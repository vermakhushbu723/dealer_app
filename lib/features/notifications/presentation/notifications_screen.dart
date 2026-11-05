import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/fake_notification_repository.dart';
import '../domain/notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => useFakeBackend ? FakeNotificationRepository(ref.watch(dealerStoreProvider)) : ApiNotificationRepository(ref.watch(apiProvider)),
);

final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).notifications(),
);

final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).value?.where((n) => !n.isRead).length ?? 0,
);

final mutedTypesProvider = FutureProvider<Set<NotificationType>>(
  (ref) => ref.watch(notificationRepositoryProvider).mutedTypes(),
);

const _typeIcons = {
  NotificationType.order: Icons.receipt_long_outlined,
  NotificationType.payment: Icons.payments_outlined,
  NotificationType.delivery: Icons.local_shipping_outlined,
  NotificationType.announcement: Icons.campaign_outlined,
};

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.notifications_none)),
      onPressed: () => context.push(Routes.notifications),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.initialFilter});

  final NotificationType? initialFilter;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late NotificationType? _filter = widget.initialFilter;

  Future<void> _run(Future<void> action) async {
    await action;
    ref.invalidate(notificationsProvider);
  }

  Widget _chip(String label, NotificationType? type) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(label), selected: _filter == type, onSelected: (_) => setState(() => _filter = type)),
  );

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(notificationRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'read':
                  _run(repo.markAllRead());
                case 'clear':
                  _run(repo.clearAll());
                default:
                  context.push(Routes.notificationSettings);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'read', child: Text('Mark all as read')),
              PopupMenuItem(value: 'clear', child: Text('Clear all')),
              PopupMenuItem(value: 'settings', child: Text('Notification settings')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 4),
              children: [_chip('All', null), for (final type in NotificationType.values) _chip(type.label, type)],
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: ref.watch(notificationsProvider),
              builder: (all) {
                final items = _filter == null ? all : all.where((n) => n.type == _filter).toList();
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No notifications',
                    message: 'Order, payment and delivery updates will show up here.',
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return ListTile(
                      tileColor: n.isRead ? Colors.white : AppColors.sky100,
                      leading: Icon(_typeIcons[n.type], color: AppColors.sky700),
                      title: Text(n.title, style: Theme.of(context).textTheme.titleSmall),
                      subtitle: Text('${n.body}\n${formatDateTime(n.createdAt)}'),
                      isThreeLine: true,
                      onTap: () async {
                        await _run(repo.markRead(n.id));
                        if (n.route != null && context.mounted) context.go(n.route!);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const _descriptions = {
    NotificationType.order: 'New, accepted and processing orders, and complaints',
    NotificationType.payment: 'Payments received and overdue reminders',
    NotificationType.delivery: 'When your order is on the way and delivered',
    NotificationType.announcement: 'News from ICECLUB',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: AsyncBody(
        value: ref.watch(mutedTypesProvider),
        builder: (muted) => ListView(
          children: [
            for (final e in _descriptions.entries)
              SwitchListTile(
                title: Text(e.key.label),
                subtitle: Text(e.value),
                value: !muted.contains(e.key),
                onChanged: (on) async {
                  await ref.read(notificationRepositoryProvider).setMuted(e.key, !on);
                  ref.invalidate(mutedTypesProvider);
                },
              ),
          ],
        ),
      ),
    );
  }
}
