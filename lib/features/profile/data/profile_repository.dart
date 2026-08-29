import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromMap(row);
  }

  Future<Profile> updateProfile({
    required String userId,
    String? name,
    String? businessName,
  }) async {
    final updates = <String, dynamic>{
      'name': ?name,
      'business_name': ?businessName,
    };
    final row = await _client.from('profiles').update(updates).eq('id', userId).select().single();
    return Profile.fromMap(row);
  }

  /// FR-42: admin view of every user - relies on the profiles_select_admin RLS policy from G1.
  Future<List<Profile>> fetchAllProfiles() async {
    final rows = await _client.from('profiles').select().order('created_at', ascending: false);
    return (rows as List).map((row) => Profile.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// FR-43: ban/suspend (or reinstate) a user.
  Future<void> setProfileStatus(String userId, AccountStatus status) async {
    await _client.from('profiles').update({'status': status.name}).eq('id', userId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
