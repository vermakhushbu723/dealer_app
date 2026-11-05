import '../../../core/network/api_client.dart';
import '../domain/notification.dart';

/// The server writes notifications itself, as things happen.
class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AppNotification>> notifications() async =>
      (await _api.get('/dealer/notifications') as Object).mapped(AppNotification.fromJson);

  @override
  Future<void> add(NotificationType type, String title, String body, {String? route}) async {}

  @override
  Future<void> markRead(String id) => _api.post('/dealer/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.post('/dealer/notifications/read-all');

  @override
  Future<void> clearAll() => _api.delete('/dealer/notifications');

  @override
  Future<Set<NotificationType>> mutedTypes() async =>
      ((await _api.get('/dealer/notifications/muted')) as List).map((t) => NotificationType.values.byName(t as String)).toSet();

  @override
  Future<void> setMuted(NotificationType type, bool muted) async {
    final types = await mutedTypes();
    muted ? types.add(type) : types.remove(type);
    await _api.put('/dealer/notifications/muted', {'types': types.map((t) => t.name).toList()});
  }
}
