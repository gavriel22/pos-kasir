// lib/providers/cart_provider.dart
//
// State management keranjang belanja menggunakan Riverpod.
// Semua logika kalkulasi ada di CartNotifier — UI hanya read & dispatch.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

// ---------------------------------------------------------------------------
// DATA CLASS: CartItem
// Immutable. Setiap perubahan membuat object baru (tidak mutasi).
// ---------------------------------------------------------------------------

class CartItem {
  final String productLocalId;
  final String productName;
  final String? productSku;
  final int unitPrice;
  final String unit;
  final int quantity;
  final int discountPerItem;

  const CartItem({
    required this.productLocalId,
    required this.productName,
    this.productSku,
    required this.unitPrice,
    required this.unit,
    required this.quantity,
    this.discountPerItem = 0,
  });

  int get lineTotal => (unitPrice - discountPerItem) * quantity;

  CartItem copyWith({int? quantity, int? discountPerItem}) => CartItem(
        productLocalId:  productLocalId,
        productName:     productName,
        productSku:      productSku,
        unitPrice:       unitPrice,
        unit:            unit,
        quantity:        quantity ?? this.quantity,
        discountPerItem: discountPerItem ?? this.discountPerItem,
      );
}

// ---------------------------------------------------------------------------
// DATA CLASS: CartState
// ---------------------------------------------------------------------------

class CartState {
  final List<CartItem> items;
  final String? appliedDiscountCode;
  final int manualDiscountAmount;
  final int taxRatePercent;

  const CartState({
    this.items                = const [],
    this.appliedDiscountCode  = null,
    this.manualDiscountAmount = 0,
    this.taxRatePercent       = 0,
  });

  int get subtotal      => items.fold(0, (sum, i) => sum + i.lineTotal);
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  int get discountAmount => manualDiscountAmount;
  int get taxAmount     => ((subtotal - discountAmount) * taxRatePercent / 100).round();
  int get totalAmount   => subtotal - discountAmount + taxAmount;
  bool get isEmpty      => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? appliedDiscountCode,
    int? manualDiscountAmount,
    int? taxRatePercent,
    bool clearDiscount = false,
  }) => CartState(
        items:                items ?? this.items,
        appliedDiscountCode:  clearDiscount ? null : appliedDiscountCode ?? this.appliedDiscountCode,
        manualDiscountAmount: clearDiscount ? 0 : manualDiscountAmount ?? this.manualDiscountAmount,
        taxRatePercent:       taxRatePercent ?? this.taxRatePercent,
      );
}

// ---------------------------------------------------------------------------
// NOTIFIER
// ---------------------------------------------------------------------------

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addProduct(Product product) {
    final items = List<CartItem>.from(state.items);
    final idx   = items.indexWhere((i) => i.productLocalId == product.localId);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + 1);
    } else {
      items.add(CartItem(
        productLocalId: product.localId,
        productName:    product.name,
        productSku:     product.sku,
        unitPrice:      product.effectivePrice,
        unit:           product.unit,
        quantity:       1,
      ));
    }
    state = state.copyWith(items: items);
  }

  void decrementProduct(String productLocalId) {
    final items = List<CartItem>.from(state.items);
    final idx   = items.indexWhere((i) => i.productLocalId == productLocalId);
    if (idx < 0) return;
    if (items[idx].quantity <= 1) {
      items.removeAt(idx);
    } else {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity - 1);
    }
    state = state.copyWith(items: items);
  }

  void setQuantity(String productLocalId, int quantity) {
    if (quantity <= 0) { removeItem(productLocalId); return; }
    final items = List<CartItem>.from(state.items);
    final idx   = items.indexWhere((i) => i.productLocalId == productLocalId);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(quantity: quantity);
    state = state.copyWith(items: items);
  }

  void removeItem(String productLocalId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productLocalId != productLocalId).toList(),
    );
  }

  void applyManualDiscount(int amount) {
    state = state.copyWith(manualDiscountAmount: amount.clamp(0, state.subtotal));
  }

  void applyDiscountCode(String code, int value) {
    state = state.copyWith(appliedDiscountCode: code, manualDiscountAmount: value);
  }

  void clearDiscount() => state = state.copyWith(clearDiscount: true);
  void clear()         => state = const CartState();
}

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).totalQuantity,
);

final cartTotalProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).totalAmount,
);

final isInCartProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(cartProvider).items.any((i) => i.productLocalId == id),
);

final productQuantityProvider = Provider.family<int, String>((ref, id) {
  return ref.watch(cartProvider).items
      .where((i) => i.productLocalId == id)
      .firstOrNull
      ?.quantity ?? 0;
});