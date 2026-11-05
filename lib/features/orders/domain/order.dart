import '../../addresses/domain/address.dart';
import '../../cart/domain/cart_pricing.dart';

enum OrderStatus { placed, accepted, processing, readyForDispatch, outForDelivery, delivered, cancelled, failed }

enum PaymentMethod { credit, online, cashOnDelivery }

enum PaymentStatus { pending, paid, onCredit, refunded }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.placed => 'New',
    OrderStatus.accepted => 'Accepted',
    OrderStatus.processing => 'Processing',
    OrderStatus.readyForDispatch => 'Ready for dispatch',
    OrderStatus.outForDelivery => 'Out for delivery',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
    OrderStatus.failed => 'Delivery failed',
  };
}

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.credit => 'Credit account',
    PaymentMethod.online => 'Pay online',
    PaymentMethod.cashOnDelivery => 'Cash on delivery',
  };
}

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.pending => 'Payment due on delivery',
    PaymentStatus.paid => 'Paid',
    PaymentStatus.onCredit => 'On credit',
    PaymentStatus.refunded => 'Refunded',
  };
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.packSize,
    required this.image,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.gstPercent,
    this.isReturnable = false,
    this.hsnCode = '',
  });

  final String productId;
  final String name;
  final String packSize;
  final String image;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double gstPercent;
  final bool isReturnable;
  final String hsnCode;

  double get amount => unitPrice * quantity;

  factory OrderLine.fromCartLine(CartLine l) => OrderLine(
    productId: l.product.id,
    name: l.product.name,
    packSize: l.product.packSize,
    image: l.product.image,
    unit: l.product.unit,
    quantity: l.quantity,
    unitPrice: l.unitPrice,
    gstPercent: l.product.gstPercent,
    isReturnable: l.product.isReturnable,
    hsnCode: l.product.hsnCode,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'packSize': packSize,
    'image': image,
    'unit': unit,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'gstPercent': gstPercent,
    'isReturnable': isReturnable,
    'hsnCode': hsnCode,
  };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    productId: j['productId'] as String,
    name: j['name'] as String,
    packSize: j['packSize'] as String,
    image: j['image'] as String,
    unit: j['unit'] as String,
    quantity: j['quantity'] as int,
    unitPrice: (j['unitPrice'] as num).toDouble(),
    gstPercent: (j['gstPercent'] as num).toDouble(),
    isReturnable: j['isReturnable'] as bool,
    hsnCode: j['hsnCode'] as String,
  );
}

class OrderEvent {
  const OrderEvent(this.status, this.at);

  final OrderStatus status;
  final DateTime at;

  Map<String, dynamic> toJson() => {'status': status.name, 'at': at.toIso8601String()};

  factory OrderEvent.fromJson(Map<String, dynamic> j) =>
      OrderEvent(OrderStatus.values.byName(j['status'] as String), DateTime.parse(j['at'] as String));
}

class DeliveryDriver {
  const DeliveryDriver({required this.name, required this.phone, required this.vehicle});

