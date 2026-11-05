import '../../../core/network/api_client.dart';
import '../domain/ice_box.dart';

class ApiIceBoxRepository implements IceBoxRepository {
  ApiIceBoxRepository(this._api);

  final ApiClient _api;

  @override
  Future<IceBoxAccount> account() async {
    final j = await _api.get('/dealer/ice-boxes') as Map<String, dynamic>;
    return IceBoxAccount(movements: (j['movements'] as Object).mapped(BoxMovement.fromJson), pickups: (j['pickups'] as Object).mapped(PickupRequest.fromJson));
  }

  @override
  Future<void> recordIssued(int quantity, String reference) async {}

  @override
  Future<void> requestPickup(int quantity, DateTime date) => _api.post('/dealer/ice-boxes/pickups', {'quantity': quantity, 'date': date.toIso8601String()});

  @override
  Future<void> cancelPickup(String id) => _api.delete('/dealer/ice-boxes/pickups/$id');
}
