import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../cart/presentation/cart_widgets.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../catalog/presentation/catalog_screens.dart';
import '../../payments/data/pdf_documents.dart';
import '../domain/order.dart';
import 'order_providers.dart';

Color orderStatusColor(OrderStatus status) => switch (status) {
  OrderStatus.delivered => AppColors.green600,
  OrderStatus.cancelled => AppColors.red600,
  OrderStatus.failed => AppColors.red600,
  OrderStatus.outForDelivery => AppColors.amber600,
  _ => AppColors.sky600,
};

/// Puts an order's items back in the cart, leaving out anything out of stock.
Future<void> reorder(BuildContext context, WidgetRef ref, Order order) async {
  final products = await ref.read(productsProvider.future);
  final items = [
    for (final line in order.lines)
      for (final product in products)
        if (product.id == line.productId && product.inStock) (product, line.quantity),
  ];
  ref.read(cartProvider.notifier).addAll(items);
  if (!context.mounted) return;
  if (items.length < order.lines.length) {
    showMessage(context, 'Some items are out of stock and were not added');
  }
  context.push(Routes.cart);
}

Future<void> shareInvoice(WidgetRef ref, Order order) async {
  final bytes = await buildInvoicePdf(order, ref.read(currentDealerProvider));
  await Printing.sharePdf(bytes: bytes, filename: '${order.invoiceNumber}.pdf');
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push(Routes.order(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(order.number, style: text.titleSmall)),
              StatusChip(order.status.label, color: orderStatusColor(order.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.lines.map((l) => '${l.name} × ${l.quantity}').join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('Delivery ${formatDateShort(order.deliveryDate)}, ${order.slot}', style: text.bodySmall),
              ),
              Text(money(order.total), style: text.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _tabs = <(String, OrderStatus?)>[
    ('All', null),
    ('New orders', OrderStatus.placed),
    ('Accepted', OrderStatus.accepted),
    ('Processing', OrderStatus.processing),
    ('Ready for dispatch', OrderStatus.readyForDispatch),
    ('Out for delivery', OrderStatus.outForDelivery),
    ('Delivered', OrderStatus.delivered),
    ('Cancelled', OrderStatus.cancelled),
  ];

  String _query = '';

  Widget _list(List<Order> orders, String tabLabel) {
    final query = _query.trim().toLowerCase();
    final items = query.isEmpty
        ? orders
        : orders
              .where((o) => '${o.number} ${o.lines.map((l) => l.name).join(' ')}'.toLowerCase().contains(query))
              .toList();
    if (items.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders in $tabLabel');
    return RefreshIndicator(
      onRefresh: () async => refreshOrdersAndBalance(ref),
      child: ListView.separated(
        padding: AppSpacing.page,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => OrderTile(order: items[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          actions: const [CartIconButton()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.sky700,
            indicatorColor: AppColors.sky700,
            tabs: [for (final (label, _) in _tabs) Tab(text: label)],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search by order ID or product',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: AsyncBody(
                value: ref.watch(ordersProvider),
                onRetry: () => ref.invalidate(ordersProvider),
                builder: (orders) => TabBarView(
                  children: [
                    for (final (label, status) in _tabs)
                      _list(
                        status == null ? orders : orders.where((o) => o.status == status).toList(),
                        label.toLowerCase(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 64, color: AppColors.green600),
              const SizedBox(height: 12),
              Text('Order placed', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('We will keep you updated as your order moves.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.go(Routes.order(orderId)), child: const Text('Track order')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => context.go(Routes.home), child: const Text('Back to home')),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // Keeps the tracking steps current while the screen is open.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ref.read(orderProvider(widget.orderId)).value?.isActive ?? false) ref.invalidate(ordersProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _cancel(Order order) async {
    final reason = await showModalBottomSheet<String>(context: context, builder: (_) => const _CancelSheet());
    if (reason == null || !mounted) return;
    try {
      await ref.read(orderRepositoryProvider).cancel(order.id, reason);
      refreshOrdersAndBalance(ref);
      if (mounted) showMessage(context, 'Order cancelled');
    } catch (e) {
      refreshOrdersAndBalance(ref);
      if (mounted) showMessage(context, '$e', isError: true);
    }
  }

  Future<void> _rate(Order order) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RatingSheet(orderId: order.id),
    );
    if (saved ?? false) ref.invalidate(ordersProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: AsyncBody(
        value: ref.watch(orderProvider(widget.orderId)),
        builder: (order) {
          if (order == null) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found');
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: AppSpacing.page,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.number, style: text.titleMedium)),
                  StatusChip(order.status.label, color: orderStatusColor(order.status)),
                ],
              ),
              Text('Placed ${formatDateTime(order.placedAt)}', style: text.bodySmall),
              const SectionTitle('Tracking'),
              AppCard(child: OrderTimeline(order: order)),
              if (order.status == OrderStatus.outForDelivery && order.driver != null) ...[
                const SizedBox(height: 10),
                DriverCard(order: order),
              ],
              if (order.cancelReason != null) ...[
                const SizedBox(height: 10),
                NoticeBanner('Cancelled: ${order.cancelReason}', color: AppColors.red600),
              ],
              const SectionTitle('Items'),
              AppCard(
                child: Column(
                  children: [
                    for (final l in order.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ProductImage(l.image, size: 44),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${l.name} (${l.packSize})\n${l.quantity} × ${money(l.unitPrice)}')),
                            Text(money(l.amount), style: text.labelLarge),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SectionTitle('Bill'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Subtotal', money(order.subtotal)),
                    if (order.discount > 0)
                      InfoRow(
                        'Discount (${order.couponCode})',
                        '- ${money(order.discount)}',
                        valueColor: AppColors.green600,
                      ),
                    InfoRow('GST', money(order.gst)),
                    InfoRow('Delivery', order.deliveryFee == 0 ? 'Free' : money(order.deliveryFee)),
                    const Divider(height: 16),
                    InfoRow('Total', money(order.total), bold: true),
                    InfoRow('Payment', order.paymentMethod.label),
                    InfoRow('Status', order.paymentStatus.label),
                  ],
                ),
              ),
              const SectionTitle('Delivery'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow('Date', formatDateShort(order.deliveryDate)),
                    InfoRow('Slot', order.slot),
                    InfoRow(order.address.label, order.address.singleLine),
                    if (order.notes.isNotEmpty) InfoRow('Notes', order.notes),
                  ],
                ),
              ),
              if (order.isDelivered) ...[
                const SectionTitle('Your rating'),
                order.rating == null
                    ? OutlinedButton(onPressed: () => _rate(order), child: const Text('Rate this delivery'))
                    : AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                for (var i = 1; i <= 5; i++)
                                  Icon(i <= order.rating! ? Icons.star : Icons.star_border, color: AppColors.amber600),
                              ],
                            ),
                            if ((order.review ?? '').isNotEmpty) Text(order.review!),
                          ],
                        ),
                      ),
              ],
              const SizedBox(height: 12),
              if (order.isActive) ...[
                FilledButton.icon(
                  onPressed: () => context.push(Routes.trackOrder(order.id)),
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Track my delivery'),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: () => reorder(context, ref, order),
                icon: const Icon(Icons.replay),
                label: const Text('Reorder'),
              ),
              if (order.status != OrderStatus.cancelled) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => shareInvoice(ref, order),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download GST invoice'),
                ),
              ],
              if (order.isDelivered) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.newComplaint, extra: order.id),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Report damaged, melted or short delivery'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.newTicket, extra: order.number),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Raise a support ticket'),
              ),
              if (order.canCancel) ...[
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.red600),
                  onPressed: () => _cancel(order),
                  child: const Text('Cancel order'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final steps = order.status == OrderStatus.cancelled
        ? [for (final e in order.events) e.status]
        : const [
            OrderStatus.placed,
            OrderStatus.accepted,
            OrderStatus.processing,
            OrderStatus.readyForDispatch,
            OrderStatus.outForDelivery,
            OrderStatus.delivered,
          ];
    return Column(
      children: [
        for (final (i, step) in steps.indexed)
          Builder(
            builder: (context) {
              final event = order.events.where((e) => e.status == step).firstOrNull;
              final done = event != null || step.index < order.status.index;
              final color = step == OrderStatus.cancelled
                  ? AppColors.red600
                  : (done ? AppColors.green600 : AppColors.sky200);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: color),
                        if (i < steps.length - 1) Expanded(child: Container(width: 2, color: color)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(step.label, style: Theme.of(context).textTheme.labelLarge),
                            if (event != null)
                              Text(formatDateTime(event.at), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final driver = order.driver!;
    final text = Theme.of(context).textTheme;
    return GradientHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: AppColors.sky700),
              const SizedBox(width: 10),
              Expanded(child: Text('${driver.name}\n${driver.vehicle}', style: text.labelLarge)),
              IconButton.filled(
                tooltip: 'Call driver',
                style: IconButton.styleFrom(backgroundColor: AppColors.sky700),
                onPressed: () => ContactLauncher.call(driver.phone),
                icon: const Icon(Icons.call, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('The rider takes a photo when your order is delivered.', style: text.bodySmall),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet();

  static const _reasons = [
    'Ordered by mistake',
    'Need a different quantity',
    'Delivery time does not suit',
    'No longer needed',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text('Why are you cancelling?', style: Theme.of(context).textTheme.titleSmall)),
          for (final reason in _reasons) ListTile(title: Text(reason), onTap: () => Navigator.pop(context, reason)),
        ],
      ),
    );
  }
}

class _RatingSheet extends ConsumerStatefulWidget {
  const _RatingSheet({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  final _review = TextEditingController();
  int _stars = 5;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(orderRepositoryProvider).rate(widget.orderId, _stars, _review.text.trim());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rate this delivery', style: Theme.of(context).textTheme.titleMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i stars',
                  icon: Icon(i <= _stars ? Icons.star : Icons.star_border, size: 32, color: AppColors.amber600),
                  onPressed: () => setState(() => _stars = i),
                ),
            ],
          ),
          TextField(
            controller: _review,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Enter your review (optional)'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _submit, child: const Text('Submit')),
        ],
      ),
    );
  }
}

/// One My Orders sub-menu: the orders in a single status.
class OrderStatusListScreen extends ConsumerWidget {
  const OrderStatusListScreen({super.key, required this.status});

  final OrderStatus status;

  String get _title => switch (status) {
    OrderStatus.placed => 'New orders',
    OrderStatus.accepted => 'Accepted orders',
    OrderStatus.processing => 'Processing orders',
    OrderStatus.readyForDispatch => 'Ready for dispatch',
    OrderStatus.outForDelivery => 'Out for delivery',
    OrderStatus.delivered => 'Delivered orders',
    OrderStatus.cancelled => 'Cancelled orders',
    OrderStatus.failed => 'Failed deliveries',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final items = orders.where((o) => o.status == status).toList();
          if (items.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: 'No ${_title.toLowerCase()}');
          return RefreshIndicator(
            onRefresh: () async => refreshOrdersAndBalance(ref),
            child: ListView.separated(
              padding: AppSpacing.page,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => OrderTile(order: items[i]),
            ),
          );
        },
      ),
    );
  }
}
