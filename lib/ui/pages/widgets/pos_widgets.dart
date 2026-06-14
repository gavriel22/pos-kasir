// lib/ui/widgets/pos_widgets.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme.dart';
import '../../../models/product.dart';
import '../../../providers/cart_provider.dart';

final _rupiahFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
String formatRupiah(int amount) => _rupiahFmt.format(amount);

// ─── CategoryChip ────────────────────────────────────────────────────────────

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final Color accentSurface;
  final VoidCallback onTap;
  const CategoryChip({super.key, required this.label, required this.isSelected,
    required this.accentColor, required this.accentSurface, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 9),
      decoration: BoxDecoration(
        color: isSelected ? accentColor : accentSurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: isSelected ? accentColor : AppColors.oatMedium),
      ),
      child: Text(label,
        style: AppTextStyles.labelMedium.copyWith(
          color: isSelected ? Colors.white : accentColor,
          fontWeight: FontWeight.w600)),
    ),
  );
}

// ─── ProductCard ─────────────────────────────────────────────────────────────

class ProductCard extends ConsumerWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty      = ref.watch(productQuantityProvider(product.localId));
    final inCart   = qty > 0;
    final outStock = product.stock == 0;

    return GestureDetector(
      onTap: outStock ? null : () {
        HapticFeedback.lightImpact();
        ref.read(cartProvider.notifier).addProduct(product);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: inCart ? AppColors.sageLight : AppColors.oatMedium,
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: inCart ? AppShadows.cardElevated : AppShadows.cardSubtle,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: inCart
                    ? [AppColors.sageSurface.withAlpha(230), AppColors.cardSurface.withAlpha(200)]
                    : [AppColors.glassWhite, AppColors.cardSurface.withAlpha(220)],
                ),
              ),
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.oatMedium.withAlpha(80),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: product.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => _icon()))
                          : _icon(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(product.name,
                      style: AppTextStyles.headingSmall, maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text(formatRupiah(product.effectivePrice),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 14)),
                    if (product.stock > 0 && product.stock <= 5) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Stok: ${product.stock}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.terracotta)),
                    ],
                  ]),
                ),
                if (inCart)
                  Positioned(top: AppSpacing.sm, right: AppSpacing.sm,
                    child: Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
                      child: Center(child: Text('$qty',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))))),
                if (outStock)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        color: Colors.white.withAlpha(160),
                        child: const Center(child: Text('Stok habis',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)))))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon() => const Center(
    child: Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 32));
}

// ─── CartItemRow ─────────────────────────────────────────────────────────────

class CartItemRow extends ConsumerWidget {
  final CartItem item;
  const CartItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.productName,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(formatRupiah(item.unitPrice), style: AppTextStyles.bodySmall),
        ])),
        const SizedBox(width: AppSpacing.md),
        _QtyControl(
          quantity: item.quantity,
          onDecrement: () => n.decrementProduct(item.productLocalId),
          onIncrement: () => n.setQuantity(item.productLocalId, item.quantity + 1),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 80,
          child: Text(formatRupiah(item.lineTotal),
            style: AppTextStyles.headingSmall, textAlign: TextAlign.end)),
      ]),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement, onIncrement;
  const _QtyControl({required this.quantity, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.oatMedium.withAlpha(120),
      borderRadius: BorderRadius.circular(AppRadius.md)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _Btn(icon: Icons.remove, onTap: onDecrement),
      SizedBox(width: 28,
        child: Text('$quantity', textAlign: TextAlign.center,
          style: AppTextStyles.headingSmall.copyWith(fontSize: 15))),
      _Btn(icon: Icons.add, onTap: onIncrement),
    ]),
  );
}

class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Icon(icon, size: 16, color: AppColors.textPrimary)));
}

// ─── SummaryRow ───────────────────────────────────────────────────────────────

class SummaryRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isTotal, isDiscount;
  const SummaryRow({super.key, required this.label, required this.amount,
    this.isTotal = false, this.isDiscount = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: isTotal
        ? AppTextStyles.headingMedium
        : AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      Text(
        isDiscount && amount > 0 ? '- ${formatRupiah(amount)}' : formatRupiah(amount),
        style: isTotal
          ? AppTextStyles.displayMedium.copyWith(color: AppColors.sage)
          : AppTextStyles.bodyMedium.copyWith(
              color: isDiscount ? AppColors.terracotta : AppColors.textPrimary,
              fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─── PayButton ────────────────────────────────────────────────────────────────

class PayButton extends StatelessWidget {
  final int total;
  final bool enabled;
  final VoidCallback onTap;
  const PayButton({super.key, required this.total, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: double.infinity, height: 64,
      decoration: BoxDecoration(
        color: enabled ? AppColors.sage : AppColors.oatMedium,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: enabled ? [BoxShadow(
          color: AppColors.sage.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))] : [],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.payment_rounded, color: enabled ? Colors.white : AppColors.textMuted, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bayar', style: TextStyle(
            color: enabled ? Colors.white.withAlpha(200) : AppColors.textMuted,
            fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
          Text(enabled ? formatRupiah(total) : 'Keranjang kosong',
            style: TextStyle(
              color: enabled ? Colors.white : AppColors.textMuted,
              fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        ]),
      ]),
    ),
  );
}

// ─── SyncStatusBadge ─────────────────────────────────────────────────────────

class SyncStatusBadge extends StatelessWidget {
  final int pendingCount;
  final bool isOnline;
  const SyncStatusBadge({super.key, required this.pendingCount, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingCount == 0)
      return _badge(AppColors.success, 'Tersinkron', Icons.cloud_done_outlined);
    if (!isOnline)
      return _badge(AppColors.clay, 'Offline', Icons.cloud_off_outlined);
    return _badge(AppColors.mustard, '$pendingCount menunggu', Icons.sync_rounded);
  }

  Widget _badge(Color c, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withAlpha(20),
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: Border.all(color: c.withAlpha(60))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 5),
      Text(label, style: AppTextStyles.labelSmall.copyWith(color: c, fontWeight: FontWeight.w600)),
    ]),
  );
}