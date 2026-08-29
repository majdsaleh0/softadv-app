import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../application/message_controller.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: inboxAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) return const Center(child: Text('No messages yet.'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inboxProvider),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return ListTile(
                  title: Text(conversation.otherPartyName, style: TextStyle(fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(conversation.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: conversation.unreadCount > 0
                      ? CircleAvatar(radius: 11, child: Text('${conversation.unreadCount}', style: const TextStyle(fontSize: 11)))
                      : null,
                  onTap: () => context.push(AppRoute.messageThread, extra: conversation.ref).then((_) => ref.invalidate(inboxProvider)),
                );
              },
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load messages: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
