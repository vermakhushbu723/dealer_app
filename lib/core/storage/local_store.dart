import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;

/// JSON storage on the device. The fake repositories keep all their data here.
class LocalStore {
  LocalStore(this._prefs, {this.scope = ''});

  final SharedPreferences _prefs;

  /// Keys are prefixed with this, so each dealer's data stays separate.
  final String scope;

  LocalStore scoped(String scope) => LocalStore(_prefs, scope: scope);

  String _key(String key) => scope.isEmpty ? key : '$scope/$key';

  Json? readMap(String key) {
    final raw = _prefs.getString(_key(key));
    return raw == null ? null : jsonDecode(raw) as Json;
  }

  Future<void> writeMap(String key, Json value) => _prefs.setString(_key(key), jsonEncode(value));

  List<Json>? readList(String key) {
    final raw = _prefs.getString(_key(key));
    return raw == null ? null : (jsonDecode(raw) as List).cast<Json>();
  }

  Future<void> writeList(String key, List<Json> value) => _prefs.setString(_key(key), jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(_key(key));

  /// Removes every key in this store's scope.
  Future<void> clearScope() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith('$scope/')).toList()) {
      await _prefs.remove(key);
    }
  }
}

/// Overridden in main() once SharedPreferences has loaded.
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError());

/// Stands in for network time, so loading states show up during development.
Future<void> fakeLatency() => Future<void>.delayed(const Duration(milliseconds: 250));
