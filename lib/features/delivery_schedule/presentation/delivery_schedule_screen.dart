import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_delivery_request_repository.dart';
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
import '../../cart/domain/delivery_slots.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../standing_orders/domain/standing_order.dart';
import '../../standing_orders/presentation/standing_order_screens.dart';
import '../data/fake_delivery_request_repository.dart';
import '../domain/delivery_request.dart';

final deliveryRequestRepositoryProvider = Provider<DeliveryRequestRepository>(
  (ref) => useFakeBackend ? FakeDeliveryRequestRepository(ref.watch(dealerStoreProvider)) : ApiDeliveryRequestRepository(ref.watch(apiProvider)),
);

final deliveryRequestsProvider = FutureProvider<List<DeliveryRequest>>(
  (ref) => ref.watch(deliveryRequestRepositoryProvider).requests(),
);

class ScheduleEntry {
  const ScheduleEntry(this.date, this.title, this.subtitle, {this.order, this.request});

  final DateTime date;
  final String title;
  final String subtitle;
  final Order? order;
  final DeliveryRequest? request;
}

/// Everything expected on [day]: orders, standing orders and requests.
List<ScheduleEntry> entriesOn(
  DateTime day,
  List<Order> orders,
  List<StandingOrder> standing,
  List<DeliveryRequest> requests,
) => [
  for (final o in orders)
    if (o.status != OrderStatus.cancelled && isSameDay(o.deliveryDate, day))
      ScheduleEntry(day, o.number, '${o.status.label} · ${o.slot}', order: o),
  for (final s in standing)
    if (s.isDueOn(day)) ScheduleEntry(day, s.name, 'Standing order · ${s.slot}'),
  for (final r in requests)
    if (isSameDay(r.date, day)) ScheduleEntry(day, 'Delivery requested', '${r.slot} · ${r.addressLabel}', request: r),
];

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});

  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = entry.order;
    final request = entry.request;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        onTap: order == null ? null : () => context.push(Routes.order(order.id)),
        child: Row(
          children: [
            Expanded(child: Text('${formatDateShort(entry.date)} · ${entry.title}\n${entry.subtitle}')),
            if (request != null)
              TextButton(
                onPressed: () async {
                  await ref.read(deliveryRequestRepositoryProvider).cancel(request.id);
                  ref.invalidate(deliveryRequestsProvider);
                },
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}

class UpcomingDeliveriesScreen extends ConsumerWidget {
  const UpcomingDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).value ?? const <Order>[];
    final standing = ref.watch(standingOrdersProvider).value ?? const <StandingOrder>[];
    final requests = ref.watch(deliveryRequestsProvider).value ?? const <DeliveryRequest>[];
    final today = dateOnly(DateTime.now());
    final upcoming = [
      for (var i = 0; i < 14; i++) ...entriesOn(today.add(Duration(days: i)), orders, standing, requests),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming deliveries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.requestDelivery),
        icon: const Icon(Icons.add),
        label: const Text('Request delivery'),
      ),
      body: upcoming.isEmpty
          ? const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No upcoming deliveries',
              message: 'Deliveries in the next 14 days will show up here.',
            )
          : ListView(
              padding: AppSpacing.pageWithFab,
              children: [for (final e in upcoming) _EntryTile(entry: e)],
            ),
    );
  }
}

class DeliveryScheduleScreen extends ConsumerStatefulWidget {
  const DeliveryScheduleScreen({super.key});

  @override
  ConsumerState<DeliveryScheduleScreen> createState() => _DeliveryScheduleScreenState();
}

