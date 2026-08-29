import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final rows = await _client.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
    return (rows as List).map((r) => AppNotification.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead(String userId) async {
    await _client.from('notifications').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});
