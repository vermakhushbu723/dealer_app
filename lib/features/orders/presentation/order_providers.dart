import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_order_repository.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../ice_boxes/presentation/ice_boxes_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../payments/presentation/payment_providers.dart';
import '../data/fake_order_repository.dart';
import '../domain/order.dart';

export '../../payments/presentation/payment_providers.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  if (!useFakeBackend) return ApiOrderRepository(ref.watch(apiProvider));
  return FakeOrderRepository(
    ref.watch(dealerStoreProvider),
    ref.watch(paymentRepositoryProvider),
    ref.watch(notificationRepositoryProvider),
    ref.watch(iceBoxRepositoryProvider),
  );
});

final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final orders = await ref.watch(orderRepositoryProvider).orders();
  // Reading orders can move them forward, which also changes these.
  ref.invalidate(notificationsProvider);
  ref.invalidate(iceBoxAccountProvider);
  return orders;
});

final orderProvider = FutureProvider.family<Order?, String>((ref, id) async {
  final orders = await ref.watch(ordersProvider.future);
  return orders.where((o) => o.id == id).firstOrNull;
});

/// Call after anything that changes an order or the dealer's balance.
void refreshOrdersAndBalance(WidgetRef ref) {
  ref.invalidate(ordersProvider);
  ref.invalidate(creditSummaryProvider);
  ref.invalidate(ledgerProvider);
}
