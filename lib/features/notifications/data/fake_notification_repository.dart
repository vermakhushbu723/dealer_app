import '../../../core/storage/local_store.dart';
import '../domain/notification.dart';

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository(this._store);

  final LocalStore _store;

  static const _key = 'notifications';
  static const _mutedKey = 'notifications_muted';

  List<AppNotification> _read() {
    final stored = _store.readList(_key);
    if (stored != null) return stored.map(AppNotification.fromJson).toList();
    return [
      AppNotification(
        id: 'welcome',
        type: NotificationType.announcement,
        title: 'Welcome to ICECLUB',
        body: 'Order ice, track deliveries and manage your account from here.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> _write(List<AppNotification> items) => _store.writeList(_key, items.map((n) => n.toJson()).toList());

  @override
  Future<List<AppNotification>> notifications() async {
    final items = _read()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> add(NotificationType type, String title, String body, {String? route}) async {
    if ((await mutedTypes()).contains(type)) return;
    final now = DateTime.now();
    await _write([
      ..._read(),
      AppNotification(
        id: 'n-${now.microsecondsSinceEpoch}',
        type: type,
        title: title,
        body: body,
        createdAt: now,
        route: route,
      ),
    ]);
  }

  @override
  Future<void> markRead(String id) => _write([for (final n in _read()) n.id == id ? n.markRead() : n]);

  @override
  Future<void> markAllRead() => _write([for (final n in _read()) n.markRead()]);

  @override
  Future<void> clearAll() => _write(const []);

  @override
  Future<Set<NotificationType>> mutedTypes() async => ((_store.readMap(_mutedKey)?['types'] as List?) ?? const [])
      .map((t) => NotificationType.values.byName(t as String))
      .toSet();

  @override
  Future<void> setMuted(NotificationType type, bool muted) async {
    final types = await mutedTypes();
    muted ? types.add(type) : types.remove(type);
    await _store.writeMap(_mutedKey, {'types': types.map((t) => t.name).toList()});
  }
}
