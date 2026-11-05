enum NotificationType { order, payment, delivery, announcement }

extension NotificationTypeLabel on NotificationType {
  String get label => switch (this) {
    NotificationType.order => 'Order updates',
    NotificationType.payment => 'Payment reminders',
    NotificationType.delivery => 'Delivery alerts',
    NotificationType.announcement => 'Company announcements',
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.route,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Screen to open when the notification is tapped.
  final String? route;

  AppNotification markRead() =>
      AppNotification(id: id, type: type, title: title, body: body, createdAt: createdAt, isRead: true, route: route);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'route': route,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    type: NotificationType.values.byName(j['type'] as String),
    title: j['title'] as String,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    isRead: j['isRead'] as bool,
    route: j['route'] as String?,
  );
}

abstract interface class NotificationRepository {
  Future<List<AppNotification>> notifications();

  /// Types the dealer has switched off are dropped.
  Future<void> add(NotificationType type, String title, String body, {String? route});

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<void> clearAll();

  Future<Set<NotificationType>> mutedTypes();

  Future<void> setMuted(NotificationType type, bool muted);
}
