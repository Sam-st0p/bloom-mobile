// lib/services/database_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class DatabaseService {

  // ── MODULES ────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchModules() async {
    try {
      final data = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchStudentProgress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('module_progress')
          .select('*')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  static Future<void> upsertProgress(String moduleId, int progressPct) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('module_progress').upsert({
        'user_id':          userId,
        'module_id':        moduleId,
        'progress_percent': progressPct,
        'status':           progressPct == 100 ? 'completed' : 'in_progress',
        'last_accessed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,module_id');
    } catch (_) {}
  }

  // ── SEMINARS ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchSeminars() async {
    try {
      final data = await _supabase
          .from('seminars')
          .select('*')
          .eq('is_public', true);
      final list = List<Map<String, dynamic>>.from(data);
      list.sort((a, b) {
        final aDate = a['scheduled_start'] ?? a['start_date'] ?? '';
        final bDate = b['scheduled_start'] ?? b['start_date'] ?? '';
        return bDate.compareTo(aDate);
      });
      return list;
    } catch (_) {}
    return [];
  }

  // ── REGISTRATION ───────────────────────────────────────────────────────────

  /// Atomically registers the current user for a seminar via the
  /// [register_for_seminar] RPC, which enforces capacity limits with a
  /// row-level lock and prevents race conditions.
  ///
  /// Returns:
  ///   null                  → success
  ///   'already_registered'  → user already has an active registration
  ///   'seminar_full'        → max_participants reached
  ///   'registration_closed' → seminar has started, ended, or was cancelled
  ///   'seminar_not_found'   → invalid seminar ID
  ///   'unauthenticated'     → no active session
  ///   'error'               → unexpected server error
  static Future<String?> registerForSeminar(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'unauthenticated';

      final result = await _supabase.rpc(
        'register_for_seminar',
        params: {'p_seminar_id': seminarId},
      );

      final code = result?.toString() ?? 'error';
      if (code == 'ok') {
        await _patchRegistrationSnapshot(userId, seminarId);
        return null;
      }

      const knownCodes = {
        'already_registered',
        'seminar_full',
        'registration_closed',
        'seminar_not_found',
        'unauthenticated',
      };
      return knownCodes.contains(code) ? code : 'error';

    } on PostgrestException catch (e) {
      return e.message.contains('seminar_full') ? 'seminar_full' : 'error';
    } catch (_) {
      return 'error';
    }
  }

  /// Soft-cancels the current user's registration (sets status → 'cancelled').
  /// Preserves the profile snapshot and audit trail.
  ///
  /// Returns null on success, or an error string.
  static Future<String?> cancelRegistration(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'unauthenticated';
      await _supabase
          .from('seminar_registrations')
          .update({'status': 'cancelled'})
          .eq('user_id', userId)
          .eq('seminar_id', seminarId);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'error';
    }
  }

  /// Returns true if the current user has an active registration for [seminarId].
  static Future<bool> isRegistered(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final result = await _supabase
          .from('seminar_registrations')
          .select('id')
          .eq('user_id', userId)
          .eq('seminar_id', seminarId)
          .eq('status', 'registered')
          .maybeSingle();
      return result != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns the set of seminar IDs the current user is actively registered for.
  /// Always reads from the DB — never trusts local or cached state.
  static Future<Set<String>> fetchMyRegisteredSeminarIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};
      final data = await _supabase
          .from('seminar_registrations')
          .select('seminar_id')
          .eq('user_id', userId)
          .eq('status', 'registered');
      return Set<String>.from(
          (data as List).map((r) => r['seminar_id'] as String));
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyRegistrations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('seminar_registrations')
          .select('*, seminars(*)')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  // ── EVALUATIONS ────────────────────────────────────────────────────────────

  /// Submits a seminar evaluation via the [submit_seminar_evaluation] RPC,
  /// which enforces registration eligibility and duplicate prevention server-side.
  ///
  /// Returns:
  ///   null                → success
  ///   'already_evaluated' → duplicate submission
  ///   'not_eligible'      → user was not a registered participant
  ///   'invalid_scores'    → one or more scores outside 1–5
  ///   'unauthenticated'   → no active session
  ///   'error'             → unexpected server error
  static Future<String?> submitEvaluation({
    required String seminarId,
    required Map<String, int> scores,
    String? comments,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'unauthenticated';

      final result = await _supabase.rpc(
        'submit_seminar_evaluation',
        params: {
          'p_seminar_id':     seminarId,
          'p_q_content':      scores['q_content']      ?? 0,
          'p_q_speaker':      scores['q_speaker']      ?? 0,
          'p_q_organization': scores['q_organization'] ?? 0,
          'p_q_relevance':    scores['q_relevance']    ?? 0,
          'p_q_materials':    scores['q_materials']    ?? 0,
          'p_q_overall':      scores['q_overall']      ?? 0,
          'p_comments':       comments?.trim() ?? '',
        },
      );

      final code = result?.toString() ?? 'error';
      if (code == 'ok') return null;

      const knownCodes = {
        'already_evaluated',
        'not_eligible',
        'invalid_scores',
        'unauthenticated',
      };
      return knownCodes.contains(code) ? code : 'error';

    } on PostgrestException catch (e) {
      return e.code == '23505' ? 'already_evaluated' : e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns true if the current user has already evaluated [seminarId].
  static Future<bool> hasEvaluated(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final result = await _supabase
          .from('seminar_evaluations')
          .select('id')
          .eq('user_id', userId)
          .eq('seminar_id', seminarId)
          .maybeSingle();
      return result != null;
    } catch (_) {
      return false;
    }
  }

  // ── EVENTS ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final data = await _supabase.from('events').select('*');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  // ── BADGES ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchBadges() async {
    try {
      final data = await _supabase.from('badges').select('*');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  static Future<List<String>> fetchMyBadgeIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('student_badges')
          .select('badge_id')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(data)
          .map((r) => r['badge_id'].toString())
          .toList();
    } catch (_) {}
    return [];
  }

  // ── CERTIFICATES ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchMyCertificates() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('certificates')
          .select('*')
          .eq('user_id', userId)
          .eq('is_revoked', false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  // ── ANNOUNCEMENTS ──────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final data = await _supabase
          .from('announcements')
          .select('*')
          .lte('published_at', DateTime.now().toUtc().toIso8601String())
          .order('is_pinned', ascending: false)
          .order('published_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  // ── PROFILE ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final data = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (_) {}
    return null;
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (_) {}
  }

  // ── PRIVATE HELPERS ────────────────────────────────────────────────────────

  /// Updates the profile snapshot on the registration row created by the RPC.
  /// Non-critical: registration has already succeeded before this is called.
  static Future<void> _patchRegistrationSnapshot(
      String userId, String seminarId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email, role, department, course, year_level')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return;
      await _supabase
          .from('seminar_registrations')
          .update({
            'full_name':  profile['full_name'],
            'email':      profile['email'],
            'role':       profile['role'],
            'department': profile['department'],
            'course':     profile['course'],
            'year_level': profile['year_level'],
          })
          .eq('user_id', userId)
          .eq('seminar_id', seminarId);
    } catch (_) {}
  }
}