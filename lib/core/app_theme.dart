// lib/core/app_theme.dart
//
// Sistem token warna dan tipografi terpusat.
// Sage Green & Earth Tones — semua nilai warna harus diambil dari sini,
// tidak boleh ada hardcoded hex di file UI manapun.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// COLOR TOKENS
// ---------------------------------------------------------------------------

abstract final class AppColors {
  // --- Backgrounds ---
  static const warmIvory  = Color(0xFFF5F2EC); // background utama app
  static const oatLight   = Color(0xFFEFEBE3); // background panel kanan (cart)
  static const oatMedium  = Color(0xFFE8E3D9); // divider, border halus
  static const cardSurface = Color(0xFFFAF8F4); // permukaan card produk

  // --- Sage Green (primary action) ---
  static const sage        = Color(0xFF7A9E7E); // tombol utama, aktif
  static const sageDark    = Color(0xFF5C7D60); // hover / pressed state
  static const sageLight   = Color(0xFFB8D4BA); // badge selected, soft bg
  static const sageSurface = Color(0xFFEBF3EC); // background aksen sage

  // --- Earth Tones (aksen kategori) ---
  static const terracotta      = Color(0xFFBF6B4A); // kategori makanan, badge
  static const terracottaLight = Color(0xFFF5E6DF); // background badge
  static const mustard         = Color(0xFFC49A2F); // kategori minuman
  static const mustardLight    = Color(0xFFF5EDD4); // background badge
  static const clay            = Color(0xFF9C7B5E); // kategori snack
  static const clayLight       = Color(0xFFF0E7DF); // background badge
  static const slate           = Color(0xFF6B7A8D); // kategori lainnya

  // --- Text ---
  static const textPrimary   = Color(0xFF1C1C1E); // judul, label penting
  static const textSecondary = Color(0xFF6B6B6B); // deskripsi, placeholder
  static const textMuted     = Color(0xFF9E9E9E); // hint, disabled
  static const textOnSage    = Color(0xFFFFFFFF); // teks di atas tombol sage

  // --- Semantic ---
  static const error   = Color(0xFFB94040);
  static const success = Color(0xFF4A7C59);
  static const warning = Color(0xFFB8860B);

  // --- Glassmorphism ---
  static const glassWhite  = Color(0xCCFFFFFF);  // 80% opacity white
  static const glassBorder = Color(0x33FFFFFF);  // 20% opacity white untuk border
}

// ---------------------------------------------------------------------------
// TEXT STYLES
// ---------------------------------------------------------------------------

abstract final class AppTextStyles {
  // Display — untuk total harga, angka besar
  static const displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // Heading — untuk nama produk, section header
  static const headingMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const headingSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  // Body
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Label — untuk harga, badge, chip
  static const labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static const labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  // Mono — untuk kode transaksi
  static const mono = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}

// ---------------------------------------------------------------------------
// SPACING & RADIUS TOKENS
// ---------------------------------------------------------------------------

abstract final class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

abstract final class AppRadius {
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double full = 999; // pill shape
}

// ---------------------------------------------------------------------------
// SHADOWS
// ---------------------------------------------------------------------------

abstract final class AppShadows {
  static const cardSubtle = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const cardElevated = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];
}

// ---------------------------------------------------------------------------
// MATERIAL THEME
// ---------------------------------------------------------------------------

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.warmIvory,
    colorScheme: const ColorScheme.light(
      primary:   AppColors.sage,
      onPrimary: AppColors.textOnSage,
      surface:   AppColors.cardSurface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.oatLight,
    ),
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,    // hapus ink splash untuk look bersih
    highlightColor: Colors.transparent,
    dividerTheme: const DividerThemeData(
      color: AppColors.oatMedium,
      thickness: 1,
      space: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.oatMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.oatMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
    ),
  );
}