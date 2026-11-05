import '../../../core/location/location_service.dart';
import '../../orders/domain/order.dart';

class DeliveryTracking {
  const DeliveryTracking({
    required this.origin,
    required this.destination,
    required this.eta,
    this.rider,
    this.updatedAt,
  });

  final GeoPoint origin;
  final GeoPoint destination;

  /// Where the rider is now. Null until the order is out for delivery.
  final GeoPoint? rider;
  final DateTime eta;
  final DateTime? updatedAt;
}

abstract interface class TrackingRepository {
  Future<DeliveryTracking> track(Order order);
}
