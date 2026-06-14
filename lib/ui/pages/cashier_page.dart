// lib/ui/pages/cashier_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../core/app_theme.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import 'widgets/pos_widgets.dart';
import '../../core/isar_service.dart';
import '../../repositories/sync_repository.dart';
import '../../services/connectivity_service.dart';

// ─── Temporary local providers (ganti dengan Isar stream di production) ──────

final _selectedCategoryProvider = StateProvider<String?>((ref) => null);
final _searchQueryProvider       = StateProvider<String>((ref) => '');

final _productsStreamProvider = StreamProvider<List<Product>>((ref) async* {
  final isar = await IsarService.instance.db;
  yield* isar.products.filter().isActiveEqualTo(true).sortByName().watch(fireImmediately: true);
});

final _pendingSyncCountProvider = StreamProvider<int>((ref) {
  return SyncRepository.instance.watchPendingSyncCount();
});

final _connectivityStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  yield ConnectivityService.instance.current;
  yield* ConnectivityService.instance.statusStream;
});

// ─── Category model ───────────────────────────────────────────────────────────

class _Cat {
  final String id, label;
  final Color color, surface;
  const _Cat(this.id, this.label, this.color, this.surface);
}

const _cats = [
  _Cat('all',   'Semua',    AppColors.sage,        AppColors.sageSurface),
  _Cat('food',  'Makanan',  AppColors.terracotta,  AppColors.terracottaLight),
  _Cat('drink', 'Minuman',  AppColors.mustard,     AppColors.mustardLight),
  _Cat('snack', 'Snack',    AppColors.clay,        AppColors.clayLight),
  _Cat('other', 'Lainnya',  AppColors.slate,       Color(0xFFEEF0F3)),
];

// =============================================================================
// CASHIER PAGE
// =============================================================================

class CashierPage extends ConsumerStatefulWidget {
  const CashierPage({super.key});
  @override
  ConsumerState<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends ConsumerState<CashierPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.warmIvory,
    body: Column(children: [
      _TopBar(),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 65, child: _ProductPanel(searchCtrl: _searchCtrl)),
        Container(width: 1, color: AppColors.oatMedium),
        const Expanded(flex: 35, child: _CartPanel()),
      ])),
    ]),
  );
}

// =============================================================================
// TOP BAR
// =============================================================================

class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(_pendingSyncCountProvider).valueOrNull ?? 0;
    final isOnline = ref.watch(_connectivityStatusProvider).valueOrNull == NetworkStatus.online;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(bottom: BorderSide(color: AppColors.oatMedium)),
      ),
      child: Row(children: [
        Text('● Kasir', style: AppTextStyles.headingMedium.copyWith(
          color: AppColors.sage, letterSpacing: -0.3)),
        const SizedBox(width: AppSpacing.xs),
        Text('Outlet Utama', style: AppTextStyles.bodySmall),
        const Spacer(),
        SyncStatusBadge(pendingCount: pendingCount, isOnline: isOnline),
        const SizedBox(width: AppSpacing.lg),
        _LiveClock(),
        const SizedBox(width: AppSpacing.lg),
        Container(
          width: 32, height: 32,
          decoration: const BoxDecoration(color: AppColors.sageLight, shape: BoxShape.circle),
          child: const Center(child: Text('A',
            style: TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.w700, fontSize: 14))),
        ),
      ]),
    );
  }
}

class _LiveClock extends StatefulWidget {
  @override State<_LiveClock> createState() => _LiveClockState();
}
class _LiveClockState extends State<_LiveClock> {
  late final _t = Stream.periodic(const Duration(seconds: 1))
      .listen((_) { if (mounted) setState(() {}); });
  @override void dispose() { _t.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    return Text(
      '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}',
      style: AppTextStyles.labelMedium.copyWith(
        fontFeatures: [const FontFeature.tabularFigures()]));
  }
}

// =============================================================================
// PRODUCT PANEL
// =============================================================================

