import 'package:supabase_flutter/supabase_flutter.dart';

// Use Supabase.instance.client directly — no separate config file needed
final _supabase = Supabase.instance.client;

class AuthService {
  static Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
    required String courseYear,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'student_id': studentId,
          'course_year': courseYear,
        },
      );
      if (response.user != null) {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': fullName,
          'student_id': studentId,
          'course_year': courseYear,
          'email': email,
        });
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Sign up failed. Please try again.';
    }
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  static get currentUser => _supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
