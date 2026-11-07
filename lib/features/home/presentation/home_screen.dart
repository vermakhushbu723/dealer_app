import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../catalog/presentation/catalog_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/order_screens.dart';
import '../../payments/presentation/payment_screens.dart';
import '../../standing_orders/presentation/standing_order_screens.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _placeDueStandingOrders();
  }

  Future<void> _placeDueStandingOrders() async {
    await ref.read(paymentRepositoryProvider).remindIfOverdue();
    final placed = await ref.read(standingOrderRepositoryProvider).placeDueOrders();
    if (mounted) ref.invalidate(notificationsProvider);
    if (placed == 0 || !mounted) return;
    refreshOrdersAndBalance(ref);
    showMessage(context, '$placed standing ${placed == 1 ? 'order' : 'orders'} placed for today');
  }

  @override
  Widget build(BuildContext context) {
    final dealer = ref.watch(currentDealerProvider);
    final credit = ref.watch(creditSummaryProvider).value;
    final orders = ref.watch(ordersProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const [];
    final active = orders.where((o) => o.isActive).toList();
    final onTheWay = active.where((o) => o.status == OrderStatus.outForDelivery).firstOrNull;
    final lastDelivered = orders.where((o) => o.isDelivered).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(AppConstants.logo, height: 38),
        centerTitle: false,
        actions: const [NotificationBell(), CartIconButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshOrdersAndBalance(ref);
          ref.invalidate(productsProvider);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text('Hello, ${dealer.ownerName}', style: Theme.of(context).textTheme.headlineMedium),
            Text(dealer.businessName),
            const SizedBox(height: 12),
            if (credit != null) CreditCard(credit: credit, onTap: () => context.go(Routes.payments)),
            if (credit != null && credit.overdue > 0) ...[
              const SizedBox(height: 10),
              const NoticeBanner('You have an overdue balance. Open Payments to clear it.', color: AppColors.red600),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go(Routes.catalog),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Place a new order'),
            ),
            if (lastDelivered != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => reorder(context, ref, lastDelivered),
                icon: const Icon(Icons.replay),
                label: const Text('Repeat previous order'),
              ),
            ],
            if (onTheWay != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => context.push(Routes.trackOrder(onTheWay.id)),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Your order is on the way. Track it'),
              ),
            ],
            if (active.isNotEmpty) ...[
              SectionTitle('Active orders', actionLabel: 'See all', onAction: () => context.go(Routes.orders)),
              for (final order in active.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OrderTile(order: order),
                ),
            ],
            const SectionTitle('Quick actions'),
            // Three across on any phone, more in a wide browser window.
            GridView.extent(
              maxCrossAxisExtent: 130,
              childAspectRatio: 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: const [
                _QuickAction(Icons.location_on_outlined, 'Track delivery', Routes.trackDelivery),
                _QuickAction(Icons.price_change_outlined, 'Price list', Routes.priceList),
                _QuickAction(Icons.calendar_month_outlined, 'Delivery schedule', Routes.deliverySchedule),
                _QuickAction(Icons.report_gmailerrorred_outlined, 'Complaints', Routes.complaints),
                _QuickAction(Icons.description_outlined, 'GST bills', Routes.invoices),
                _QuickAction(Icons.account_balance_wallet_outlined, 'Ledger', Routes.ledger),
                _QuickAction(Icons.local_offer_outlined, 'Offers', Routes.offers),
                _QuickAction(Icons.event_repeat_outlined, 'Standing orders', Routes.standingOrders),
                _QuickAction(Icons.support_agent_outlined, 'Support', Routes.support),
              ],
            ),
            SectionTitle('Products', actionLabel: 'See all', onAction: () => context.go(Routes.catalog)),
            for (final product in products.where((p) => p.inStock).take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ProductTile(product: product),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      onTap: () => context.push(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.sky600),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
