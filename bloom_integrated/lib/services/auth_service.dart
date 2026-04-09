// lib/services/auth_service.dart
// BLOOM GAD Mobile App — Authentication Service

import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/rate_limiter.dart';

final _supabase = Supabase.instance.client;

class AuthService {
  // ── Sign In ────────────────────────────────────────────
  static Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign Up Step 1 — create auth account only ──────────
  // Does NOT insert profile yet — profile is inserted after
  // OTP verification in signUpCompleteProfile()
  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
    required String department,
    required int    yearLevel,
  }) async {
    try {
      await _supabase.auth.signUp(
        email:    email,
        password: password,
        data: {
          'full_name':  fullName,
          'student_id': studentId,
          'department': department,
          'year_level': yearLevel,
        },
      );
      // Profile insert is deferred to after OTP verification
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Sign up failed. Please try again.';
    }
  }

  // ── Sign Up Step 2 — insert profile after OTP verified ─
  // Call this from OtpScreen.onVerified for signup flow
  static Future<void> signUpCompleteProfile({
    required String email,
    required String fullName,
    required String studentId,
    required String department,
    required int    yearLevel,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profiles').upsert({
        'id':          user.id,
        'full_name':   fullName,
        'student_id':  studentId,
        'department':  department,
        'year_level':  yearLevel,
        'email':       email,
        'is_active':   true,
      });
    } catch (_) {
      // Non-fatal — profile can be completed later
    }
  }

  // ── Update last sign in ────────────────────────────────
  static Future<void> updateLastSignIn() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase
          .from('profiles')
          .update({
            'last_sign_in_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (_) {}
  }

  // ── Sign Out ───────────────────────────────────────────
  static Future<void> signOut() async {
    RateLimiter.reset('login');
    RateLimiter.reset('reset');
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
  }

  // ── Check and update inactivity ────────────────────────
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
      if (profile['is_active'] == false) return false;

      final lastSignIn = profile['last_sign_in_at'];
      if (lastSignIn == null) {
        await updateLastSignIn();
        return true;
      }

      final last     = DateTime.parse(lastSignIn);
      final now      = DateTime.now().toUtc();
      final inactive = now.difference(last).inSeconds;
      const kInactivitySeconds = 30 * 24 * 60 * 60;

      if (inactive > kInactivitySeconds) {
        await _supabase
            .from('profiles')
            .update({'is_active': false})
            .eq('id', user.id);
        await _supabase.auth.signOut();
        return false;
      }

      await updateLastSignIn();
      return true;
    } catch (_) {
      return true;
    }
  }

  // ── Helpers ────────────────────────────────────────────
  static User? get currentUser => _supabase.auth.currentUser;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}