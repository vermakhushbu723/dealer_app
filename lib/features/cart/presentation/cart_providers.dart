import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../offers/domain/offer.dart';
import '../domain/cart_pricing.dart';

/// Product id to quantity, saved so the cart survives a restart.
class CartController extends Notifier<Map<String, int>> {
  static const _key = 'cart';

  LocalStore get _store => ref.read(dealerStoreProvider);

  @override
  Map<String, int> build() {
    ref.watch(dealerStoreProvider);
    return (_store.readMap(_key) ?? const {}).cast<String, int>();
  }

  void _update(Map<String, int> next) {
    state = next;
    _store.writeMap(_key, next);
  }

  void add(Product product) => setQuantity(product, product.minOrderQty);

  void setQuantity(Product product, int quantity) {
    _update({...state, product.id: quantity});
  }

  void remove(String productId) => _update({...state}..remove(productId));

  /// Adds several items, for example from a past order. Quantities are raised
  /// to the product's minimum and existing cart lines are added to.
  void addAll(Iterable<(Product, int)> items) {
    final next = {...state};
    for (final (product, quantity) in items) {
      final total = (next[product.id] ?? 0) + quantity;
      next[product.id] = total < product.minOrderQty ? product.minOrderQty : total;
    }
    _update(next);
  }

  void clear() => _update(const {});
}

final cartProvider = NotifierProvider<CartController, Map<String, int>>(CartController.new);

class AppliedCoupon extends Notifier<Offer?> {
  @override
  Offer? build() {
    ref.watch(dealerStoreProvider);
    return null;
  }

  void apply(Offer offer) => state = offer;

  void clear() => state = null;
}

final appliedCouponProvider = NotifierProvider<AppliedCoupon, Offer?>(AppliedCoupon.new);

/// Null until the product list has loaded.
final cartBillProvider = Provider<CartBill?>((ref) {
  final products = ref.watch(productsProvider).value;
  if (products == null) return null;
  final cart = ref.watch(cartProvider);
  final lines = [
    for (final product in products)
      if (cart.containsKey(product.id)) CartLine(product, cart[product.id]!),
  ];
  final coupon = ref.watch(appliedCouponProvider);
  final base = CartBill.calculate(lines);
  final discount = coupon?.discountOn(base.subtotal) ?? 0;
  return discount > 0 ? CartBill.calculate(lines, discount: discount, couponCode: coupon!.code) : base;
});

final cartItemCountProvider = Provider<int>((ref) => ref.watch(cartProvider).length);
