import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class DatabaseService {

  // ── MODULES ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchModules() async {
    try {
      final data = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) { /* non-critical */ }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchStudentProgress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('student_progress')
          .select('*')
          .eq('student_id', userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) { /* non-critical */ }
    return [];
  }

  static Future<void> upsertProgress(String moduleId, int progressPct) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('student_progress').upsert({
        'student_id': userId,
        'module_id': moduleId,
        'progress_percentage': progressPct,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) { /* non-critical */ }
  }

  // ── SEMINARS ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchSeminars() async {
    try {
      final data = await _supabase
          .from('seminars')
          .select('*')
          .eq('status', 'active');
      final list = List<Map<String, dynamic>>.from(data);
      list.sort((a, b) {
        final aDate = a['scheduled_at'] ?? a['date'] ?? '';
        final bDate = b['scheduled_at'] ?? b['date'] ?? '';
        return bDate.compareTo(aDate);
      });
      return list;
    } catch (e) { /* non-critical */ }
    return [];
  }

  static Future<String?> registerForSeminar(String seminarId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 'Not logged in';
      await _supabase.from('seminar_registrations').insert({
        'student_id': userId,
        'seminar_id': seminarId,
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
          .eq('student_id', userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) { /* non-critical */ }
    return [];
  }

  // ── CALENDAR EVENTS ───────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    try {
      final data = await _supabase
          .from('calendar_events')
          .select('*')
          .eq('status', 'published');
      final list = List<Map<String, dynamic>>.from(data);
      list.sort((a, b) {
        final aDate = _eventDate(a);
        final bDate = _eventDate(b);
        return aDate.compareTo(bDate);
      });
      return list;
    } catch (e) { /* non-critical */ }
    return [];
  }

  static String _eventDate(Map<String, dynamic> ev) {
    final raw = ev['start_date'] ?? ev['start_time'] ?? ev['scheduled_at'] ?? ev['date'] ?? ev['created_at'];
    return raw != null ? raw.toString().substring(0, 10) : '';
  }

  // ── BADGES ────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchBadges() async {
    try {
      final data = await _supabase.from('badges').select('*');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) { /* non-critical */ }
    return [];
  }

  static Future<List<String>> fetchMyBadgeIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('student_badges')
          .select('badge_id')
          .eq('student_id', userId);
      return List<Map<String, dynamic>>.from(data)
          .map((row) => row['badge_id'].toString())
          .toList();
    } catch (e) { /* non-critical */ }
    return [];
  }

  // ── CERTIFICATES ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchMyCertificates() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _supabase
          .from('certificates')
          .select('*')
          .eq('student_id', userId)
          .eq('status', 'active');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) { /* non-critical */ }
    return [];
  }

  // ── ANNOUNCEMENTS ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final data = await _supabase
          .from('announcements')
          .select('*')
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) { /* non-critical */ }
    return [];
  }

  // ── PROFILE ───────────────────────────────────────────────────────────────
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
    } catch (e) { /* non-critical */ }
    return null;
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (e) { /* non-critical */ }
  }
}
