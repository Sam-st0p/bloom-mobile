import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class ActivityService {
  static Future<void> log({
    required String activityType,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('activity_logs').insert({
        'user_id': userId,
        'action_type': activityType,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'metadata': metadata,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
