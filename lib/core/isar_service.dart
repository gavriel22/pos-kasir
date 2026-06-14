// lib/core/isar_service.dart
//
// Singleton yang mengelola lifecycle Isar database.
// Dipanggil sekali saat app start di main.dart, lalu diakses via getter.

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/product.dart';
import '../models/transaction.dart';

class IsarService {
  IsarService._();
  static final IsarService instance = IsarService._();

  Isar? _isar;

  /// Buka (atau kembalikan) instance Isar yang sudah terbuka.
  /// Aman dipanggil berkali-kali — hanya membuka sekali.
  Future<Isar> get db async {
    if (_isar != null && _isar!.isOpen) return _isar!;
    return _isar = await _open();
  }

  Future<Isar> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [
        ProductSchema,
        TransactionSchema,
        // Tambahkan schema baru di sini saat ada model baru
      ],
      directory: dir.path,
      name: 'pos_local',       // nama file: pos_local.isar
      inspector: true,         // aktifkan Isar Inspector di debug mode
    );
  }

  /// Tutup koneksi — dipanggil saat widget dispose atau app exit.
  /// Biasanya tidak perlu dipanggil manual kecuali untuk testing.
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}