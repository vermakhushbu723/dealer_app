import '../../../core/location/location_service.dart';
import '../../cart/domain/delivery_slots.dart';
import '../../orders/data/fake_order_repository.dart';
import '../../orders/domain/order.dart';
import '../domain/delivery_tracking.dart';

/// Moves the rider in a straight line from the plant to the dealer. The Driver
/// App will send the real position, and addresses will need saved coordinates.
class FakeTrackingRepository implements TrackingRepository {
  static const _plant = GeoPoint(19.1136, 72.8697); // Andheri, Mumbai
  static const _destination = GeoPoint(19.0760, 72.8777);

  @override
  Future<DeliveryTracking> track(Order order) async {
    final now = DateTime.now();
    final startedAt = order.timeOf(OrderStatus.outForDelivery);
    if (startedAt == null) {
      return DeliveryTracking(
        origin: _plant,
        destination: _destination,
        eta: slotStart(order.deliveryDate, order.slot),
      );
    }
    final progress = (now.difference(startedAt).inMilliseconds / FakeOrderRepository.riderTripDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    return DeliveryTracking(
      origin: _plant,
      destination: _destination,
      rider: GeoPoint(
        _plant.latitude + (_destination.latitude - _plant.latitude) * progress,
        _plant.longitude + (_destination.longitude - _plant.longitude) * progress,
      ),
      eta: startedAt.add(FakeOrderRepository.riderTripDuration),
      updatedAt: now,
    );
  }
}
