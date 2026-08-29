import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../application/notification_controller.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              await ref.read(notificationRepositoryProvider).markAllRead(user.id);
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) return const Center(child: Text('No notifications yet.'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _NotificationTile(notification: notifications[index]),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load notifications: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        notification.isRead ? Icons.notifications_none : Icons.notifications_active,
        color: notification.isRead ? null : Theme.of(context).colorScheme.primary,
      ),
      title: Text(notification.content, style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)),
      subtitle: Text(_relativeTime(notification.createdAt)),
      onTap: notification.isRead
          ? null
          : () async {
              await ref.read(notificationRepositoryProvider).markRead(notification.id);
              ref.invalidate(notificationsProvider);
            },
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
