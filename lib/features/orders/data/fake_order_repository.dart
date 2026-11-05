import 'dart:math';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../../addresses/domain/address.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../../ice_boxes/domain/ice_box.dart';
import '../../notifications/domain/notification.dart';
import '../../payments/domain/ledger.dart';
import '../domain/order.dart';

/// Keeps orders on the device and stands in for the operations team, moving
/// each active order forward over time. The credit check,
/// ledger postings and notifications below belong on the server in production.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository(this._store, this._payments, this._notifications, this._iceBoxes);

  final LocalStore _store;
  final PaymentRepository _payments;
  final NotificationRepository _notifications;
  final IceBoxRepository _iceBoxes;

  static const _key = 'orders';
  static const _stepDuration = Duration(seconds: 40);

  /// How long the simulated rider takes to reach the dealer.
  static const riderTripDuration = Duration(minutes: 3);
  static const _demoDriver = DeliveryDriver(name: 'Delivery Partner', phone: '+917009090977', vehicle: 'MH 02 AB 1234');

  List<Order> _read() {
    final stored = _store.readList(_key);
    if (stored != null) return stored.map(Order.fromJson).toList();
    return _store.scope == demoDealerId ? _sampleOrders() : [];
  }

  Future<void> _write(List<Order> items) => _store.writeList(_key, items.map((o) => o.toJson()).toList());

  @override
  Future<List<Order>> orders() async {
    await fakeLatency();
    final items = await _advanceActiveOrders(_read());
    return items..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  }

  Future<List<Order>> _advanceActiveOrders(List<Order> items) async {
    final now = DateTime.now();
    final result = <Order>[];
    for (var order in items) {
      while (order.isActive && now.difference(order.events.last.at) >= _durationOf(order.status)) {
        order = await _nextStatus(order, order.events.last.at.add(_durationOf(order.status)));
      }
      result.add(order);
    }
    await _write(result);
    return result;
  }

  Duration _durationOf(OrderStatus status) => status == OrderStatus.outForDelivery ? riderTripDuration : _stepDuration;

  Future<Order> _nextStatus(Order order, DateTime at) async {
    final next = OrderStatus.values[order.status.index + 1];
    final route = '/orders/${order.id}';
    final isDeliveryAlert = next == OrderStatus.outForDelivery || next == OrderStatus.delivered;
    await _notifications.add(
      isDeliveryAlert ? NotificationType.delivery : NotificationType.order,
      '${order.number}: ${next.label}',
      _statusMessage(next, order),
      route: route,
    );
    if (next == OrderStatus.delivered) {
      final boxes = order.lines.where((l) => l.isReturnable).fold(0, (sum, l) => sum + l.quantity);
      if (boxes > 0) await _iceBoxes.recordIssued(boxes, order.number);
    }
    return order.copyWith(
      events: [...order.events, OrderEvent(next, at)],
      driver: next == OrderStatus.outForDelivery ? _demoDriver : null,
      paymentStatus: next == OrderStatus.delivered && order.paymentMethod == PaymentMethod.cashOnDelivery
          ? PaymentStatus.paid
          : null,
    );
  }

  String _statusMessage(OrderStatus status, Order order) => switch (status) {
    OrderStatus.accepted => 'We have accepted your order for ${formatDateShort(order.deliveryDate)}.',
    OrderStatus.processing => 'Your order is being prepared.',
    OrderStatus.readyForDispatch => 'Your order is packed and ready for dispatch.',
    OrderStatus.outForDelivery => 'Your order is on the way. Share OTP ${order.deliveryOtp} with the driver.',
    OrderStatus.delivered => 'Your order has been delivered. Thank you!',
    _ => '',
  };

  @override
  Future<Order> place(PlaceOrderRequest request) async {
    await fakeLatency();
    final bill = request.bill;
    if (request.paymentMethod == PaymentMethod.credit) {
      final credit = await _payments.creditSummary();
      if (bill.total > credit.available) {
        throw AppException('This order is above your available credit of ${money(credit.available)}.');
      }
    }
    final now = DateTime.now();
    final items = _read();
    final order = Order(
      id: 'o-${now.microsecondsSinceEpoch}',
      number: _newOrderNumber(now),
      lines: bill.lines.map(OrderLine.fromCartLine).toList(),
      subtotal: bill.subtotal,
      discount: bill.discount,
      gst: bill.gst,
      deliveryFee: bill.deliveryFee,
      total: bill.total,
      address: request.address,
      deliveryDate: request.deliveryDate,
      slot: request.slot,
      paymentMethod: request.paymentMethod,
      paymentStatus: switch (request.paymentMethod) {
        PaymentMethod.credit => PaymentStatus.onCredit,
        PaymentMethod.online => PaymentStatus.paid,
        PaymentMethod.cashOnDelivery => PaymentStatus.pending,
      },
      events: [OrderEvent(OrderStatus.placed, now)],
      deliveryOtp: (1000 + Random().nextInt(9000)).toString(),
      couponCode: bill.couponCode,
      notes: request.notes,
      standingOrderId: request.standingOrderId,
    );
    await _write([...items, order]);
    if (request.paymentMethod == PaymentMethod.credit) {
      await _payments.postInvoice(order.invoiceNumber, order.total);
    }
    await _notifications.add(
      NotificationType.order,
      'Order placed',
      '${order.number} for ${money(order.total)} has been placed.',
      route: '/orders/${order.id}',
    );
    return order;
  }

  /// Date, then the dealer's number and a time-based code, so numbers can't
  /// repeat across dealers. In production the server assigns these.
  String _newOrderNumber(DateTime now) {
    final date = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final dealer = _store.scope.substring(_store.scope.length - 4);
    return 'ICE-$date-$dealer-${now.microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }

  @override
  Future<void> cancel(String orderId, String reason) async {
    await fakeLatency();
    final items = await _advanceActiveOrders(_read());
    final index = items.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const AppException('Order not found');
    final order = items[index];
    if (!order.canCancel) {
      throw AppException('This order is ${order.status.label.toLowerCase()} and can no longer be cancelled.');
    }
    items[index] = order.copyWith(
      events: [...order.events, OrderEvent(OrderStatus.cancelled, DateTime.now())],
      cancelReason: reason,
      paymentStatus: order.paymentMethod == PaymentMethod.online ? PaymentStatus.refunded : null,
    );
    await _write(items);
    if (order.paymentMethod == PaymentMethod.credit) {
      await _payments.postCreditNote(order.invoiceNumber, order.total);
    }
    await _notifications.add(
      NotificationType.order,
      'Order cancelled',
      '${order.number} has been cancelled.',
      route: '/orders/${order.id}',
    );
  }

  @override
  Future<void> rate(String orderId, int stars, String review) async {
    final items = _read();
    final index = items.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const AppException('Order not found');
    items[index] = items[index].copyWith(rating: stars, review: review);
    await _write(items);
  }

  List<Order> _sampleOrders() {
    const address = Address(
      id: 'business',
      label: 'Business address',
      contactName: 'Demo Dealer',
      phone: demoPhone,
      line: 'Unit 12, Sample Industrial Estate, Andheri East',
      city: 'Mumbai',
      pincode: '400069',
      isDefault: true,
    );
    const cube = OrderLine(
      productId: 'cube-20',
      name: 'Cube Ice',
      packSize: '20 kg bag',
      image: 'assets/images/CubeIce.png',
      unit: 'bag',
      quantity: 12,
      unitPrice: 295,
      gstPercent: 18,
      hsnCode: '22019010',
    );
    const crushed = OrderLine(
      productId: 'crushed-25',
      name: 'Crushed Ice',
      packSize: '25 kg bag',
      image: 'assets/images/CrushedBlockIce.png',
      unit: 'bag',
      quantity: 10,
      unitPrice: 200,
      gstPercent: 18,
      hsnCode: '22019010',
    );
    const block = OrderLine(
      productId: 'block-50',
      name: 'Block Ice',
      packSize: '50 kg block',
      image: 'assets/images/CrushedBlockIce.png',
      unit: 'block',
      quantity: 10,
      unitPrice: 320,
      gstPercent: 18,
      hsnCode: '22019010',
    );

    Order sample(int daysAgo, int serial, List<OrderLine> lines) {
      final placed = DateTime.now().subtract(Duration(days: daysAgo));
      final subtotal = lines.fold<double>(0, (sum, l) => sum + l.amount);
      final gst = roundMoney(subtotal * 0.18);
      return Order(
        id: 'sample-$serial',
        number: 'ICE-${placed.year}-${100 + serial}',
        lines: lines,
        subtotal: subtotal,
        discount: 0,
        gst: gst,
        deliveryFee: 0,
        total: subtotal + gst,
        address: address,
        deliveryDate: placed.add(const Duration(days: 1)),
        slot: '9 AM - 12 PM',
        paymentMethod: PaymentMethod.credit,
        paymentStatus: PaymentStatus.onCredit,
        events: [
          OrderEvent(OrderStatus.placed, placed),
          OrderEvent(OrderStatus.delivered, placed.add(const Duration(days: 1))),
        ],
        deliveryOtp: '4821',
        driver: _demoDriver,
      );
    }

    return [
      sample(5, 6, const [cube, crushed]),
      sample(24, 5, const [block]),
      sample(52, 4, const [cube, block]),
      sample(83, 3, const [crushed]),
      sample(115, 2, const [cube]),
      sample(146, 1, const [cube, crushed, block]),
    ];
  }
}
