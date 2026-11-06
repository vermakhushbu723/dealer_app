import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../catalog/presentation/catalog_screens.dart';
import '../domain/cart_pricing.dart';
import 'cart_providers.dart';
import 'cart_widgets.dart';

/// The price rows shared by the cart and checkout.
class BillSummary extends StatelessWidget {
  const BillSummary({super.key, required this.bill});

  final CartBill bill;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          InfoRow('Subtotal', money(bill.subtotal)),
          if (bill.discount > 0)
            InfoRow('Discount (${bill.couponCode})', '- ${money(bill.discount)}', valueColor: AppColors.green600),
          InfoRow('GST', money(bill.gst)),
          InfoRow('Delivery', bill.deliveryFee == 0 ? 'Free' : money(bill.deliveryFee)),
          const Divider(height: 16),
          InfoRow('Total', money(bill.total), bold: true),
        ],
      ),
    );
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref.watch(cartBillProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (bill != null && bill.lines.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: 'Empty the cart?',
                  message: 'All items will be removed.',
                  confirmLabel: 'Empty cart',
                );
                if (confirmed) {
                  ref.read(cartProvider.notifier).clear();
                }
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: bill == null
          ? const Center(child: CircularProgressIndicator())
          : bill.lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add ice from the product list to place an order.',
              actionLabel: 'Browse products',
              onAction: () => context.go(Routes.catalog),
            )
          : _CartBody(bill: bill),
      bottomNavigationBar: bill == null || bill.lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: AppSpacing.bottomBar,
                child: FilledButton(
                  onPressed: bill.meetsMinimumOrder ? () => context.push(Routes.checkout) : null,
                  child: Text('Checkout · ${money(bill.total)}'),
                ),
              ),
            ),
    );
  }
}

class _CartBody extends ConsumerWidget {
  const _CartBody({required this.bill});

  final CartBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final amountToFreeDelivery = AppConstants.freeDeliveryAbove - bill.subtotal;
    return ListView(
      padding: AppSpacing.page,
      children: [
        if (!bill.meetsMinimumOrder) ...[
          NoticeBanner('The minimum order value is ${money(AppConstants.minOrderValue)}.', color: AppColors.red600),
          const SizedBox(height: 10),
        ] else if (amountToFreeDelivery > 0) ...[
          NoticeBanner(
            'Add ${money(amountToFreeDelivery)} more for free delivery.',
            color: AppColors.sky600,
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 10),
        ],
        for (final line in bill.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ProductImage(line.product.image, size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.product.name, style: text.titleSmall),
                        Text(line.product.packSize, style: text.bodySmall),
                        Text(
                          '${money(line.unitPrice)} × ${line.quantity} = ${money(line.amount)}',
                          style: text.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  AddToCartControl(product: line.product),
                ],
              ),
            ),
          ),
        const SectionTitle('Bill'),
        BillSummary(bill: bill),
      ],
    );
  }
}
