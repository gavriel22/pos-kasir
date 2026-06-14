// lib/models/transaction.dart

import 'package:isar/isar.dart';
import 'product.dart';

part 'transaction.g.dart';

// ---------------------------------------------------------------------------
// ENUM: PaymentMethod & PaymentStatus
// ---------------------------------------------------------------------------

enum PaymentMethod { cash, qris, transfer, card, other }

enum PaymentStatus { pending, paid, expired, failed, refunded }

// ---------------------------------------------------------------------------
// EMBEDDED: QrisInfo
// Seluruh data QRIS disatukan dalam satu embedded object supaya akses
// di UI kasir cukup satu property: `transaction.qris`.
// ---------------------------------------------------------------------------

@embedded
class QrisInfo {
  /// order_id yang dikirim ke Midtrans. Format: POS-{localId[0..7]}-{timestamp}
  String? referenceId;

  /// transaction_id dari Midtrans (dipakai untuk polling status)
  String? token;

  /// QR string untuk di-render menjadi QR code di layar kasir
  String? qrString;

  /// URL alternatif jika pakai payment_url dari Midtrans
  String? paymentUrl;

  /// Batas waktu QRIS. Setelah ini, status otomatis expired.
  DateTime? expiresAt;

  /// Timestamp saat webhook konfirmasi pembayaran diterima server
  DateTime? paidAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

// ---------------------------------------------------------------------------
// EMBEDDED: TransactionDiscount
// Snapshot diskon yang diterapkan. Embedded agar struk bisa dirender
// tanpa query tambahan ke tabel lain.
// ---------------------------------------------------------------------------

@embedded
class TransactionDiscount {
  String? discountLocalId;
  String? discountCode;
  String? discountName;
  int appliedValue = 0; // nilai aktual yang dipotong, bukan persentasenya
}

// ---------------------------------------------------------------------------
// COLLECTION: TransactionDetail
// Satu line item produk dalam transaksi. Disimpan sebagai embedded list
// di dalam Transaction — bukan collection terpisah — karena:
//   1. Detail selalu diakses bersama header transaksi
//   2. Mengurangi join query di Isar
//   3. Snapshot sudah mandiri, tidak perlu referensi ke Product
// ---------------------------------------------------------------------------

@embedded
class TransactionDetail {
  // Identitas
  late String localId; // UUID unik per line item

  // Referensi ke produk (nullable — produk bisa dihapus di masa depan)
  String? productLocalId;
  String? productServerId;

  // SNAPSHOT — nilai ini TIDAK BOLEH berubah setelah transaksi dibuat
  // Ini adalah bukti harga resmi di saat transaksi terjadi.
  late String productNameSnapshot;
  String? productSkuSnapshot;
  int unitPriceSnapshot = 0;

  // Kalkulasi
  int quantity = 1;
  int discountPerItem = 0;

  /// subtotal = (unitPriceSnapshot - discountPerItem) * quantity
  int get subtotal => (unitPriceSnapshot - discountPerItem) * quantity;
}

// ---------------------------------------------------------------------------
// COLLECTION: Transaction
// Dokumen utama POS. Dirancang agar bisa dirender sebagai struk
// hanya dari data dalam dokumen ini — tanpa query tambahan.
// ---------------------------------------------------------------------------

@Collection()
class Transaction {
  Id id = Isar.autoIncrement;

  // --- Identitas Sinkronisasi ---

  @Index(unique: true)
  late String localId;

  String? serverId;

  // --- Metadata Transaksi ---

  /// Kode human-readable untuk struk. Format: TRX-YYYYMMDD-XXXX
  /// Di-generate di Flutter saat transaksi dibuat.
  @Index(unique: true)
  late String transactionCode;

  late String outletLocalId;
  late String cashierLocalId;  // user yang login
  late String cashierName;     // snapshot nama kasir untuk struk
  String? customerLocalId;
  String? customerName;        // snapshot nama pelanggan

  // --- Line Items ---

  List<TransactionDetail> details = [];
  List<TransactionDiscount> appliedDiscounts = [];

  // --- Kalkulasi (semua integer Rupiah) ---

  int subtotal = 0;        // jumlah sebelum diskon & pajak
  int discountAmount = 0;  // total nilai diskon
  int taxAmount = 0;       // PPN atau pajak lainnya
  int totalAmount = 0;     // yang dibayar pelanggan

  int amountPaid = 0;      // untuk metode cash: uang yang diserahkan
  int changeAmount = 0;    // kembalian

  // --- Pembayaran ---

  @enumerated
  PaymentMethod paymentMethod = PaymentMethod.cash;

  @enumerated
  PaymentStatus paymentStatus = PaymentStatus.pending;

  QrisInfo? qris; // null jika bukan pembayaran QRIS

  // --- Sinkronisasi ---

  @Index()
  @enumerated
  SyncStatus syncStatus = SyncStatus.pending;

  int retryCount = 0;       // berapa kali sudah dicoba sync
  String? lastSyncError;    // pesan error terakhir untuk ditampilkan di admin

  DateTime? syncedAt;

  // --- Timestamps ---

  /// Waktu transaksi di perangkat kasir. Bisa offline = beda dari syncedAt.
  @Index()
  DateTime transactionTime = DateTime.now();

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  // --- Computed Properties ---

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isSynced => syncStatus == SyncStatus.synced;
  bool get needsSync => syncStatus == SyncStatus.pending || syncStatus == SyncStatus.failed;

  // --- Serialization ---

  /// Payload lengkap yang dikirim ke endpoint POST /api/v1/sync/push
  Map<String, dynamic> toSyncPayload() => {
        'local_id':         localId,
        'transaction_code': transactionCode,
        'outlet_local_id':  outletLocalId,
        'cashier_local_id': cashierLocalId,
        'customer_local_id': customerLocalId,
        'subtotal':         subtotal,
        'discount_amount':  discountAmount,
        'tax_amount':       taxAmount,
        'total_amount':     totalAmount,
        'amount_paid':      amountPaid,
        'change_amount':    changeAmount,
        'payment_method':   paymentMethod.name,
        'payment_status':   paymentStatus.name,
        'transaction_time': transactionTime.toIso8601String(),
        'qris': qris == null
            ? null
            : {
                'reference_id': qris!.referenceId,
                'token':        qris!.token,
                'paid_at':      qris!.paidAt?.toIso8601String(),
              },
        'details': details
            .map((d) => {
                  'local_id':               d.localId,
                  'product_local_id':        d.productLocalId,
                  'product_name_snapshot':   d.productNameSnapshot,
                  'product_sku_snapshot':    d.productSkuSnapshot,
                  'unit_price_snapshot':     d.unitPriceSnapshot,
                  'quantity':                d.quantity,
                  'discount_per_item':       d.discountPerItem,
                  'subtotal':                d.subtotal,
                })
            .toList(),
        'applied_discounts': appliedDiscounts
            .map((d) => {
                  'discount_local_id': d.discountLocalId,
                  'discount_code':     d.discountCode,
                  'applied_value':     d.appliedValue,
                })
            .toList(),
      };
}