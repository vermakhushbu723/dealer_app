import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_ice_box_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/fake_ice_box_repository.dart';
import '../domain/ice_box.dart';

final iceBoxRepositoryProvider = Provider<IceBoxRepository>(
  (ref) => useFakeBackend ? FakeIceBoxRepository(ref.watch(dealerStoreProvider)) : ApiIceBoxRepository(ref.watch(apiProvider)),
);

final iceBoxAccountProvider = FutureProvider<IceBoxAccount>((ref) => ref.watch(iceBoxRepositoryProvider).account());

class IceBoxesScreen extends ConsumerWidget {
  const IceBoxesScreen({super.key});

  Future<void> _requestPickup(BuildContext context, IceBoxAccount account) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PickupSheet(maxBoxes: account.boxesHeld - account.boxesInPickup),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ice boxes')),
      body: AsyncBody(
        value: ref.watch(iceBoxAccountProvider),
        builder: (account) => ListView(
          padding: AppSpacing.page,
          children: [
            GradientHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Boxes with you'),
                  Text('${account.boxesHeld}', style: Theme.of(context).textTheme.displaySmall),
                  Text('Refundable deposit: ${money(account.boxesHeld * AppConstants.iceBoxDeposit)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: account.boxesHeld - account.boxesInPickup > 0 ? () => _requestPickup(context, account) : null,
              child: const Text('Request box pickup'),
            ),
            if (account.pickups.isNotEmpty) ...[
              const SectionTitle('Pickups requested'),
              for (final pickup in account.pickups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(child: Text('${pickup.quantity} boxes on ${formatDateShort(pickup.date)}')),
                        TextButton(
                          onPressed: () async {
                            await ref.read(iceBoxRepositoryProvider).cancelPickup(pickup.id);
                            ref.invalidate(iceBoxAccountProvider);
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SectionTitle('History'),
            if (account.movements.isEmpty) const Text('Boxes you order and return will be listed here.'),
            for (final m in account.movements)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(
                        m.type == BoxMovementType.issued ? Icons.south_west : Icons.north_east,
                        color: m.type == BoxMovementType.issued ? AppColors.sky600 : AppColors.green600,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${m.quantity} boxes ${m.type == BoxMovementType.issued ? 'received' : 'returned'}\n'
                          '${formatDate(m.date)} · ${m.reference}',
                        ),
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

class _PickupSheet extends ConsumerStatefulWidget {
  const _PickupSheet({required this.maxBoxes});

  final int maxBoxes;

  @override
  ConsumerState<_PickupSheet> createState() => _PickupSheetState();
}

class _PickupSheetState extends ConsumerState<_PickupSheet> {
  int _quantity = 1;
  DateTime _date = dateOnly(DateTime.now()).add(const Duration(days: 1));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    try {
      await ref.read(iceBoxRepositoryProvider).requestPickup(_quantity, _date);
      ref.invalidate(iceBoxAccountProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request box pickup', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Number of boxes')),
                QuantityStepper(
                  value: _quantity,
                  max: widget.maxBoxes,
                  onChanged: (v) => setState(() => _quantity = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pickup date'),
              subtitle: Text(formatDateShort(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _submit, child: const Text('Submit request')),
          ],
        ),
      ),
    );
  }
}
