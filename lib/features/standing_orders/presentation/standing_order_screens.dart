import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_standing_order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../addresses/presentation/address_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../cart/domain/cart_pricing.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../data/fake_standing_order_repository.dart';
import '../domain/standing_order.dart';

final standingOrderRepositoryProvider = Provider<StandingOrderRepository>(
  (ref) => !useFakeBackend ? ApiStandingOrderRepository(ref.watch(apiProvider)) : FakeStandingOrderRepository(
    ref.watch(dealerStoreProvider),
    ref.watch(catalogRepositoryProvider),
    ref.watch(orderRepositoryProvider),
    ref.watch(addressRepositoryProvider),
    ref.watch(notificationRepositoryProvider),
  ),
);

final standingOrdersProvider = FutureProvider<List<StandingOrder>>(
  (ref) => ref.watch(standingOrderRepositoryProvider).standingOrders(),
);

class StandingOrdersScreen extends ConsumerWidget {
  const StandingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standing orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.standingOrderForm),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: AsyncBody(
        value: ref.watch(standingOrdersProvider),
        builder: (orders) => orders.isEmpty
            ? const EmptyState(
                icon: Icons.event_repeat_outlined,
                title: 'No standing orders',
                message: 'Set up the ice you need on fixed days and we will place the order for you.',
              )
            : ListView.separated(
                padding: AppSpacing.pageWithFab,
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _StandingOrderCard(order: orders[i]),
              ),
      ),
    );
  }
}

class _StandingOrderCard extends ConsumerWidget {
  const _StandingOrderCard({required this.order});

  final StandingOrder order;

