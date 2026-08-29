import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/message.dart';

class MessageRepository {
  MessageRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithNames = '''
    *,
    sender:profiles!messages_sender_id_fkey(name),
    recipient:profiles!messages_recipient_id_fkey(name)
  ''';

  /// FR-34, sorted by most recent activity. Groups raw messages into conversations
  /// client-side - see Message.scopeKey for why grouping can't just use listing_id.
  Future<List<Conversation>> fetchInbox(String myUserId) async {
    final rows = await _client.from('messages').select(_selectWithNames).or('sender_id.eq.$myUserId,recipient_id.eq.$myUserId').order('created_at', ascending: false);

    final latestByKey = <String, Map<String, dynamic>>{};
    final unreadCountByKey = <String, int>{};

    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final message = Message.fromMap(map);
      final key = message.scopeKey(myUserId);
      latestByKey.putIfAbsent(key, () => map);
      if (!message.isRead && message.recipientId == myUserId) {
        unreadCountByKey[key] = (unreadCountByKey[key] ?? 0) + 1;
      }
    }

    final conversations = [
      for (final entry in latestByKey.entries)
        _conversationFromLatest(key: entry.key, map: entry.value, myUserId: myUserId, unreadCount: unreadCountByKey[entry.key] ?? 0),
    ];
    conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return conversations;
  }

  Conversation _conversationFromLatest({required String key, required Map<String, dynamic> map, required String myUserId, required int unreadCount}) {
    final message = Message.fromMap(map);
    final isSender = message.senderId == myUserId;
    final otherPartyMap = (isSender ? map['recipient'] : map['sender']) as Map<String, dynamic>?;
    return Conversation(
      scopeKey: key,
      otherPartyId: isSender ? message.recipientId : message.senderId,
      otherPartyName: otherPartyMap?['name'] as String? ?? '',
      listingId: message.listingId,
      bookingId: message.bookingId,
      lastMessage: message.content,
      lastMessageAt: message.createdAt,
      unreadCount: unreadCount,
    );
  }

  Future<List<Message>> fetchThread({required String? listingId, required String? bookingId, required String otherPartyId, required String myUserId}) async {
    var query = _client.from('messages').select();
    query = bookingId != null
        ? query.eq('booking_id', bookingId)
        : query.eq('listing_id', listingId!).or('and(sender_id.eq.$myUserId,recipient_id.eq.$otherPartyId),and(sender_id.eq.$otherPartyId,recipient_id.eq.$myUserId)');
    final rows = await query.order('created_at', ascending: true);
    return (rows as List).map((r) => Message.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// FR-33/35.
  Future<void> sendMessage({required String recipientId, required String content, String? listingId, String? bookingId}) async {
    final user = _client.auth.currentUser!;
    await _client.from('messages').insert({'sender_id': user.id, 'recipient_id': recipientId, 'listing_id': listingId, 'booking_id': bookingId, 'content': content});
  }

  Future<void> markThreadRead({required String? listingId, required String? bookingId, required String otherPartyId, required String myUserId}) async {
    var query = _client.from('messages').update({'is_read': true}).eq('recipient_id', myUserId).eq('is_read', false);
    query = bookingId != null ? query.eq('booking_id', bookingId) : query.eq('listing_id', listingId!).eq('sender_id', otherPartyId);
    await query;
  }
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(supabaseClientProvider));
});
