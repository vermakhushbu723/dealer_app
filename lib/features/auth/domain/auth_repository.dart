import 'dealer.dart';

abstract interface class AuthRepository {
  /// The signed-in dealer, or null when signed out.
  Future<Dealer?> currentDealer();

  Future<void> sendOtp(String phone);

  /// Signs in, creating an account the first time a number is seen.
  Future<Dealer> verifyOtp(String phone, String otp);

  Future<Dealer> signInWithPassword(String phone, String password);

  /// Whether the signed-in dealer has set a password yet.
  Future<bool> hasPassword();

  /// [current] is ignored when no password has been set yet.
  Future<void> changePassword({required String current, required String next});

  Future<Dealer> submitKyc(Dealer dealer);

  /// Re-reads the account, to pick up a KYC decision made by the admin team.
  Future<Dealer> refreshKycStatus();

  Future<Dealer> updateProfile(Dealer dealer);

  Future<void> logout();

  Future<void> deleteAccount();
}