  Future<void> _save(WidgetRef ref, StandingOrder updated) async {
    await ref.read(standingOrderRepositoryProvider).save(updated);
    ref.invalidate(standingOrdersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final next = order.nextRun(DateTime.now());
    final days = [for (final d in (order.weekdays.toList()..sort())) weekdayLabels[d]].join(', ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(order.name, style: text.titleSmall)),
              StatusChip(
                order.isActive ? 'Active' : 'Paused',
                color: order.isActive ? AppColors.green600 : AppColors.neutral500,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$days · ${order.slot}'),
          Text('${order.items.length} products · ${order.paymentMethod.label}', style: text.bodySmall),
          if (next != null) Text('Next order: ${formatDateShort(next)}', style: text.labelMedium),
          Wrap(
            children: [
              TextButton(
                onPressed: () => context.push(Routes.standingOrderForm, extra: order),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () => _save(ref, order.copyWith(isActive: !order.isActive)),
                child: Text(order.isActive ? 'Pause' : 'Resume'),
              ),
              if (next != null)
                TextButton(
                  onPressed: () => _save(ref, order.copyWith(skippedDates: {...order.skippedDates, next})),
                  child: const Text('Skip next'),
                ),
              TextButton(
                onPressed: () async {
                  final confirmed = await confirmDialog(
                    context,
                    title: 'Delete "${order.name}"?',
                    message: 'No more orders will be created from it.',
                    confirmLabel: 'Delete',
                  );
                  if (!confirmed) return;
                  await ref.read(standingOrderRepositoryProvider).delete(order.id);
                  ref.invalidate(standingOrdersProvider);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StandingOrderFormScreen extends ConsumerStatefulWidget {
  const StandingOrderFormScreen({super.key, this.order});

  final StandingOrder? order;

  @override
  ConsumerState<StandingOrderFormScreen> createState() => _StandingOrderFormScreenState();
}

class _StandingOrderFormScreenState extends ConsumerState<StandingOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.order?.name);
  late final Map<String, int> _items = {...?widget.order?.items};
  late final Set<int> _weekdays = {...?widget.order?.weekdays};
  late String _slot = widget.order?.slot ?? AppConstants.deliverySlots.first.$1;
  late String? _addressId = widget.order?.addressId;
  late PaymentMethod _method = widget.order?.paymentMethod ?? PaymentMethod.cashOnDelivery;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<Product> products) async {
    if (!_formKey.currentState!.validate()) return;
    final lines = [
      for (final p in products)
        if (_items.containsKey(p.id)) CartLine(p, _items[p.id]!),
    ];
    final String? problem = switch (()) {
      _ when lines.isEmpty => 'Add at least one product',
      _ when !CartBill.calculate(lines).meetsMinimumOrder =>
        'The minimum order value is ${money(AppConstants.minOrderValue)}',
      _ when _weekdays.isEmpty => 'Choose at least one delivery day',
      _ when _addressId == null => 'Choose a delivery address',
      _ => null,
    };
    if (problem != null) {
      showMessage(context, problem, isError: true);
      return;
    }
    await ref
        .read(standingOrderRepositoryProvider)
        .save(
          StandingOrder(
            id: widget.order?.id ?? 'so-${DateTime.now().millisecondsSinceEpoch}',
            name: _name.text.trim(),
            items: _items,
            weekdays: _weekdays,
            slot: _slot,
            addressId: _addressId!,
            paymentMethod: _method,
            lastRun: widget.order?.lastRun ?? DateTime.now(),
            isActive: widget.order?.isActive ?? true,
            skippedDates: widget.order?.skippedDates ?? const {},
          ),
        );
    ref.invalidate(standingOrdersProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider).value ?? const [];
    _addressId ??= addresses.where((a) => a.isDefault).firstOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.order == null ? 'New standing order' : 'Edit standing order')),
      body: AsyncBody(
        value: ref.watch(productsProvider),
        builder: (products) => Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              LabeledField(
                label: 'Name, for example Weekend stock',
                child: TextFormField(
                  controller: _name,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
                  decoration: InputDecoration(hintText: enterHint('Name, for example Weekend stock')),
                ),
              ),
              const SectionTitle('Products'),
              for (final p in products.where((p) => p.inStock))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('${p.name} (${p.packSize})\n${money(p.basePrice)} / ${p.unit}')),
                        if (_items.containsKey(p.id))
                          QuantityStepper(
                            value: _items[p.id]!,
                            min: p.minOrderQty - p.stepQty,
                            step: p.stepQty,
                            onChanged: (v) => setState(() {
                              v < p.minOrderQty ? _items.remove(p.id) : _items[p.id] = v;
                            }),
                          )
                        else
                          TextButton(
                            onPressed: () => setState(() => _items[p.id] = p.minOrderQty),
                            child: const Text('Add'),
                          ),
                      ],
                    ),
                  ),
                ),
              const SectionTitle('Delivery days'),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in weekdayLabels.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _weekdays.contains(e.key),
                      showCheckmark: false,
                      onSelected: (on) => setState(() => on ? _weekdays.add(e.key) : _weekdays.remove(e.key)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Delivery slot',
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  initialValue: _slot,
                  decoration: InputDecoration(hintText: selectHint('Delivery slot')),
                  items: [
                    for (final (label, _) in AppConstants.deliverySlots)
                      DropdownMenuItem(value: label, child: Text(label)),
                  ],
                  onChanged: (v) => setState(() => _slot = v!),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Deliver to',
                child: DropdownButtonFormField<String>(
                  initialValue: _addressId,
                  isExpanded: true,
                  decoration: InputDecoration(hintText: selectHint('Deliver to')),
                  items: [for (final a in addresses) DropdownMenuItem(value: a.id, child: Text(a.label))],
                  onChanged: (v) => setState(() => _addressId = v),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Payment',
                child: DropdownButtonFormField<PaymentMethod>(
                  isExpanded: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  initialValue: _method,
                  decoration: InputDecoration(hintText: selectHint('Payment')),
                  items: const [
                    DropdownMenuItem(value: PaymentMethod.credit, child: Text('Credit account')),
                    DropdownMenuItem(value: PaymentMethod.cashOnDelivery, child: Text('Cash on delivery')),
                  ],
                  onChanged: (v) => setState(() => _method = v!),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _save(products), child: const Text('Save standing order')),
            ],
          ),
        ),
      ),
    );
  }
}
