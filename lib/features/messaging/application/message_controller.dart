import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/message_repository.dart';
import '../domain/message.dart';

final inboxProvider = FutureProvider<List<Conversation>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(messageRepositoryProvider).fetchInbox(user.id);
});

final threadProvider = FutureProvider.family<List<Message>, ConversationRef>((ref, conversation) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(messageRepositoryProvider).fetchThread(listingId: conversation.listingId, bookingId: conversation.bookingId, otherPartyId: conversation.otherPartyId, myUserId: user.id);
});
