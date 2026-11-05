import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_payment_repository.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../data/fake_payment_repository.dart';
import '../domain/ledger.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final dealer = ref.watch(authControllerProvider).value;
  if (!useFakeBackend) return ApiPaymentRepository(ref.watch(apiProvider));
  return FakePaymentRepository(
    ref.watch(dealerStoreProvider),
    ref.watch(notificationRepositoryProvider),
    creditLimit: dealer?.creditLimit ?? 0,
    creditDays: dealer?.creditDays ?? 0,
  );
});

final creditSummaryProvider = FutureProvider<CreditSummary>(
  (ref) => ref.watch(paymentRepositoryProvider).creditSummary(),
);

final ledgerProvider = FutureProvider<List<LedgerEntry>>((ref) => ref.watch(paymentRepositoryProvider).ledger());
