import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../../addresses/domain/address.dart';
import '../../cart/domain/cart_pricing.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../notifications/domain/notification.dart';
import '../../orders/domain/order.dart';
import '../domain/standing_order.dart';

class FakeStandingOrderRepository implements StandingOrderRepository {
  FakeStandingOrderRepository(this._store, this._catalog, this._orders, this._addresses, this._notifications);

  final LocalStore _store;
  final CatalogRepository _catalog;
  final OrderRepository _orders;
  final AddressRepository _addresses;
  final NotificationRepository _notifications;

  static const _key = 'standing_orders';

  List<StandingOrder> _read() => (_store.readList(_key) ?? const []).map(StandingOrder.fromJson).toList();

  Future<void> _write(List<StandingOrder> items) => _store.writeList(_key, items.map((o) => o.toJson()).toList());

  @override
  Future<List<StandingOrder>> standingOrders() async {
    await fakeLatency();
    return _read();
  }

  @override
  Future<void> save(StandingOrder order) async {
    final items = _read();
    final index = items.indexWhere((o) => o.id == order.id);
    index >= 0 ? items[index] = order : items.add(order);
    await _write(items);
  }

  @override
  Future<void> delete(String id) => _write(_read()..removeWhere((o) => o.id == id));

  /// Runs when the app opens. In production a scheduled job on the server does
  /// this, so orders go out even if the dealer doesn't open the app.
  @override
  Future<int> placeDueOrders() async {
    final now = DateTime.now();
    var placed = 0;
    final updated = <StandingOrder>[];
    for (final standing in _read()) {
      if (!standing.isDueOn(now)) {
        updated.add(standing);
        continue;
      }
      try {
        await _place(standing, now);
        placed++;
      } catch (e) {
        await _notifications.add(NotificationType.order, 'Could not place "${standing.name}"', '$e');
      }
      updated.add(standing.copyWith(lastRun: dateOnly(now)));
    }
    await _write(updated);
    return placed;
  }

  Future<void> _place(StandingOrder standing, DateTime now) async {
    final products = await _catalog.products();
    final lines = [
      for (final p in products)
        if (standing.items.containsKey(p.id) && p.inStock) CartLine(p, standing.items[p.id]!),
    ];
    final addresses = await _addresses.addresses();
    final address = addresses.where((a) => a.id == standing.addressId).firstOrNull ?? addresses.first;
    await _orders.place(
      PlaceOrderRequest(
        bill: CartBill.calculate(lines),
        address: address,
        deliveryDate: dateOnly(now),
        slot: standing.slot,
        paymentMethod: standing.paymentMethod,
        notes: 'Standing order: ${standing.name}',
        standingOrderId: standing.id,
      ),
    );
  }
}
