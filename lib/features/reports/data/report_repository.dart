import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/report.dart';

class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  /// FR-44: any user can report a listing or a review.
  Future<void> submitReport({required ReportTargetType targetType, required String targetId, required String reason}) async {
    final user = _client.auth.currentUser!;
    await _client.from('reports').insert({'reporter_id': user.id, 'target_type': targetType.dbValue, 'target_id': targetId, 'reason': reason});
  }

  Future<List<Report>> fetchOpenReports() async {
    final rows = await _client.from('reports').select('*, reporter:profiles!reports_reporter_id_fkey(name)').eq('status', 'open').order('created_at', ascending: false);
    return (rows as List).map((r) => Report.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// FR-45. The actual moderation action (remove content / ban user) is a separate
  /// call to ListingRepository/ReviewRepository/ProfileRepository - this just closes
  /// the report out with a note on what was done.
  Future<void> resolveReport({required String reportId, required String resolution}) async {
    await _client.from('reports').update({'status': 'resolved', 'resolution': resolution}).eq('id', reportId);
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(supabaseClientProvider));
});
