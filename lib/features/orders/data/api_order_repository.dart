import '../../../core/network/api_client.dart';
import '../domain/order.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api);

  final ApiClient _api;

  /// The total the server last quoted, when it differed from the app's bill.
  double? _confirmedTotal;

  @override
  Future<List<Order>> orders() async => (await _api.get('/dealer/orders') as Object).mapped(Order.fromJson);

  /// The server works out the price. If a delivery-location price changes the total,
  /// it says so, and placing the order again is the dealer's confirmation.
  @override
  Future<Order> place(PlaceOrderRequest request) async {
    final bill = request.bill;
    try {
      final body = await _api.post('/dealer/orders', {
        'addressId': request.address.id,
        'items': [for (final l in bill.lines) {'productId': l.product.id, 'qty': l.quantity}],
        'paymentMethod': request.paymentMethod.name,
        'deliveryDate': request.deliveryDate.toIso8601String(),
        'slot': request.slot,
        'notes': request.notes,
        'standingOrderId': request.standingOrderId,
        'expectedTotal': _confirmedTotal ?? bill.total,
      });
      _confirmedTotal = null;
      return Order.fromJson(body as Map<String, dynamic>);
    } on ApiException catch (e) {
      _confirmedTotal = e.code == 'PRICE_CHANGED' ? e.total?.toDouble() : null;
      rethrow;
    }
  }

  @override
  Future<void> cancel(String orderId, String reason) => _api.post('/dealer/orders/$orderId/cancel', {'reason': reason});

  @override
  Future<void> rate(String orderId, int stars, String review) => _api.post('/dealer/orders/$orderId/rate', {'stars': stars, 'review': review});
}
