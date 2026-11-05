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
import '../../offers/presentation/offers_screen.dart';
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
                  ref.read(appliedCouponProvider.notifier).clear();
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
        const SectionTitle('Coupon'),
        _CouponCard(subtotal: bill.subtotal),
        const SectionTitle('Bill'),
        BillSummary(bill: bill),
      ],
    );
  }
}

class _CouponCard extends ConsumerStatefulWidget {
  const _CouponCard({required this.subtotal});

  final double subtotal;

  @override
  ConsumerState<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends ConsumerState<_CouponCard> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final offers = await ref.read(offersProvider.future);
    if (!mounted) return;
    final offer = offers.where((o) => o.code == code).firstOrNull;
    if (offer == null) {
      showMessage(context, 'This coupon code is not valid', isError: true);
    } else if (offer.discountOn(widget.subtotal) == 0) {
      showMessage(context, 'This coupon needs an order of ${money(offer.minOrder)} or more', isError: true);
    } else {
      ref.read(appliedCouponProvider.notifier).apply(offer);
      _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupon = ref.watch(appliedCouponProvider);
    final isActive = coupon != null && coupon.discountOn(widget.subtotal) > 0;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: coupon == null
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Enter coupon code', isDense: true),
                  ),
                ),
                TextButton(onPressed: _apply, child: const Text('Apply')),
                TextButton(onPressed: () => context.push(Routes.offers), child: const Text('View offers')),
              ],
            )
          : Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.info_outline,
                  color: isActive ? AppColors.green600 : AppColors.amber600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isActive
                        ? '${coupon.code} applied'
                        : '${coupon.code} needs an order of ${money(coupon.minOrder)} or more',
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(appliedCouponProvider.notifier).clear(),
                  child: const Text('Remove'),
                ),
              ],
            ),
    );
  }
}
