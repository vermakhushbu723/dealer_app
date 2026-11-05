import 'package:geolocator/geolocator.dart';

import '../error/app_exception.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude, {this.accuracyMetres});

  final double latitude;
  final double longitude;
  final double? accuracyMetres;

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude, 'accuracyMetres': accuracyMetres};

  factory GeoPoint.fromJson(Map<String, dynamic> j) => GeoPoint(
    (j['latitude'] as num).toDouble(),
    (j['longitude'] as num).toDouble(),
    accuracyMetres: (j['accuracyMetres'] as num?)?.toDouble(),
  );
}

abstract final class LocationService {
  /// The device's current position. Throws [AppException] with a message the
  /// dealer can act on when location is off or the permission is refused.
  static Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException('Please turn on location (GPS) and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const AppException('Location permission is needed. Please allow it in your phone settings and try again.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
    return GeoPoint(position.latitude, position.longitude, accuracyMetres: position.accuracy);
  }
}
