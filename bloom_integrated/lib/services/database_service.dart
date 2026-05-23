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

  /// Register the current user for a seminar.
  /// Snapshots profile data at time of registration.
  /// Enforces registration deadline: cannot register after seminar starts.
  /// Returns null on success, or an error string.
  static Future<String?> registerForSeminar(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not logged in.';

      // 1. Fetch seminar to enforce deadline
      final seminar = await _supabase
          .from('seminars')
          .select('scheduled_start, status')
          .eq('id', seminarId)
          .maybeSingle();

      if (seminar == null) return 'Seminar not found.';

      // Block registration if seminar has already started or ended
      final dbStatus = seminar['status'] as String? ?? 'upcoming';
      if (dbStatus == 'cancelled') return 'registration_closed';
      if (dbStatus == 'completed') return 'registration_closed';

      final startIso = seminar['scheduled_start'] as String?;
      if (startIso != null) {
        try {
          final utcStart = startIso.endsWith('Z') || startIso.contains('+')
              ? startIso
              : '${startIso}Z';
          final startTime = DateTime.parse(utcStart);
          if (DateTime.now().isAfter(startTime)) {
            return 'registration_closed';
          }
        } catch (_) {}
      }

      // 2. Fetch current profile snapshot
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email, role, department, course, year_level')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return 'Profile not found.';

      // 3. Check if already registered (active)
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
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'already_registered';
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Cancel the current user's registration for a seminar.
  static Future<String?> cancelRegistration(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not logged in.';
      await _supabase
          .from('seminar_registrations')
          .update({'status': 'cancelled'})
          .eq('user_id', userId)
          .eq('seminar_id', seminarId);
      return null;
    } catch (e) {
      return e.toString();
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

  /// Submit a seminar evaluation.
  /// Enforces: user must have been registered before seminar started.
  /// Returns null on success, 'already_evaluated' if duplicate,
  /// 'not_eligible' if user was not pre-registered, or error string.
  static Future<String?> submitEvaluation({
    required String seminarId,
    required Map<String, int> scores,
    String? comments,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not logged in.';

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

          // Must have been registered (not cancelled) and registered before start
          final regAtIso = reg['registered_at'] as String?;
          if (regAtIso != null) {
            final utcRegAt = regAtIso.endsWith('Z') || regAtIso.contains('+')
                ? regAtIso
                : '${regAtIso}Z';
            final regAt = DateTime.parse(utcRegAt);
            if (regAt.isAfter(startTime)) return 'not_eligible';
          }
        } catch (_) {}
      }

      // 2. Server-side duplicate check before insert
      final existing = await _supabase
          .from('seminar_evaluations')
          .select('id')
          .eq('user_id', userId)
          .eq('seminar_id', seminarId)
          .maybeSingle();

      if (existing != null) return 'already_evaluated';

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
        'comments':       (comments?.trim().isEmpty ?? true) ? null : comments?.trim(),
        'submitted_at':   DateTime.now().toUtc().toIso8601String(),
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