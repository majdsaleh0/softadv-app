class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.listingId,
    required this.bookingId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String? listingId;
  final String? bookingId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      listingId: map['listing_id'] as String?,
      bookingId: map['booking_id'] as String?,
      content: map['content'] as String,
      isRead: map['is_read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Identifies which conversation this message belongs to. Booking-scoped messages
  /// key on the booking alone (its two parties are fixed); listing-scoped ones must
  /// also key on the other party, since several different customers can each have
  /// their own inquiry thread about the same listing.
  String scopeKey(String myUserId) {
    if (bookingId != null) return 'booking:$bookingId';
    final otherPartyId = senderId == myUserId ? recipientId : senderId;
    return 'listing:$listingId:$otherPartyId';
  }
}

/// Identifies one conversation: who it's with, and whether it's scoped to a listing
/// inquiry or a specific booking. A record, so it has structural equality for free -
/// used both as go_router `extra` and as a Riverpod family key.
typedef ConversationRef = ({String otherPartyId, String otherPartyName, String? listingId, String? bookingId});

class Conversation {
  const Conversation({
    required this.scopeKey,
    required this.otherPartyId,
    required this.otherPartyName,
    required this.listingId,
    required this.bookingId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String scopeKey;
  final String otherPartyId;
  final String otherPartyName;
  final String? listingId;
  final String? bookingId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  ConversationRef get ref => (otherPartyId: otherPartyId, otherPartyName: otherPartyName, listingId: listingId, bookingId: bookingId);
}
