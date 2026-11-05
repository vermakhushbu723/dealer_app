import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../domain/auth_repository.dart';
import '../domain/dealer.dart';

/// Number of the pre-approved account that comes with sample history.
const demoPhone = '9876543210';
const demoDealerId = 'D-$demoPhone';

/// Every number signs in with this code until a real SMS provider is connected.
const demoOtp = '123456';

/// Password of the demo account.
const demoPassword = 'Demo@1234';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._store);

  final LocalStore _store;

  static const _sessionKey = 'session_phone';

  String _accountKey(String phone) => 'account_$phone';

  String _passwordKey(String phone) => 'password_$phone';

  // Only stops the password sitting in plain text on the device. In production
  // the server stores and checks passwords.
  String _hash(String phone, String password) => sha256.convert(utf8.encode('$phone:$password')).toString();

  bool _passwordMatches(String phone, String password) {
    if (phone == demoPhone && _store.readMap(_passwordKey(phone)) == null) return password == demoPassword;
    return _store.readMap(_passwordKey(phone))?['hash'] == _hash(phone, password);
  }

  void _save(Dealer dealer) => _store.writeMap(_accountKey(dealer.phone), dealer.toJson());

  @override
  Future<Dealer?> currentDealer() async {
    final session = _store.readMap(_sessionKey);
    if (session == null) return null;
    return _load(session['phone'] as String);
  }

  Dealer? _load(String phone) {
    final json = _store.readMap(_accountKey(phone));
    return json == null ? null : Dealer.fromJson(json);
  }

  Future<Dealer> _requireCurrent() async {
    final dealer = await currentDealer();
    if (dealer == null) throw const AppException('Please sign in again');
    return dealer;
  }

  @override
  Future<void> sendOtp(String phone) => fakeLatency();

  @override
  Future<Dealer> verifyOtp(String phone, String otp) async {
    await fakeLatency();
    if (otp != demoOtp) throw const AppException('Incorrect OTP. Please try again.');
    final dealer = _load(phone) ?? (phone == demoPhone ? _demoDealer() : Dealer(id: 'D-$phone', phone: phone));
    _save(dealer);
    await _startSession(phone);
    return dealer;
  }

  Future<void> _startSession(String phone) => _store.writeMap(_sessionKey, {'phone': phone});

  @override
  Future<Dealer> signInWithPassword(String phone, String password) async {
    await fakeLatency();
    final dealer = _load(phone) ?? (phone == demoPhone ? _demoDealer() : null);
    if (dealer == null || !_passwordMatches(phone, password)) {
      throw const AppException('Incorrect mobile number or password. New here, or forgot it? Sign in with OTP.');
    }
    _save(dealer);
    await _startSession(phone);
    return dealer;
  }

  @override
  Future<bool> hasPassword() async {
    final dealer = await _requireCurrent();
    return dealer.phone == demoPhone || _store.readMap(_passwordKey(dealer.phone)) != null;
  }

  @override
  Future<void> changePassword({required String current, required String next}) async {
    await fakeLatency();
    final dealer = await _requireCurrent();
    if (await hasPassword() && !_passwordMatches(dealer.phone, current)) {
      throw const AppException('Your current password is incorrect.');
    }
    await _store.writeMap(_passwordKey(dealer.phone), {'hash': _hash(dealer.phone, next)});
  }

  @override
  Future<Dealer> submitKyc(Dealer dealer) async {
    await fakeLatency();
    final updated = dealer.copyWith(kycStatus: KycStatus.pending, rejectionReason: '', joinedOn: DateTime.now());
    _save(updated);
    return updated;
  }

  @override
  Future<Dealer> refreshKycStatus() async {
    await fakeLatency();
    var dealer = await _requireCurrent();
    // There is no admin panel yet, so a status check approves the application.
    if (dealer.kycStatus == KycStatus.pending) {
      dealer = dealer.copyWith(kycStatus: KycStatus.approved, creditLimit: 50000, creditDays: 15);
      _save(dealer);
    }
    return dealer;
  }

  @override
  Future<Dealer> updateProfile(Dealer dealer) async {
    await fakeLatency();
    _save(dealer);
    return dealer;
  }

  @override
  Future<void> logout() => _store.remove(_sessionKey);

  @override
  Future<void> deleteAccount() async {
    final dealer = await _requireCurrent();
    await _store.scoped(dealer.id).clearScope();
    await _store.remove(_accountKey(dealer.phone));
    await _store.remove(_passwordKey(dealer.phone));
    await logout();
  }

  Dealer _demoDealer() => Dealer(
    id: demoDealerId,
    phone: demoPhone,
    ownerName: 'Demo Dealer',
    businessName: 'Demo Cold Traders',
    businessType: 'Distributor',
    email: 'demo@example.com',
    gstin: '27AAAAA0000A1Z5',
    pan: 'AAAAA0000A',
    fssai: '11500000000000',
    addressLine: 'Unit 12, Sample Industrial Estate, Andheri East',
    city: 'Mumbai',
    pincode: '400069',
    kycStatus: KycStatus.approved,
    tier: 'Gold',
    creditLimit: 100000,
    creditDays: 15,
    joinedOn: DateTime(2026, 1, 15),
  );
}
