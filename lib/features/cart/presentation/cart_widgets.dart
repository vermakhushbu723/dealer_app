import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../catalog/domain/product.dart';
import 'cart_providers.dart';

class CartIconButton extends ConsumerWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    return IconButton(
      tooltip: 'Cart',
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined)),
      onPressed: () => context.push(Routes.cart),
    );
  }
}

/// An Add button that turns into a quantity stepper once the product is in the cart.
class AddToCartControl extends ConsumerWidget {
  const AddToCartControl({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider)[product.id];
    final cart = ref.read(cartProvider.notifier);
    if (quantity == null) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 32)),
        onPressed: () => cart.add(product),
        child: const Text('Add'),
      );
    }
    return QuantityStepper(
      value: quantity,
      // Stepping below the minimum removes the line, so the floor is one step under it.
      min: product.minOrderQty - product.stepQty,
      step: product.stepQty,
      max: product.availableQty,
      onChanged: (v) => v < product.minOrderQty ? cart.remove(product.id) : cart.setQuantity(product, v),
    );
  }
}

class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(cartBillProvider);
    if (bill == null || bill.lines.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
        child: FilledButton(
          onPressed: () => context.push(Routes.cart),
          child: Text('View cart · ${bill.lines.length} items · ${money(bill.subtotal)}'),
        ),
      ),
    );
  }
}
