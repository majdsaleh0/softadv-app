import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Kept in sync with [authStateChangesProvider] so widgets that only need
/// "who is logged in" don't have to unwrap an AsyncValue.
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return Supabase.instance.client.auth.currentUser;
});
