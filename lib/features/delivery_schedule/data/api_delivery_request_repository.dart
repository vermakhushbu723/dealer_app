import '../../../core/network/api_client.dart';
import '../domain/delivery_request.dart';

class ApiDeliveryRequestRepository implements DeliveryRequestRepository {
  ApiDeliveryRequestRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<DeliveryRequest>> requests() async => (await _api.get('/dealer/delivery-requests') as Object).mapped(DeliveryRequest.fromJson);

  @override
  Future<void> add(DeliveryRequest request) => _api.post('/dealer/delivery-requests', request.toJson());

  @override
  Future<void> cancel(String id) => _api.delete('/dealer/delivery-requests/$id');
}
