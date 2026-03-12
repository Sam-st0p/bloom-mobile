import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class DatabaseService {

  // ── MODULES ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchModules() async {
    try {
      final data = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {}
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
    } catch (e) {}
    return [];
  }

  static Future<void> upsertProgress(String moduleId, int progressPct) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('module_progress').upsert({
        'user_id': userId,
        'module_id': moduleId,
        'progress_percent': progressPct,
        'status': progressPct == 100 ? 'completed' : 'in_progress',
        'last_accessed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,module_id');
    } catch (e) {}
  }

  // ── SEMINARS ───────────────────────────────────────────────────────
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
    } catch (e) {}
    return [];
  }

  static Future<String?> registerForSeminar(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not logged in';
      await _supabase.from('seminar_registrations').insert({
        'user_id': userId,
        'seminar_id': seminarId,
        'status': 'registered',
        'registered_at': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
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
    } catch (e) {}
    return [];
  }

  // ── EVENTS ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final data = await _supabase
          .from('events')
          .select('*')
          ;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {}
    return [];
  }

  // ── BADGES ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchBadges() async {
    try {
      final data = await _supabase.from('badges').select('*');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {}
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
          .map((row) => row['badge_id'].toString())
          .toList();
    } catch (e) {}
    return [];
  }

  // ── CERTIFICATES ───────────────────────────────────────────────────
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
    } catch (e) {}
    return [];
  }

  // ── ANNOUNCEMENTS ──────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final data = await _supabase
          .from('announcements')
          .select('*')
          .lte('published_at', DateTime.now().toIso8601String())
          .order('is_pinned', ascending: false)
          .order('published_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {}
    return [];
  }

  // ── PROFILE ────────────────────────────────────────────────────────
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
    } catch (e) {}
    return null;
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (e) {}
  }
}
