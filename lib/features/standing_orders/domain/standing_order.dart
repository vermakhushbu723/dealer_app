import '../../../core/utils/formatters.dart';
import '../../orders/domain/order.dart';

/// An order that repeats automatically on chosen weekdays.
class StandingOrder {
  const StandingOrder({
    required this.id,
    required this.name,
    required this.items,
    required this.weekdays,
    required this.slot,
    required this.addressId,
    required this.paymentMethod,
    required this.lastRun,
    this.isActive = true,
    this.skippedDates = const {},
  });

  final String id;
  final String name;

  /// Product id to quantity.
  final Map<String, int> items;

  /// 1 is Monday and 7 is Sunday, matching [DateTime.weekday].
  final Set<int> weekdays;
  final String slot;
  final String addressId;
  final PaymentMethod paymentMethod;
  final bool isActive;
  final Set<DateTime> skippedDates;

  /// The day an order was last created. Starts as the day this was set up, so
  /// creating it on a scheduled weekday doesn't place an order immediately.
  final DateTime lastRun;

  bool isDueOn(DateTime day) {
    final date = dateOnly(day);
    return isActive &&
        weekdays.contains(date.weekday) &&
        !skippedDates.contains(date) &&
        date.isAfter(dateOnly(lastRun));
  }

  /// The next day an order will be created, or null when paused.
  DateTime? nextRun(DateTime from) {
    if (!isActive || weekdays.isEmpty) return null;
    for (var i = 0; i <= 366; i++) {
      final day = dateOnly(from).add(Duration(days: i));
      if (isDueOn(day)) return day;
    }
    return null;
  }

  StandingOrder copyWith({bool? isActive, Set<DateTime>? skippedDates, DateTime? lastRun}) => StandingOrder(
    id: id,
    name: name,
    items: items,
    weekdays: weekdays,
    slot: slot,
    addressId: addressId,
    paymentMethod: paymentMethod,
    lastRun: lastRun ?? this.lastRun,
    isActive: isActive ?? this.isActive,
    skippedDates: skippedDates ?? this.skippedDates,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items,
    'weekdays': weekdays.toList(),
    'slot': slot,
    'addressId': addressId,
    'paymentMethod': paymentMethod.name,
    'lastRun': lastRun.toIso8601String(),
    'isActive': isActive,
    'skippedDates': skippedDates.map((d) => d.toIso8601String()).toList(),
  };

  factory StandingOrder.fromJson(Map<String, dynamic> j) => StandingOrder(
    id: j['id'] as String,
    name: j['name'] as String,
    items: (j['items'] as Map).cast<String, int>(),
    weekdays: (j['weekdays'] as List).cast<int>().toSet(),
    slot: j['slot'] as String,
    addressId: j['addressId'] as String,
    paymentMethod: PaymentMethod.values.byName(j['paymentMethod'] as String),
    lastRun: DateTime.parse(j['lastRun'] as String),
    isActive: j['isActive'] as bool,
    skippedDates: (j['skippedDates'] as List).map((d) => DateTime.parse(d as String)).toSet(),
  );
}

abstract interface class StandingOrderRepository {
  Future<List<StandingOrder>> standingOrders();

  Future<void> save(StandingOrder order);

  Future<void> delete(String id);

  /// Creates today's orders and returns how many were placed.
  Future<int> placeDueOrders();
}
