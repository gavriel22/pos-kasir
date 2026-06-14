import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'ui/pages/cashier_page.dart';

import 'services/connectivity_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectivityService.instance.start();
  runApp(
    const ProviderScope(
      child: PosApp(),
    ),
  );
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Kasir',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(), // Menggunakan theme dari app_theme.dart
      home: const CashierPage(), // Mengarah ke halaman kasir baru
    );
  }
}