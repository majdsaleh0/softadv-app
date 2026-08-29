import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../notifications/application/notification_controller.dart';
import '../../application/profile_controller.dart';
import '../../domain/profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            icon: Badge(label: Text('$unreadCount'), isLabelVisible: unreadCount > 0, child: const Icon(Icons.notifications_outlined)),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppRoute.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Not signed in.'));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    Text(profile.email, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Center(child: Chip(label: Text(profile.role.name))),
                    if (profile.businessName != null && profile.businessName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Business: ${profile.businessName}', textAlign: TextAlign.center),
                    ],
                    if (profile.status == AccountStatus.pending) ...[
                      const SizedBox(height: 16),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Your provider account is pending admin approval.'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.push(AppRoute.editProfile),
                      child: const Text('Edit profile'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoute.browse),
                      child: const Text('Browse Listings'),
                    ),
                    if (profile.role == UserRole.provider) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(AppRoute.myListings),
                        child: const Text('My Listings'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(AppRoute.incomingBookings),
                        child: const Text('Incoming Bookings'),
                      ),
                    ],
                    if (profile.role == UserRole.customer) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(AppRoute.myBookings),
                        child: const Text('My Bookings'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoute.messages),
                      child: const Text('Messages'),
                    ),
                    if (profile.role == UserRole.admin) ...[
                      const SizedBox(height: 24),
                      Text('Admin', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(AppRoute.adminListings),
                        child: const Text('Manage Listings'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(AppRoute.adminUsers),
                        child: const Text('Manage Users'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.push(AppRoute.adminReports),
                        child: const Text('Reports'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load profile: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
