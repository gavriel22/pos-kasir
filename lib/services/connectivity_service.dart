// lib/services/connectivity_service.dart
//
// Mendeteksi perubahan status jaringan dan memicu sinkronisasi otomatis.
// Dipasang sekali di MaterialApp level — bukan di setiap halaman.

import 'dart:async';
import 'dart:io';

import '../repositories/sync_repository.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _statusController = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  NetworkStatus _current = NetworkStatus.online;
  NetworkStatus get current => _current;

  Timer? _pollTimer;
  Timer? _syncTimer;

  /// Mulai monitoring. Panggil satu kali di main.dart setelah app init.
  void start() {
    // Poll konektivitas setiap 5 detik (lebih reliable dari connectivity_plus
    // karena benar-benar cek apakah bisa reach server, bukan sekadar ada WiFi)
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());

    // Push pending setiap 5 menit meski tidak ada perubahan konektivitas
    // Mengantisipasi kasus koneksi ada tapi pertama kali sync gagal
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_current == NetworkStatus.online) {
        await SyncRepository.instance.pushPendingTransactions();
      }
    });

    _check(); // cek segera saat start
  }

  Future<void> _check() async {
    final reachable = await _canReachServer();
    final newStatus = reachable ? NetworkStatus.online : NetworkStatus.offline;

    if (newStatus != _current) {
      _current = newStatus;
      _statusController.add(newStatus);

      // Koneksi baru pulih → langsung push semua yang pending
      if (newStatus == NetworkStatus.online) {
        await SyncRepository.instance.pushPendingTransactions();
        await SyncRepository.instance.pullMasterData();
      }
    }
  }

  Future<bool> _canReachServer() async {
    try {
      // Ping ke DNS Google sebagai proxy check konektivitas internet
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _syncTimer?.cancel();
    _statusController.close();
  }
}