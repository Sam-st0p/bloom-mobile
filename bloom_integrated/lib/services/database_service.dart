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

  /// Register the current user for a seminar via atomic RPC.
  ///
  /// The RPC (register_for_seminar) is the source of truth and enforces:
  ///   • Capacity limit (max_participants) with a row-level lock
  ///   • Registration deadline (cannot register after seminar starts)
  ///   • Duplicate prevention
  ///
  /// This method falls back to a direct insert (with capacity check) if the
  /// RPC is unavailable, preserving the profile snapshot behaviour.
  ///
  /// Returns null on success, or one of these error codes:
  ///   'already_registered'  – user already has an active registration
  ///   'seminar_full'        – max_participants has been reached
  ///   'registration_closed' – seminar started / ended / cancelled
  ///   'seminar_not_found'   – bad seminar ID
  ///   'unauthenticated'     – no active session
  ///   'error'               – unexpected server error
  static Future<String?> registerForSeminar(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'unauthenticated';

      // ── 1. Try the atomic RPC first (handles capacity + race conditions) ──
      try {
        final rpcResult = await _supabase.rpc(
          'register_for_seminar',
          params: {'p_seminar_id': seminarId},
        );
        final code = rpcResult?.toString() ?? 'error';

        // RPC succeeded — now patch in the profile snapshot if it was a
        // fresh registration (the RPC inserts a bare row; we update it here).
        if (code == 'ok') {
          await _patchRegistrationSnapshot(userId, seminarId);
          return null;
        }

        // RPC returned a known error code — surface it directly.
        if (['already_registered', 'seminar_full', 'registration_closed',
             'seminar_not_found', 'unauthenticated'].contains(code)) {
          return code;
        }

        // Unknown code from RPC — fall through to legacy path
      } on PostgrestException catch (rpcErr) {
        // If the trigger fires and rejects a raw insert, surface seminar_full.
        if (rpcErr.message.contains('seminar_full')) return 'seminar_full';
        // Any other RPC error — fall through to legacy direct-insert path
      }

      // ── 2. Legacy direct-insert path (used if RPC not yet deployed) ───────
      return await _registerDirectly(userId, seminarId);

    } catch (e) {
      return 'error';
    }
  }

  /// Patches the profile snapshot onto the registration row that the RPC
  /// created. Called only after a successful RPC 'ok' response.
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
    } catch (_) {
      // Non-critical — registration already succeeded; snapshot is best-effort
    }
  }

  /// Legacy direct-insert registration with manual capacity enforcement.
  /// Used as fallback when the RPC has not yet been deployed to Supabase.
  static Future<String?> _registerDirectly(
      String userId, String seminarId) async {
    // 1. Fetch seminar to enforce deadline + capacity
    final seminar = await _supabase
        .from('seminars')
        .select('scheduled_start, status, max_participants')
        .eq('id', seminarId)
        .maybeSingle();

    if (seminar == null) return 'seminar_not_found';

    final dbStatus = seminar['status'] as String? ?? 'upcoming';
    if (dbStatus == 'cancelled' || dbStatus == 'completed') {
      return 'registration_closed';
    }

    final startIso = seminar['scheduled_start'] as String?;
    if (startIso != null) {
      try {
        final utcStart = startIso.endsWith('Z') || startIso.contains('+')
            ? startIso
            : '${startIso}Z';
        if (DateTime.now().isAfter(DateTime.parse(utcStart))) {
          return 'registration_closed';
        }
      } catch (_) {}
    }

    // 2. Capacity check (non-atomic — RPC is preferred for race safety)
    final maxP = seminar['max_participants'] as int?;
    if (maxP != null) {
      final countRes = await _supabase
          .from('seminar_registrations')
          .select('id')
          .eq('seminar_id', seminarId)
          .eq('status', 'registered')
          .count(CountOption.exact);
      if (countRes.count >= maxP) return 'seminar_full';
    }

    // 3. Fetch profile snapshot
    final profile = await _supabase
        .from('profiles')
        .select('full_name, email, role, department, course, year_level')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) return 'error';

    // 4. Check for existing row (re-activation path)
    final existing = await _supabase
        .from('seminar_registrations')
        .select('id, status')
        .eq('user_id', userId)
        .eq('seminar_id', seminarId)
        .maybeSingle();

    if (existing != null && existing['status'] == 'registered') {
      return 'already_registered';
    }

    final now = DateTime.now().toUtc().toIso8601String();

    if (existing != null) {
      // Re-activate a previously cancelled registration
      await _supabase
          .from('seminar_registrations')
          .update({
            'status':        'registered',
            'registered_at': now,
            'full_name':     profile['full_name'],
            'email':         profile['email'],
            'role':          profile['role'],
            'department':    profile['department'],
            'course':        profile['course'],
            'year_level':    profile['year_level'],
          })
          .eq('id', existing['id'] as String);
    } else {
      // Fresh registration with profile snapshot
      await _supabase.from('seminar_registrations').insert({
        'user_id':       userId,
        'seminar_id':    seminarId,
        'status':        'registered',
        'registered_at': now,
        'created_at':    now,
        'full_name':     profile['full_name'],
        'email':         profile['email'],
        'role':          profile['role'],
        'department':    profile['department'],
        'course':        profile['course'],
        'year_level':    profile['year_level'],
      });
    }

    return null; // success
  }

  /// Cancel the current user's registration for a seminar.
  /// Soft-delete: sets status to 'cancelled' rather than deleting the row,
  /// preserving the profile snapshot and audit trail.
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

  /// Returns true if the user is actively registered for a seminar.
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

  /// Returns the set of seminar IDs the user is actively registered for.
  /// Reads directly from DB — never trusts local/cached state.
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

  /// Verifies registration eligibility directly from DB via RPC.
  /// Used to gate the evaluation form before it is shown or submitted.
  /// Returns true only when a confirmed registration row exists in the DB.
  static Future<bool> checkEvaluationEligibility(String seminarId) async {
    try {
      // Try RPC first (deployed with the capacity fix SQL)
      final result = await _supabase.rpc(
        'check_evaluation_eligibility',
        params: {'p_seminar_id': seminarId},
      );
      return result == true;
    } on PostgrestException {
      // RPC not yet deployed — fall back to direct query
      return isRegistered(seminarId);
    } catch (_) {
      return false;
    }
  }

  /// Submit a seminar evaluation via secure RPC when available,
  /// falling back to the original direct-insert path with eligibility checks.
  ///
  /// Enforces:
  ///   • User must have been registered before seminar started
  ///   • No duplicate evaluations
  ///   • Score range 1–5
  ///
  /// Returns null on success, 'already_evaluated' if duplicate,
  /// 'not_eligible' if user was not pre-registered, or error string.
  static Future<String?> submitEvaluation({
    required String seminarId,
    required Map<String, int> scores,
    String? comments,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'unauthenticated';

      // ── Try the secure RPC first ──────────────────────────────────────────
      try {
        final rpcResult = await _supabase.rpc(
          'submit_seminar_evaluation',
          params: {
            'p_seminar_id':       seminarId,
            'p_q_content':        scores['q_content']      ?? 0,
            'p_q_speaker':        scores['q_speaker']      ?? 0,
            'p_q_organization':   scores['q_organization'] ?? 0,
            'p_q_relevance':      scores['q_relevance']    ?? 0,
            'p_q_materials':      scores['q_materials']    ?? 0,
            'p_q_overall':        scores['q_overall']      ?? 0,
            'p_comments': (comments?.trim().isEmpty ?? true)
                ? null
                : comments?.trim(),
          },
        );

        final code = rpcResult?.toString() ?? 'error';
        if (code == 'ok') return null;

        if (['already_evaluated', 'not_eligible',
             'invalid_scores', 'unauthenticated'].contains(code)) {
          return code;
        }

        // Unknown code — fall through to legacy path
      } on PostgrestException {
        // RPC not yet deployed — fall through
      }

      // ── Legacy direct-insert path ─────────────────────────────────────────

      // 1. Verify registration eligibility:
      //    user must have registered BEFORE seminar started
      final seminar = await _supabase
          .from('seminars')
          .select('scheduled_start')
          .eq('id', seminarId)
          .maybeSingle();

      final startIso = seminar?['scheduled_start'] as String?;
      if (startIso != null) {
        try {
          final utcStart = startIso.endsWith('Z') || startIso.contains('+')
              ? startIso
              : '${startIso}Z';
          final startTime = DateTime.parse(utcStart);

          final reg = await _supabase
              .from('seminar_registrations')
              .select('registered_at, status')
              .eq('user_id', userId)
              .eq('seminar_id', seminarId)
              .maybeSingle();

          if (reg == null) return 'not_eligible';

          final regAtIso = reg['registered_at'] as String?;
          if (regAtIso != null) {
            final utcRegAt = regAtIso.endsWith('Z') || regAtIso.contains('+')
                ? regAtIso
                : '${regAtIso}Z';
            final regAt = DateTime.parse(utcRegAt);
            if (regAt.isAfter(startTime)) return 'not_eligible';
          }
        } catch (_) {}
      } else {
        // No start time set — just check a registration row exists
        final reg = await _supabase
            .from('seminar_registrations')
            .select('id')
            .eq('user_id', userId)
            .eq('seminar_id', seminarId)
            .eq('status', 'registered')
            .maybeSingle();
        if (reg == null) return 'not_eligible';
      }

      // 2. Duplicate check
      final existing = await _supabase
          .from('seminar_evaluations')
          .select('id')
          .eq('user_id', userId)
          .eq('seminar_id', seminarId)
          .maybeSingle();

      if (existing != null) return 'already_evaluated';

      // 3. Insert
      await _supabase.from('seminar_evaluations').insert({
        'seminar_id':     seminarId,
        'user_id':        userId,
        'q_content':      scores['q_content'],
        'q_speaker':      scores['q_speaker'],
        'q_organization': scores['q_organization'],
        'q_relevance':    scores['q_relevance'],
        'q_materials':    scores['q_materials'],
        'q_overall':      scores['q_overall'],
        'rating':         scores['q_overall'],
        'comments': (comments?.trim().isEmpty ?? true)
            ? null
            : comments?.trim(),
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      });

      return null;

    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'already_evaluated';
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns true if the user has already evaluated a seminar.
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
}