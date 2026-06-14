// lib/repositories/sync_repository.dart
//
// Satu-satunya class yang boleh berbicara ke Isar DAN API sekaligus.
// UI dan state management TIDAK boleh menyentuh Isar atau ApiClient langsung —
// semua melalui repository ini.
//
// Prinsip:
//   - Write-local-first: setiap operasi SELALU berhasil secara lokal
//   - Sync adalah proses latar belakang, bukan bagian dari alur UI
//   - UI mendengarkan Isar Stream — otomatis update saat data lokal berubah

import 'dart:async';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../core/isar_service.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';

// ---------------------------------------------------------------------------
// Result type sederhana — menghindari exception untuk flow normal
// ---------------------------------------------------------------------------

sealed class SyncResult {}

class SyncSuccess extends SyncResult {
  final int pushed;
  final int skipped;
  SyncSuccess({required this.pushed, required this.skipped});
}

class SyncFailure extends SyncResult {
  final String message;
  final List<String> failedLocalIds;
  SyncFailure({required this.message, required this.failedLocalIds});
}

class SyncPartial extends SyncResult {
  final int pushed;
  final List<String> failedLocalIds;
  SyncPartial({required this.pushed, required this.failedLocalIds});
}

// ---------------------------------------------------------------------------
// SyncRepository
// ---------------------------------------------------------------------------

class SyncRepository {
  SyncRepository._();
  static final SyncRepository instance = SyncRepository._();

  final _uuid = const Uuid();
  final _api  = ApiClient.instance;
  bool _isSyncing = false;

  Future<Isar> get _db => IsarService.instance.db;

  // =========================================================================
  // SECTION 1: WRITE — Simpan Transaksi Baru ke Isar
  // =========================================================================

  /// Buat dan simpan transaksi baru secara lokal.
  /// Return: localId dari transaksi yang baru dibuat.
  ///
  /// Method ini SELALU berhasil selama Isar bisa diakses —
  /// tidak bergantung pada koneksi internet sama sekali.
  Future<String> saveTransaction({
    required String outletLocalId,
    required String cashierLocalId,
    required String cashierName,
    required List<TransactionDetail> details,
    required PaymentMethod paymentMethod,
    String? customerLocalId,
    String? customerName,
    int taxRatePercent = 0,
    List<TransactionDiscount> discounts = const [],
  }) async {
    final isar = await _db;

    // --- Kalkulasi ---
    final subtotal = details.fold<int>(0, (sum, d) => sum + d.subtotal);
    final discountAmount = discounts.fold<int>(0, (sum, d) => sum + d.appliedValue);
    final taxAmount = ((subtotal - discountAmount) * taxRatePercent / 100).round();
    final totalAmount = subtotal - discountAmount + taxAmount;

    // --- Generate kode transaksi (TRX-20250614-XXXX) ---
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final countToday = await isar.transactions
        .filter()
        .transactionTimeGreaterThan(DateTime(now.year, now.month, now.day))
        .count();
    final seq = (countToday + 1).toString().padLeft(4, '0');
    final transactionCode = 'TRX-$dateStr-$seq';

    // --- Assign localId ke setiap detail ---
    final detailsWithId = details.map((d) {
      d.localId = _uuid.v4();
      return d;
    }).toList();

    // --- Buat object Transaction ---
    final tx = Transaction()
      ..localId          = _uuid.v4()
      ..transactionCode  = transactionCode
      ..outletLocalId    = outletLocalId
      ..cashierLocalId   = cashierLocalId
      ..cashierName      = cashierName
      ..customerLocalId  = customerLocalId
      ..customerName     = customerName
      ..details          = detailsWithId
      ..appliedDiscounts = discounts
      ..subtotal         = subtotal
      ..discountAmount   = discountAmount
      ..taxAmount        = taxAmount
      ..totalAmount      = totalAmount
      ..paymentMethod    = paymentMethod
      ..paymentStatus    = paymentMethod == PaymentMethod.cash
          ? PaymentStatus.paid    // cash langsung paid
          : PaymentStatus.pending // QRIS/transfer tunggu konfirmasi
      ..syncStatus       = SyncStatus.pending
      ..transactionTime  = now
      ..createdAt        = now
      ..updatedAt        = now;

    // --- Tulis ke Isar (atomic write) ---
    await isar.writeTxn(() async {
      await isar.transactions.put(tx);
    });

    // Kurangi stok produk secara lokal untuk konsistensi UI offline
    await _decrementStock(isar, details);

    return tx.localId;
  }