class _ProductPanel extends ConsumerWidget {
  final TextEditingController searchCtrl;
  const _ProductPanel({required this.searchCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selCat = ref.watch(_selectedCategoryProvider);
    final query  = ref.watch(_searchQueryProvider);
    final productsAsync = ref.watch(_productsStreamProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
        child: TextField(
          controller: searchCtrl,
          onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
          decoration: InputDecoration(
            hintText: 'Cari produk...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            suffixIcon: query.isNotEmpty
              ? GestureDetector(
                  onTap: () { searchCtrl.clear(); ref.read(_searchQueryProvider.notifier).state = ''; },
                  child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18))
              : null,
          ),
        ),
      ),

      // Category chips
      SizedBox(height: 38, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: _cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final c = _cats[i];
          final sel = (c.id == 'all' && selCat == null) || c.id == selCat;
          return CategoryChip(
            label: c.label, isSelected: sel,
            accentColor: c.color, accentSurface: c.surface,
            onTap: () => ref.read(_selectedCategoryProvider.notifier).state =
              c.id == 'all' ? null : c.id,
          );
        },
      )),

      const SizedBox(height: AppSpacing.lg),

      ...productsAsync.when(
        data: (all) {
          final filtered = all.where((p) =>
            p.isActive &&
            (selCat == null || p.categoryLocalId == selCat) &&
            (query.isEmpty || p.name.toLowerCase().contains(query.toLowerCase()))
          ).toList();

          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text('${filtered.length} produk',
                style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.4)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                ? _Empty(isSearch: query.isNotEmpty || selCat != null)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ProductCard(product: filtered[i]),
                  ),
            ),
          ];
        },
        loading: () => [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text('Memuat produk...', style: AppTextStyles.labelSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.sage),
            ),
          ),
        ],
        error: (err, stack) => [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text('Gagal memuat produk', style: AppTextStyles.labelSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Expanded(
            child: Center(
              child: Text('Terjadi kesalahan data', style: TextStyle(color: AppColors.terracotta)),
            ),
          ),
        ],
      ),
    ]);
  }
}

class _Empty extends StatelessWidget {
  final bool isSearch;
  const _Empty({required this.isSearch});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(isSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
      size: 48, color: AppColors.textMuted),
    const SizedBox(height: AppSpacing.md),
    Text(isSearch ? 'Produk tidak ditemukan' : 'Belum ada produk',
      style: AppTextStyles.headingSmall.copyWith(color: AppColors.textSecondary)),
    const SizedBox(height: AppSpacing.xs),
    Text(isSearch ? 'Coba kata kunci lain' : 'Tambah produk di Web Admin',
      style: AppTextStyles.bodySmall),
  ]));
}

// =============================================================================
// CART PANEL
// =============================================================================

class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      color: AppColors.oatLight,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            border: Border(bottom: BorderSide(color: AppColors.oatMedium)),
          ),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text('Pesanan', style: AppTextStyles.headingMedium),
            if (!cart.isEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sage, borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text('${cart.totalQuantity}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ],
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () => _confirmClear(context, ref),
                child: Text('Hapus semua', style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.terracotta, fontWeight: FontWeight.w600))),
          ]),
        ),

        // Item list
        Expanded(
          child: cart.isEmpty
            ? _CartEmpty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => CartItemRow(item: cart.items[i]),
              ),
        ),

        // Summary + pay
        _CartFooter(cart: cart),
      ]),
    );
  }

  void _confirmClear(BuildContext ctx, WidgetRef ref) => showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Hapus semua item?', style: AppTextStyles.headingMedium),
      content: Text('Keranjang akan dikosongkan.',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
        TextButton(
          onPressed: () { ref.read(cartProvider.notifier).clear(); Navigator.pop(ctx); },
          child: const Text('Hapus', style: TextStyle(color: AppColors.terracotta))),
      ],
    ),
  );
}

class _CartEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 64, height: 64,
      decoration: BoxDecoration(color: AppColors.oatMedium.withAlpha(80), shape: BoxShape.circle),
      child: const Icon(Icons.shopping_basket_outlined, size: 28, color: AppColors.textMuted),
    ),
    const SizedBox(height: AppSpacing.lg),
    Text('Keranjang kosong',
      style: AppTextStyles.headingSmall.copyWith(color: AppColors.textSecondary)),
    const SizedBox(height: AppSpacing.xs),
    Text('Ketuk produk untuk menambahkan', style: AppTextStyles.bodySmall),
  ]));
}

// =============================================================================
// CART FOOTER
// =============================================================================

