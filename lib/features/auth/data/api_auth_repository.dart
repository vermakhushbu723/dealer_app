import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import '../domain/dealer.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  Future<Dealer> _signedIn(dynamic body) async {
    final data = body as Map<String, dynamic>;
    await _api.saveToken(data['token'] as String);
    return Dealer.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<Dealer?> currentDealer() async {
    if (!_api.hasToken) return null;
    try {
      return Dealer.fromJson(await _api.get('/dealer/me') as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      rethrow;
    }
  }

  @override
  Future<void> sendOtp(String phone) => _api.post('/auth/dealer/otp/send', {'phone': phone});

  @override
  Future<Dealer> verifyOtp(String phone, String otp) async => _signedIn(await _api.post('/auth/dealer/otp/verify', {'phone': phone, 'otp': otp}));

  @override
  Future<Dealer> signInWithPassword(String phone, String password) async => _signedIn(await _api.post('/auth/dealer/login', {'phone': phone, 'password': password}));

  @override
  Future<bool> hasPassword() async => (await _api.get('/dealer/me/has-password') as Map<String, dynamic>)['hasPassword'] as bool;

  @override
  Future<void> changePassword({required String current, required String next}) async {
    final body = await _api.post('/dealer/me/password', {'current': current, 'next': next}) as Map<String, dynamic>;
    await _api.saveToken(body['token'] as String);
  }

  @override
  Future<Dealer> submitKyc(Dealer dealer) async {
    final documents = <String, String>{};
    for (final entry in dealer.documents.entries) {
      documents[entry.key] = await _api.upload(entry.value);
    }
    final body = await _api.post('/dealer/kyc', {...dealer.toJson(), 'documents': documents});
    return Dealer.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<Dealer> refreshKycStatus() async => Dealer.fromJson(await _api.get('/dealer/me') as Map<String, dynamic>);

  @override
  Future<Dealer> updateProfile(Dealer dealer) async => Dealer.fromJson(await _api.put('/dealer/me', dealer.toJson()) as Map<String, dynamic>);

  @override
  Future<void> logout() => _api.clearToken();

  @override
  Future<void> deleteAccount() async {
    await _api.delete('/dealer/me');
    await _api.clearToken();
  }
}