  final String name;
  final String phone;
  final String vehicle;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'vehicle': vehicle};

  factory DeliveryDriver.fromJson(Map<String, dynamic> j) =>
      DeliveryDriver(name: j['name'] as String, phone: j['phone'] as String, vehicle: j['vehicle'] as String);
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.gst,
    required this.deliveryFee,
    required this.total,
    required this.address,
    required this.deliveryDate,
    required this.slot,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.events,
    required this.deliveryOtp,
    this.couponCode,
    this.notes = '',
    this.driver,
    this.cancelReason,
    this.rating,
    this.review,
    this.standingOrderId,
  });

  final String id;
  final String number;
  final List<OrderLine> lines;
  final double subtotal;
  final double discount;
  final double gst;
  final double deliveryFee;
  final double total;
  final Address address;
  final DateTime deliveryDate;
  final String slot;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final List<OrderEvent> events;

  /// The dealer gives this code to the driver to confirm delivery.
  final String deliveryOtp;
  final String? couponCode;
  final String notes;
  final DeliveryDriver? driver;
  final String? cancelReason;
  final int? rating;
  final String? review;
  final String? standingOrderId;

  OrderStatus get status => events.last.status;
  DateTime get placedAt => events.first.at;
  String get invoiceNumber => number.replaceFirst('ICE', 'INV');
  bool get isActive => status != OrderStatus.delivered && status != OrderStatus.cancelled;
  bool get canCancel => status == OrderStatus.placed || status == OrderStatus.accepted;
  DateTime? timeOf(OrderStatus s) => events.where((e) => e.status == s).firstOrNull?.at;
  bool get isDelivered => status == OrderStatus.delivered;
  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  Order copyWith({
    PaymentStatus? paymentStatus,
    List<OrderEvent>? events,
    DeliveryDriver? driver,
    String? cancelReason,
    int? rating,
    String? review,
  }) => Order(
    id: id,
    number: number,
    lines: lines,
    subtotal: subtotal,
    discount: discount,
    gst: gst,
    deliveryFee: deliveryFee,
    total: total,
    address: address,
    deliveryDate: deliveryDate,
    slot: slot,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    events: events ?? this.events,
    deliveryOtp: deliveryOtp,
    couponCode: couponCode,
    notes: notes,
    driver: driver ?? this.driver,
    cancelReason: cancelReason ?? this.cancelReason,
    rating: rating ?? this.rating,
    review: review ?? this.review,
    standingOrderId: standingOrderId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'lines': lines.map((l) => l.toJson()).toList(),
    'subtotal': subtotal,
    'discount': discount,
    'gst': gst,
    'deliveryFee': deliveryFee,
    'total': total,
    'address': address.toJson(),
    'deliveryDate': deliveryDate.toIso8601String(),
    'slot': slot,
    'paymentMethod': paymentMethod.name,
    'paymentStatus': paymentStatus.name,
    'events': events.map((e) => e.toJson()).toList(),
    'deliveryOtp': deliveryOtp,
    'couponCode': couponCode,
    'notes': notes,
    'driver': driver?.toJson(),
    'cancelReason': cancelReason,
    'rating': rating,
    'review': review,
    'standingOrderId': standingOrderId,
  };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as String,
    number: j['number'] as String,
    lines: (j['lines'] as List).map((l) => OrderLine.fromJson(l as Map<String, dynamic>)).toList(),
    subtotal: (j['subtotal'] as num).toDouble(),
    discount: (j['discount'] as num).toDouble(),
    gst: (j['gst'] as num).toDouble(),
    deliveryFee: (j['deliveryFee'] as num).toDouble(),
    total: (j['total'] as num).toDouble(),
    address: Address.fromJson(j['address'] as Map<String, dynamic>),
    deliveryDate: DateTime.parse(j['deliveryDate'] as String),
    slot: j['slot'] as String,
    paymentMethod: PaymentMethod.values.byName(j['paymentMethod'] as String),
    paymentStatus: PaymentStatus.values.byName(j['paymentStatus'] as String),
    events: (j['events'] as List).map((e) => OrderEvent.fromJson(e as Map<String, dynamic>)).toList(),
    deliveryOtp: j['deliveryOtp'] as String,
    couponCode: j['couponCode'] as String?,
    notes: j['notes'] as String,
    driver: j['driver'] == null ? null : DeliveryDriver.fromJson(j['driver'] as Map<String, dynamic>),
    cancelReason: j['cancelReason'] as String?,
    rating: j['rating'] as int?,
    review: j['review'] as String?,
    standingOrderId: j['standingOrderId'] as String?,
  );
}

class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.bill,
    required this.address,
    required this.deliveryDate,
    required this.slot,
    required this.paymentMethod,
    this.notes = '',
    this.standingOrderId,
  });

  final CartBill bill;
  final Address address;
  final DateTime deliveryDate;
  final String slot;
  final PaymentMethod paymentMethod;
  final String notes;
  final String? standingOrderId;
}

abstract interface class OrderRepository {
  Future<List<Order>> orders();

  Future<Order> place(PlaceOrderRequest request);

  /// Only allowed before the order goes into processing. Refunds what was charged.
  Future<void> cancel(String orderId, String reason);

  Future<void> rate(String orderId, int stars, String review);
}
