import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';

import '../../../core/storage/local_store.dart';
import '../data/fake_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/dealer.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => useFakeBackend ? FakeAuthRepository(ref.watch(localStoreProvider)) : ApiAuthRepository(ref.watch(apiProvider)));

class AuthController extends AsyncNotifier<Dealer?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<Dealer?> build() => _repo.currentDealer();

  Future<void> verifyOtp(String phone, String otp) async => state = AsyncData(await _repo.verifyOtp(phone, otp));

  Future<void> signInWithPassword(String phone, String password) async =>
      state = AsyncData(await _repo.signInWithPassword(phone, password));

  Future<void> submitKyc(Dealer dealer) async => state = AsyncData(await _repo.submitKyc(dealer));

  Future<void> refreshKycStatus() async => state = AsyncData(await _repo.refreshKycStatus());

  Future<void> updateProfile(Dealer dealer) async => state = AsyncData(await _repo.updateProfile(dealer));

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Dealer?>(AuthController.new);

/// The signed-in dealer, for screens that are only reachable after sign in.
/// Blank for the moment between signing out and the router moving away.
final currentDealerProvider = Provider<Dealer>(
  (ref) => ref.watch(authControllerProvider).value ?? const Dealer(id: '', phone: ''),
);

final dealerIdProvider = Provider<String?>((ref) => ref.watch(authControllerProvider.select((a) => a.value?.id)));

/// Storage for the signed-in dealer. Every repository built on this one is
/// recreated when the dealer changes, which clears their cached data too.
final dealerStoreProvider = Provider<LocalStore>((ref) {
  final id = ref.watch(dealerIdProvider);
  return ref.watch(localStoreProvider).scoped(id ?? 'signed_out');
});
