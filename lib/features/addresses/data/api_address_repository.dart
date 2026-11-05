import '../../../core/network/api_client.dart';
import '../domain/address.dart';

class ApiAddressRepository implements AddressRepository {
  ApiAddressRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Address>> addresses() async => (await _api.get('/dealer/addresses') as Object).mapped(Address.fromJson);

  @override
  Future<void> save(Address address) => _api.post('/dealer/addresses', address.toJson());

  @override
  Future<void> delete(String id) => _api.delete('/dealer/addresses/$id');

  @override
  Future<void> setDefault(String id) => _api.post('/dealer/addresses/$id/default');
}