  /// Update transaksi setelah QRIS dibuat (dapat data dari server).
  Future<void> attachQrisInfo(String transactionLocalId, QrisInfo qrisInfo) async {
    final isar = await _db;
    final tx = await isar.transactions
        .filter()
        .localIdEqualTo(transactionLocalId)
        .findFirst();

    if (tx == null) return;

    await isar.writeTxn(() async {
      tx.qris       = qrisInfo;
      tx.updatedAt  = DateTime.now();
      await isar.transactions.put(tx);
    });
  }

  /// Tandai transaksi sebagai PAID setelah polling QRIS confirm.
  Future<void> markTransactionPaid(String transactionLocalId) async {
    final isar = await _db;
    final tx = await isar.transactions
        .filter()
        .localIdEqualTo(transactionLocalId)
        .findFirst();

    if (tx == null) return;

    await isar.writeTxn(() async {
      tx.paymentStatus     = PaymentStatus.paid;
      tx.qris?.paidAt      = DateTime.now();
      tx.syncStatus        = SyncStatus.pending; // trigger sync ulang dengan status terbaru
      tx.updatedAt         = DateTime.now();
      await isar.transactions.put(tx);
    });
  }

  // =========================================================================
  // SECTION 2: PUSH — Kirim Data Pending ke Server
  // =========================================================================

  /// Push semua transaksi berstatus 'pending' atau 'failed' ke backend.
  ///
  /// Method ini dipanggil oleh:
  ///   - ConnectivityService saat deteksi koneksi pulih
  ///   - Timer periodik setiap 5 menit di background
  ///   - Manually oleh kasir via tombol "Sinkronkan"
  ///
  /// Guard _isSyncing mencegah multiple calls berjalan bersamaan.
  Future<SyncResult> pushPendingTransactions() async {
    if (_isSyncing) {
      return SyncFailure(
        message: 'Sinkronisasi sedang berjalan',
        failedLocalIds: [],
      );
    }

    _isSyncing = true;

    try {
      final isar = await _db;

      // Ambil semua yang perlu di-sync, prioritaskan 'pending' dulu
      final pending = await isar.transactions
          .filter()
          .syncStatusEqualTo(SyncStatus.pending)
          .or()
          .group((q) => q
              .syncStatusEqualTo(SyncStatus.failed)
              .retryCountLessThan(5)) // max 5 retry
          .sortByTransactionTime()
          .findAll();

      if (pending.isEmpty) {
        return SyncSuccess(pushed: 0, skipped: 0);
      }

      // Tandai semua sebagai 'syncing' sebelum kirim
      await isar.writeTxn(() async {
        for (final tx in pending) {
          tx.syncStatus = SyncStatus.syncing;
        }
        await isar.transactions.putAll(pending);
      });

      // Kirim dalam batch (satu HTTP request untuk semua)
      final payload = {
        'device_id':    'flutter-device-id', // TODO: ambil dari device_info_plus
        'transactions': pending.map((t) => t.toSyncPayload()).toList(),
        'sync_timestamp': DateTime.now().toIso8601String(),
      };

      try {
        final response = await _api.post('/sync/push', payload);
        final results  = response['results'] as Map<String, dynamic>;
        final txResult = results['transactions'] as Map<String, dynamic>;
        final failedIds = List<String>.from(txResult['failed'] as List? ?? []);

        // Update status berdasarkan respons server
        await isar.writeTxn(() async {
          for (final tx in pending) {
            if (failedIds.contains(tx.localId)) {
              tx.syncStatus    = SyncStatus.failed;
              tx.retryCount    += 1;
              tx.lastSyncError = 'Server menolak data';
            } else {
              tx.syncStatus    = SyncStatus.synced;
              tx.syncedAt      = DateTime.now();
              tx.lastSyncError = null;
            }
            tx.updatedAt = DateTime.now();
          }
          await isar.transactions.putAll(pending);
        });

        final pushed = pending.length - failedIds.length;

        if (failedIds.isEmpty) {
          return SyncSuccess(pushed: pushed, skipped: 0);
        }
        return SyncPartial(pushed: pushed, failedLocalIds: failedIds);

      } on ApiException catch (e) {
        // Koneksi ada tapi server error — rollback ke pending
        await _rollbackSyncStatus(isar, pending, e.message);
        return SyncFailure(
          message: e.message,
          failedLocalIds: pending.map((t) => t.localId).toList(),
        );
      }
    } catch (e) {
      return SyncFailure(
        message: 'Error tidak terduga: $e',
        failedLocalIds: [],
      );
    } finally {
      _isSyncing = false;
    }
  }

  // =========================================================================
  // SECTION 3: PULL — Ambil Data Master Terbaru dari Server
  // =========================================================================

