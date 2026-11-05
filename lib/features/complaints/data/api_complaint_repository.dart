import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../domain/complaint.dart';

class ApiComplaintRepository implements ComplaintRepository {
  ApiComplaintRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Complaint>> complaints() async => (await _api.get('/dealer/complaints') as Object).mapped(Complaint.fromJson);

  @override
  Future<Complaint> submit({
    required String orderId,
    required String orderNumber,
    required ComplaintType type,
    required int affectedQuantity,
    required String description,
    required List<PickedPhoto> photos,
    required GeoPoint location,
  }) async {
    final uploaded = [
      for (final p in photos) {'path': await _api.upload(p.path), 'takenAt': p.takenAt.toIso8601String()},
    ];
    final body = await _api.post('/dealer/complaints', {
      'orderId': orderId,
      'type': type.name,
      'affectedQuantity': affectedQuantity,
      'description': description,
      'photos': uploaded,
      'location': location.toJson(),
    });
    return Complaint.fromJson(body as Map<String, dynamic>);
  }
}
