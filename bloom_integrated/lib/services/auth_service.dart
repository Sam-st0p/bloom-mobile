// lib/services/auth_service.dart
// BLOOM GAD Mobile App — Authentication Service

import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/rate_limiter.dart';

final _supabase = Supabase.instance.client;

class AuthService {
  // ── Sign In ────────────────────────────────────────────────
  static Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Update last_sign_in_at for inactivity tracking
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('profiles')
            .update({
              'last_sign_in_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', user.id);
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign Up ────────────────────────────────────────────────
  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
    required String department,
    required int    yearLevel,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name':  fullName,
          'student_id': studentId,
          'department': department,
          'year_level': yearLevel,
        },
      );

      if (response.user != null) {
        await _supabase.from('profiles').upsert({
          'id':          response.user!.id,
          'full_name':   fullName,
          'student_id':  studentId,
          'department':  department,
          'year_level':  yearLevel,
          'email':       email,
          'is_active':   true,
        });
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Sign up failed. Please try again.';
    }
  }

  // ── Sign Out ───────────────────────────────────────────────
  // Clears rate limiter state and forces local session cleanup
  // even if the network call fails
  static Future<void> signOut() async {
    // Clear client-side rate limit counters on logout
    RateLimiter.reset('login');
    RateLimiter.reset('reset');

    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // If network fails, force local session clear so the
      // user is not stuck in a broken auth state
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
  }

  // ── Check and update inactivity ────────────────────────────
  // Call this after every successful login.
  // Returns true if account is still active,
  // false if it has been deactivated due to inactivity.
  static Future<bool> checkAndUpdateActivity() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profile = await _supabase
          .from('profiles')
          .select('last_sign_in_at, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) return false;

      // Already deactivated by admin
      if (profile['is_active'] == false) return false;

      final lastSignIn = profile['last_sign_in_at'];

      // Null means fresh/reactivated account — grant access
      if (lastSignIn == null) {
        await _updateLastSignIn(user.id);
        return true;
      }

      final last     = DateTime.parse(lastSignIn);
      final now      = DateTime.now().toUtc();
      final inactive = now.difference(last).inSeconds;

      const kInactivitySeconds = 30 * 24 * 60 * 60; // 30 days

      if (inactive > kInactivitySeconds) {
        // Deactivate and sign out
        await _supabase
            .from('profiles')
            .update({'is_active': false})
            .eq('id', user.id);
        await _supabase.auth.signOut();
        return false;
      }

      await _updateLastSignIn(user.id);
      return true;
    } catch (_) {
      // On error, allow access — don't block legitimate users
      return true;
    }
  }

  static Future<void> _updateLastSignIn(String userId) async {
    await _supabase
        .from('profiles')
        .update({
          'last_sign_in_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  // ── Helpers ────────────────────────────────────────────────
  static User? get currentUser => _supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