  /// Download data master (products, categories, discounts) dari server.
  /// Gunakan strategi delta sync: hanya ambil yang berubah sejak `since`.
  Future<void> pullMasterData({DateTime? since}) async {
    final isar = await _db;

    // Tentukan timestamp delta — ambil dari transaksi terakhir yang di-sync
    final sinceStr = since?.toIso8601String() ??
        await _getLastSyncTimestamp(isar);

    try {
      final response = await _api.get(
        '/sync/pull',
        queryParams: sinceStr != null ? {'since': sinceStr} : null,
      );

      // Proses products
      final productsJson = response['products'] as List? ?? [];
      final products = productsJson
          .map((j) => Product.fromServerJson(j as Map<String, dynamic>))
          .toList();

      // Upsert ke Isar: update jika sudah ada (berdasarkan localId), insert jika baru
      if (products.isNotEmpty) {
        await isar.writeTxn(() async {
          for (final incoming in products) {
            final existing = await isar.products
                .filter()
                .localIdEqualTo(incoming.localId)
                .findFirst();

            if (existing != null) {
              // Pertahankan Isar internal id agar tidak duplicate
              incoming.id = existing.id;
            }
            await isar.products.put(incoming);
          }
        });
      }

      // TODO: proses categories, discounts dengan pola yang sama

    } on ApiException catch (e) {
      // Pull gagal bukan masalah fatal — kasir tetap bisa transaksi dengan data lama
      // Log saja, jangan throw ke UI
      debugLog('[SyncRepository] Pull gagal: ${e.message}');
    }
  }

  // =========================================================================
  // SECTION 4: READ — Stream untuk State Management
  // =========================================================================

  /// Stream list transaksi yang belum ter-sync.
  /// State management (Riverpod/BLoC) listen ke stream ini untuk badge counter.
  Stream<int> watchPendingSyncCount() async* {
    final isar = await _db;
    yield* isar.transactions
        .filter()
        .syncStatusEqualTo(SyncStatus.pending)
        .or()
        .syncStatusEqualTo(SyncStatus.failed)
        .watch(fireImmediately: true)
        .map((list) => list.length);
  }

  /// Stream satu transaksi — dipakai halaman detail & polling QRIS.
  Stream<Transaction?> watchTransaction(String localId) async* {
    final isar = await _db;
    yield* isar.transactions
        .filter()
        .localIdEqualTo(localId)
        .watch(fireImmediately: true)
        .map((list) => list.firstOrNull);
  }

  /// Stream semua produk aktif — untuk halaman kasir (grid produk).
  Stream<List<Product>> watchActiveProducts({String? categoryLocalId}) async* {
    final isar = await _db;
    final query = categoryLocalId != null
        ? isar.products
            .filter()
            .isActiveEqualTo(true)
            .categoryLocalIdEqualTo(categoryLocalId)
        : isar.products
            .filter()
            .isActiveEqualTo(true);

    yield* query
        .sortByName()
        .watch(fireImmediately: true);
  }

  // =========================================================================
  // PRIVATE HELPERS
  // =========================================================================

  Future<void> _decrementStock(Isar isar, List<TransactionDetail> details) async {
    await isar.writeTxn(() async {
      for (final detail in details) {
        if (detail.productLocalId == null) continue;
        final product = await isar.products
            .filter()
            .localIdEqualTo(detail.productLocalId!)
            .findFirst();

        if (product == null) continue;
        product.stock = (product.stock - detail.quantity).clamp(0, product.stock);
        product.updatedAt = DateTime.now();
        await isar.products.put(product);
      }
    });
  }

  Future<void> _rollbackSyncStatus(
    Isar isar,
    List<Transaction> transactions,
    String errorMessage,
  ) async {
    await isar.writeTxn(() async {
      for (final tx in transactions) {
        tx.syncStatus    = SyncStatus.pending; // kembali ke pending, bukan failed
        tx.lastSyncError = errorMessage;
        tx.updatedAt     = DateTime.now();
      }
      await isar.transactions.putAll(transactions);
    });
  }

  Future<String?> _getLastSyncTimestamp(Isar isar) async {
    final lastSynced = await isar.transactions
        .filter()
        .syncStatusEqualTo(SyncStatus.synced)
        .sortBySyncedAtDesc()
        .findFirst();
    return lastSynced?.syncedAt?.toIso8601String();
  }

  // Placeholder untuk logging — ganti dengan package logger di production
  void debugLog(String message) {
    // ignore: avoid_print
    assert(() { print(message); return true; }());
  }
}