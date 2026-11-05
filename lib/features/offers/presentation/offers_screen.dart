import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_offer_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/fake_offer_repository.dart';
import '../domain/offer.dart';

final offerRepositoryProvider = Provider<OfferRepository>(
  (ref) => !useFakeBackend ? ApiOfferRepository(ref.watch(apiProvider)) : FakeOfferRepository(tier: ref.watch(authControllerProvider.select((a) => a.value?.tier)) ?? 'Standard'),
);

final offersProvider = FutureProvider<List<Offer>>((ref) => ref.watch(offerRepositoryProvider).offers());

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key, this.initial = OfferKind.current});

  final OfferKind initial;

  static const _tabs = [
    ('Current offers', OfferKind.current),
    ('Dealer schemes', OfferKind.scheme),
    ('Special discounts', OfferKind.specialDiscount),
  ];

  Widget _list(List<Offer> offers) {
    if (offers.isEmpty) return const EmptyState(icon: Icons.local_offer_outlined, title: 'Nothing here right now');
    return ListView.separated(
      padding: AppSpacing.page,
      itemCount: offers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final offer = offers[i];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(offer.description),
              Text('Valid till ${formatDate(offer.validTill)}', style: Theme.of(context).textTheme.bodySmall),
              if (offer.code.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusChip(offer.code, color: AppColors.green600),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy code'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: offer.code));
                        showMessage(context, '${offer.code} copied. Apply it in your cart.');
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: _tabs.indexWhere((t) => t.$2 == initial),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offers and schemes'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.sky700,
            indicatorColor: AppColors.sky700,
            tabs: [for (final (label, _) in _tabs) Tab(text: label)],
          ),
        ),
        body: AsyncBody(
          value: ref.watch(offersProvider),
          builder: (offers) => TabBarView(
            children: [for (final (_, kind) in _tabs) _list(offers.where((o) => o.kind == kind).toList())],
          ),
        ),
      ),
    );
  }
}