class _CartFooter extends ConsumerWidget {
  final CartState cart;
  const _CartFooter({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
    decoration: const BoxDecoration(
      color: AppColors.cardSurface,
      border: Border(top: BorderSide(color: AppColors.oatMedium)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SummaryRow(label: 'Subtotal', amount: cart.subtotal),
      if (cart.discountAmount > 0)
        SummaryRow(
          label: cart.appliedDiscountCode != null
            ? 'Diskon (${cart.appliedDiscountCode})' : 'Diskon',
          amount: cart.discountAmount, isDiscount: true),
      if (cart.taxAmount > 0)
        SummaryRow(label: 'Pajak (${cart.taxRatePercent}%)', amount: cart.taxAmount),

      const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Divider()),
      SummaryRow(label: 'Total', amount: cart.totalAmount, isTotal: true),
      const SizedBox(height: AppSpacing.lg),

      // Discount row
      if (!cart.isEmpty) _DiscountTile(cart: cart),
      if (!cart.isEmpty) const SizedBox(height: AppSpacing.md),

      // Pay button
      PayButton(
        total: cart.totalAmount,
        enabled: !cart.isEmpty,
        onTap: () => _showPaySheet(context, ref),
      ),
    ]),
  );

  void _showPaySheet(BuildContext ctx, WidgetRef ref) => showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PaySheet(cart: cart),
  );
}

class _DiscountTile extends ConsumerWidget {
  final CartState cart;
  const _DiscountTile({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.appliedDiscountCode != null) {
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.sageSurface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.sageLight),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_offer_outlined, size: 13, color: AppColors.sage),
            const SizedBox(width: 5),
            Text(cart.appliedDiscountCode!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.sage)),
          ]),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => ref.read(cartProvider.notifier).clearDiscount(),
          child: Text('Hapus', style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.terracotta, fontWeight: FontWeight.w600))),
      ]);
    }
    return GestureDetector(
      onTap: () => _showDiscountDialog(context, ref),
      child: Row(children: [
        const Icon(Icons.local_offer_outlined, size: 14, color: AppColors.sage),
        const SizedBox(width: AppSpacing.xs),
        Text('Tambah diskon / kode promo',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.sage, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _showDiscountDialog(BuildContext ctx, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Kode Promo', style: AppTextStyles.headingMedium),
      content: TextField(controller: ctrl, autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'Masukkan kode...')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
        TextButton(
          onPressed: () {
            ref.read(cartProvider.notifier).applyDiscountCode(ctrl.text.trim(), 10000);
            Navigator.pop(ctx);
          },
          child: const Text('Terapkan', style: TextStyle(color: AppColors.sage))),
      ],
    ));
  }
}

// =============================================================================
// PAYMENT BOTTOM SHEET
// =============================================================================

class _PaySheet extends ConsumerWidget {
  final CartState cart;
  const _PaySheet({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        width: 36, height: 4,
        decoration: BoxDecoration(color: AppColors.oatMedium,
          borderRadius: BorderRadius.circular(AppRadius.full)))),

      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xs),
        child: Row(children: [
          Text('Metode Pembayaran', style: AppTextStyles.headingMedium),
          const Spacer(),
          Text(formatRupiah(cart.totalAmount),
            style: AppTextStyles.displayMedium.copyWith(color: AppColors.sage)),
        ]),
      ),

      const Divider(height: AppSpacing.xl),

      _PayOpt(Icons.payments_outlined,     'Tunai',         'Hitung kembalian',              null,
        () { Navigator.pop(context); /* → CashPaymentPage */ }),
      _PayOpt(Icons.qr_code_rounded,       'QRIS',          'GoPay, OVO, Dana, ShopeePay',   AppColors.sage,
        () { Navigator.pop(context); /* → QrisPaymentPage */ }),
      _PayOpt(Icons.account_balance_outlined, 'Transfer Bank', 'BCA, Mandiri, BRI, BNI',    null,
        () => Navigator.pop(context)),

      const SizedBox(height: AppSpacing.xl),
    ]),
  );
}

class _PayOpt extends StatelessWidget {
  final IconData icon; final String label, sub; final Color? accent; final VoidCallback onTap;
  const _PayOpt(this.icon, this.label, this.sub, this.accent, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (accent ?? AppColors.clay).withAlpha(15),
            borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(icon, color: accent ?? AppColors.clay, size: 22)),
        const SizedBox(width: AppSpacing.lg),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.headingSmall),
          Text(sub, style: AppTextStyles.bodySmall),
        ]),
        const Spacer(),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
      ]),
    ),
  );
}