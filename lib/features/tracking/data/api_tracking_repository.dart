import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../cart/domain/delivery_slots.dart';
import '../../orders/domain/order.dart';
import '../domain/delivery_tracking.dart';

class ApiTrackingRepository implements TrackingRepository {
  ApiTrackingRepository(this._api);

  final ApiClient _api;

  @override
  Future<DeliveryTracking> track(Order order) async {
    final j = await _api.get('/dealer/orders/${order.id}/tracking') as Map<String, dynamic>;
    GeoPoint? point(String key) => j[key] == null ? null : GeoPoint.fromJson(j[key] as Map<String, dynamic>);
    return DeliveryTracking(
      origin: point('origin')!,
      destination: point('destination')!,
      rider: point('rider'),
      eta: j['eta'] == null ? slotStart(order.deliveryDate, order.slot) : DateTime.parse(j['eta'] as String),
      updatedAt: j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
    );
  }
}
