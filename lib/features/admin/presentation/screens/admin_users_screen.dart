import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/profile.dart';
import '../../application/admin_controller.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) return const Center(child: Text('No users.'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allProfilesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _AdminUserTile(profile: profiles[index]),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load users: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AdminUserTile extends ConsumerWidget {
  const _AdminUserTile({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuspended = profile.status == AccountStatus.suspended;

    return Card(
      child: ListTile(
        title: Text(profile.name),
        subtitle: Text('${profile.email} · ${profile.role.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(profile.status.name)),
            IconButton(
              icon: Icon(isSuspended ? Icons.restore : Icons.block),
              tooltip: isSuspended ? 'Reinstate' : 'Suspend',
              onPressed: profile.role == UserRole.admin
                  ? null
                  : () async {
                      await ref.read(profileRepositoryProvider).setProfileStatus(profile.id, isSuspended ? AccountStatus.active : AccountStatus.suspended);
                      ref.invalidate(allProfilesProvider);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
