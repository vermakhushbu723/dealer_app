import '../../../core/network/api_client.dart';
import '../domain/standing_order.dart';

/// The server places these every day, even if the dealer doesn't open the app.
class ApiStandingOrderRepository implements StandingOrderRepository {
  ApiStandingOrderRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<StandingOrder>> standingOrders() async => (await _api.get('/dealer/standing-orders') as Object).mapped(StandingOrder.fromJson);

  @override
  Future<void> save(StandingOrder order) => _api.post('/dealer/standing-orders', order.toJson());

  @override
  Future<void> delete(String id) => _api.delete('/dealer/standing-orders/$id');

  @override
  Future<int> placeDueOrders() async => (await _api.post('/dealer/standing-orders/run-due') as Map<String, dynamic>)['placed'] as int;
}
