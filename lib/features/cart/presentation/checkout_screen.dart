import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../addresses/domain/address.dart';
import '../../addresses/presentation/address_providers.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import '../domain/delivery_slots.dart';
import 'cart_providers.dart';
import 'cart_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _notes = TextEditingController();
  late DateTime _date = firstDeliveryDate(DateTime.now());
  String? _slot;
  String? _addressId;
  PaymentMethod? _method;
  bool _placing = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: firstDeliveryDate(now),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _slot = null;
      });
    }
  }

  Address? _selectedAddress(List<Address> addresses) {
    if (addresses.isEmpty) return null;
    return addresses.where((a) => a.id == _addressId).firstOrNull ??
        addresses.where((a) => a.isDefault).firstOrNull ??
        addresses.first;
  }

  Future<void> _placeOrder(Address address) async {
    final bill = ref.read(cartBillProvider)!;
    setState(() => _placing = true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .place(
            PlaceOrderRequest(
              bill: bill,
              address: address,
              deliveryDate: _date,
              slot: _slot!,
              paymentMethod: _method!,
              notes: _notes.text.trim(),
            ),
          );
      ref.read(cartProvider.notifier).clear();
      ref.read(appliedCouponProvider.notifier).clear();
      refreshOrdersAndBalance(ref);
      if (mounted) context.go(Routes.orderPlaced(order.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = ref.watch(cartBillProvider);
    final addresses = ref.watch(addressesProvider);
    final credit = ref.watch(creditSummaryProvider).value;
    final slots = availableSlots(_date, DateTime.now());
    final address = _selectedAddress(addresses.value ?? const []);

    final creditEnough = credit != null && bill != null && credit.hasCreditAccount && bill.total <= credit.available;
    final canPlace = address != null && _slot != null && _method != null && bill != null && bill.lines.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: AsyncBody(
        value: addresses,
        builder: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 16),
          children: [
            SectionTitle('Deliver to', actionLabel: 'Manage', onAction: () => context.push(Routes.addresses)),
            if (items.isEmpty)
              const NoticeBanner('Add a delivery address to continue.', color: AppColors.red600)
            else
              RadioGroup<String>(
                groupValue: address?.id,
                onChanged: (id) => setState(() => _addressId = id),
                child: Column(
                  children: [
                    for (final a in items)
                      RadioListTile<String>(
                        value: a.id,
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.label),
                        subtitle: Text(a.singleLine),
                      ),
                  ],
                ),
              ),
            const SectionTitle('Delivery date'),
            AppCard(
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.sky600),
                  const SizedBox(width: 10),
                  Expanded(child: Text(formatDateShort(_date))),
                  const Text('Change'),
                ],
              ),
            ),
            const SectionTitle('Delivery slot'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final slot in slots)
                  ChoiceChip(
                    label: Text(slot),
                    selected: _slot == slot,
                    onSelected: (_) => setState(() => _slot = slot),
                  ),
              ],
            ),
            const SectionTitle('Payment'),
            RadioGroup<PaymentMethod>(
              groupValue: _method,
              onChanged: (m) => setState(() => _method = m),
              child: Column(
                children: [
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.credit,
                    enabled: creditEnough,
                    contentPadding: EdgeInsets.zero,
                    title: Text(PaymentMethod.credit.label),
                    subtitle: Text(
                      credit == null || !credit.hasCreditAccount
                          ? 'No credit account on file'
                          : '${money(credit.available)} available of ${money(credit.limit)}',
                    ),
                  ),
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.online,
                    contentPadding: EdgeInsets.zero,
                    title: Text(PaymentMethod.online.label),
                    subtitle: const Text('Demo: no payment gateway is connected, so this is marked paid straight away'),
                  ),
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.cashOnDelivery,
                    contentPadding: EdgeInsets.zero,
                    title: Text(PaymentMethod.cashOnDelivery.label),
                  ),
                ],
              ),
            ),
            const SectionTitle('Notes for delivery'),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Enter gate number or unloading instructions (optional)'),
            ),
            const SectionTitle('Bill'),
            if (bill != null) BillSummary(bill: bill),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: AppSpacing.bottomBar,
          child: LoadingButton(
            label: bill == null ? 'Place order' : 'Place order · ${money(bill.total)}',
            loading: _placing,
            onPressed: canPlace ? () => _placeOrder(address) : null,
          ),
        ),
      ),
    );
  }
}