class _DeliveryScheduleScreenState extends ConsumerState<DeliveryScheduleScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider).value ?? const <Order>[];
    final standing = ref.watch(standingOrdersProvider).value ?? const <StandingOrder>[];
    final requests = ref.watch(deliveryRequestsProvider).value ?? const <DeliveryRequest>[];
    List<ScheduleEntry> on(DateTime day) => entriesOn(day, orders, standing, requests);

    final selectedEntries = on(_selected);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.requestDelivery),
        icon: const Icon(Icons.add),
        label: const Text('Request delivery'),
      ),
      body: ListView(
        padding: AppSpacing.pageWithFab,
        children: [
          AppCard(
            padding: const EdgeInsets.all(8),
            child: _MonthCalendar(
              month: _month,
              selected: _selected,
              hasEntries: (day) => on(day).isNotEmpty,
              onMonthChanged: (m) => setState(() => _month = m),
              onSelected: (d) => setState(() => _selected = d),
            ),
          ),
          SectionTitle(formatDateShort(_selected)),
          if (selectedEntries.isEmpty) const Text('No deliveries on this day.'),
          for (final e in selectedEntries) _EntryTile(entry: e),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push(Routes.upcomingDeliveries),
            child: const Text('Upcoming deliveries'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.push(Routes.standingOrders), child: const Text('Standing orders')),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.hasEntries,
    required this.onMonthChanged,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selected;
  final bool Function(DateTime) hasEntries;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = month.weekday - 1;
    final today = dateOnly(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonthChanged(DateTime(month.year, month.month - 1)),
            ),
            Expanded(
              child: Text(formatMonthYear(month), textAlign: TextAlign.center, style: text.titleSmall),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1)),
            ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          // Square days on a phone; flatter ones in a wide browser window, so the month fits.
          childAspectRatio: MediaQuery.sizeOf(context).width >= 900 ? 2.4 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final label in weekdayLabels.values) Center(child: Text(label, style: text.labelSmall)),
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              Builder(
                builder: (context) {
                  final day = DateTime(month.year, month.month, d);
                  final isSelected = day == selected;
                  return InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onSelected(day),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.sky700 : null,
                        border: day == today ? Border.all(color: AppColors.sky600) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$d', style: TextStyle(color: isSelected ? Colors.white : AppColors.neutral900)),
                          Container(
                            height: 5,
                            width: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: !hasEntries(day)
                                  ? Colors.transparent
                                  : (isSelected ? Colors.white : AppColors.sky600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class RequestDeliveryScreen extends ConsumerStatefulWidget {
  const RequestDeliveryScreen({super.key});

  @override
  ConsumerState<RequestDeliveryScreen> createState() => RequestDeliveryScreenState();
}

class RequestDeliveryScreenState extends ConsumerState<RequestDeliveryScreen> {
  final _details = TextEditingController();
  late DateTime _date = firstDeliveryDate(DateTime.now());
  String? _slot;
  String? _addressId;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: firstDeliveryDate(now),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _slot = null;
      });
    }
  }

  Future<void> _submit() async {
    final addresses = ref.read(addressesProvider).value ?? const [];
    final address = addresses.where((a) => a.id == _addressId).firstOrNull ?? addresses.firstOrNull;
    if (_slot == null || address == null || _details.text.trim().isEmpty) {
      showMessage(context, 'Please choose a slot and tell us what you need', isError: true);
      return;
    }
    final now = DateTime.now();
    await ref
        .read(deliveryRequestRepositoryProvider)
        .add(
          DeliveryRequest(
            id: 'r-${now.microsecondsSinceEpoch}',
            date: _date,
            slot: _slot!,
            addressLabel: address.label,
            details: _details.text.trim(),
            requestedAt: now,
          ),
        );
    ref.invalidate(deliveryRequestsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request delivery')),
    body: _form(context),
  );

  Widget _form(BuildContext context) {
    final addresses = ref.watch(addressesProvider).value ?? const [];
    final slots = availableSlots(_date, DateTime.now());
    _addressId ??= (addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull)?.id;
    return SingleChildScrollView(
      padding: AppSpacing.page,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Our team will confirm this and create the order for you.'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(formatDateShort(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final slot in slots)
                ChoiceChip(label: Text(slot), selected: _slot == slot, onSelected: (_) => setState(() => _slot = slot)),
            ],
          ),
          const SizedBox(height: 12),
          if (addresses.isNotEmpty)
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
            label: 'What do you need?',
            child: TextField(
              controller: _details,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Enter what you need, for example 20 bags of cube ice'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _submit, child: const Text('Send request')),
          Text(AppConstants.serviceArea, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
