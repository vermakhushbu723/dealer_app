import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../error/app_exception.dart';
import '../storage/local_store.dart';

/// Where the server is. On a phone over USB, run `adb reverse tcp:4000 tcp:4000` for the default.
/// A release build passes the real one: --dart-define=API_URL=https://api.example.com/api
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:4000/api');

/// Tests run without a server by passing --dart-define=USE_FAKE_BACKEND=true.
const useFakeBackend = bool.fromEnvironment('USE_FAKE_BACKEND');

/// The demo login hint. A build for real users passes --dart-define=SHOW_DEMO_HINT=false.
const showDemoHint = bool.fromEnvironment('SHOW_DEMO_HINT', defaultValue: true);

/// An error from the server, with what it says about the request.
class ApiException extends AppException {
  const ApiException(super.message, {required this.status, this.code, this.total});

  final int status;
  final String? code;
  final num? total;
}

final _utcTime = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$');

/// The server sends times in UTC. The apps show them and count days in the phone's own time.
dynamic _localTimes(dynamic value) => switch (value) {
  final String s when _utcTime.hasMatch(s) => DateTime.parse(s).toLocal().toIso8601String(),
  final List<dynamic> list => list.map(_localTimes).toList(),
  final Map<String, dynamic> map => map.map((k, v) => MapEntry(k, _localTimes(v))),
  _ => value,
};

class ApiClient {
  ApiClient(this._store, {http.Client? client}) : _client = client ?? http.Client();

  final LocalStore _store;
  final http.Client _client;

  static const _tokenKey = 'api_session';
  static const _timeout = Duration(seconds: 30);

  String? get token => _store.readMap(_tokenKey)?['token'] as String?;
  bool get hasToken => token != null;
  Future<void> saveToken(String token) => _store.writeMap(_tokenKey, {'token': token});
  Future<void> clearToken() => _store.remove(_tokenKey);

  Map<String, String> get _authHeader => {if (token != null) 'Authorization': 'Bearer $token'};

  /// A read is safe to try twice. A write is not: the first may have worked, and a second could place an order twice.
  Future<dynamic> _send(Future<http.Response> Function() request, {bool retry = false}) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on http.ClientException {
      if (retry) return _send(request);
      throw const AppException('Could not reach the server. Please check your internet.');
    } on TimeoutException {
      throw const AppException('The server is taking too long. Please try again.');
    }
    final body = response.body.isEmpty ? null : _localTimes(jsonDecode(utf8.decode(response.bodyBytes)));
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final error = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    if (response.statusCode == 401) await clearToken();
    throw ApiException(
      error['error'] as String? ?? 'Something went wrong. Please try again.',
      status: response.statusCode,
      code: error['code'] as String?,
      total: error['total'] as num?,
    );
  }

  Uri _uri(String path) => Uri.parse('$apiUrl$path');

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json', ..._authHeader};

  Future<dynamic> get(String path) => _send(() => _client.get(_uri(path), headers: _authHeader), retry: true);

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _client.post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body ?? const {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _client.put(_uri(path), headers: _jsonHeaders, body: jsonEncode(body ?? const {})));

  Future<dynamic> patch(String path, [Object? body]) =>
      _send(() => _client.patch(_uri(path), headers: _jsonHeaders, body: jsonEncode(body ?? const {})));

  Future<dynamic> delete(String path) => _send(() => _client.delete(_uri(path), headers: _authHeader));

  /// Sends a photo or document, and gives back where the server keeps it.
  /// Something already on the server is left as it is.
  Future<String> upload(String path) async {
    if (path.startsWith('http')) return path;
    final Uint8List bytes = await XFile(path).readAsBytes();
    final request = http.MultipartRequest('POST', _uri('/uploads'))
      ..headers.addAll(_authHeader)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'upload.jpg'));
    final body = await _send(() async => http.Response.fromStream(await _client.send(request)));
    return (body as Map<String, dynamic>)['url'] as String;
  }
}

final apiProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(localStoreProvider)));

extension JsonListX on dynamic {
  /// A JSON array as maps, read by one of the fromJson factories.
  List<T> mapped<T>(T Function(Map<String, dynamic>) read) =>
      (this as List).map((e) => read(e as Map<String, dynamic>)).toList();
}
