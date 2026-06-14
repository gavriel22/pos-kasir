// lib/models/product.dart
//
// Jalankan code generator setelah membuat/mengubah file ini:
//   dart run build_runner build --delete-conflicting-outputs

import 'package:isar/isar.dart';

part 'product.g.dart';

// ---------------------------------------------------------------------------
// ENUM: SyncStatus
// Dipakai oleh semua collection yang perlu sinkronisasi offline → cloud.
// Disimpan sebagai index integer di Isar (0, 1, 2, 3, 4).
// ---------------------------------------------------------------------------

enum SyncStatus {
  pending,   // 0 — baru dibuat/diubah lokal, belum dikirim
  syncing,   // 1 — sedang dalam proses upload
  synced,    // 2 — sudah dikonfirmasi server
  conflict,  // 3 — server menolak / data bentrok
  failed,    // 4 — gagal setelah max retry
}

// ---------------------------------------------------------------------------
// EMBEDDED: ProductPrice
// Embedded object tidak punya tabel sendiri di Isar — tersimpan inline
// di dalam dokumen Product. Cocok untuk data yang selalu diakses bersama.
// ---------------------------------------------------------------------------

@embedded
class ProductPrice {
  String? priceType; // 'default', 'wholesale', 'member'
  int price = 0;
  bool isActive = true;
}

// ---------------------------------------------------------------------------
// COLLECTION: Product
// Mirror dari tabel `products` di PostgreSQL.
// Kolom `localId` = UUID dari perangkat, `serverId` = UUID dari server.
// ---------------------------------------------------------------------------

@Collection()
class Product {
  Product();
  // Isar internal ID — auto-increment, hanya untuk Isar. JANGAN kirim ke server.
  Id id = Isar.autoIncrement;

  // --- Identitas Sinkronisasi ---

  /// UUID yang digenerate di Flutter sebelum ada koneksi internet.
  /// Ini yang dikirim ke server sebagai `local_id` saat sync.
  @Index(unique: true)
  late String localId;

  /// UUID yang dikembalikan server setelah sync berhasil.
  /// Null selama belum pernah tersinkron.
  String? serverId;

  // --- Data Master ---

  String? categoryLocalId; // referensi ke Category.localId
  String? sku;

  @Index()
  late String name;

  String? description;

  /// Harga dalam satuan Rupiah. Gunakan int, bukan double.
  int basePrice = 0;

  int stock = 0;
  String unit = 'pcs';
  String? imageUrl;

  @Index()
  bool isActive = true;

  List<ProductPrice> prices = [];

  // --- Sinkronisasi ---

  @enumerated
  SyncStatus syncStatus = SyncStatus.synced; // produk biasanya di-pull dari server

  DateTime? syncedAt;
  DateTime updatedAt = DateTime.now();
  DateTime createdAt = DateTime.now();

  // --- Helper Methods ---

  /// Kembalikan harga default atau fallback ke basePrice.
  int get effectivePrice {
    final defaultPrice = prices.where((p) => p.priceType == 'default' && p.isActive).firstOrNull;
    return defaultPrice?.price ?? basePrice;
  }

  /// Konversi ke Map untuk dikirim ke server saat sync.
  Map<String, dynamic> toSyncPayload() => {
        'local_id':   localId,
        'sku':        sku,
        'name':       name,
        'base_price': basePrice,
        'stock':      stock,
        'unit':       unit,
        'is_active':  isActive,
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Buat Product dari response JSON server (delta pull).
  factory Product.fromServerJson(Map<String, dynamic> json) {
    return Product()
      ..localId    = json['local_id'] as String
      ..serverId   = json['id'] as String
      ..sku        = json['sku'] as String?
      ..name       = json['name'] as String
      ..basePrice  = (json['base_price'] as num).toInt()
      ..stock      = (json['stock'] as num).toInt()
      ..unit       = json['unit'] as String? ?? 'pcs'
      ..isActive   = json['is_active'] as bool? ?? true
      ..syncStatus = SyncStatus.synced
      ..syncedAt   = DateTime.now()
      ..updatedAt  = DateTime.parse(json['updated_at'] as String)
      ..createdAt  = DateTime.parse(json['created_at'] as String);
  }
}