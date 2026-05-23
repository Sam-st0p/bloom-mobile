// lib/services/auth_service.dart
// BLOOM GAD Mobile App — Authentication Service

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/rate_limiter.dart';

final _supabase = Supabase.instance.client;

class AuthService {
  // ── Validate credentials only (no persistent session) ──────────────
  static Future<String?> validateCredentials(
      String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _supabase.auth.signOut(scope: SignOutScope.local);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign In: validate credentials then send OTP ─────────────────────
  static Future<String?> signIn(String email, String password) async {
    final error = await validateCredentials(email, password);
    if (error != null) return error;
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to send verification code. Please try again.';
    }
  }

  // ── Sign In with Google ─────────────────────────────────────────────
  static bool _googleInitialized = false;

  static Future<String?> signInWithGoogle() async {
    try {
      final bool isWeb = identical(0, 0.0);

      if (isWeb) {
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        return null;
      }

      const webClientId =
          '7383107443-fbiv7p4kb10voq9c88d8i0ccda6idejl.apps.googleusercontent.com';
      const androidClientId =
          '7383107443-9mnl4tqep7bu5vu2octrm69c58c6n1sq.apps.googleusercontent.com';

      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          clientId: androidClientId,
          serverClientId: webClientId,
        );
        _googleInitialized = true;
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) return 'No ID token from Google.';

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _ensureProfile(
          userId:   user.id,
          email:    user.email ?? '',
          fullName: user.userMetadata?['full_name'] ??
                    googleUser.displayName ?? '',
        );
        await updateLastSignIn();
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('abort')) {
        return 'Google sign-in cancelled.';
      }
      return 'Google sign-in failed. Please try again.';
    }
  }

  // ── Sign Up ─────────────────────────────────────────────────────────
  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'student_id': studentId},
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Sign up failed. Please try again.';
    }
  }

  // ── Complete profile after OTP verified ─────────────────────────────
  // Uses INSERT ... ON CONFLICT DO UPDATE so it works whether or not
  // a partial row already exists. Never throws on conflict.
  static Future<void> signUpCompleteProfile({
    required String email,
    required String fullName,
    required String studentId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _supabase.from('profiles').upsert(
      {
        'id':         user.id,
        'full_name':  fullName,
        'student_id': studentId.isEmpty ? null : studentId,
        'email':      email,
        'is_active':  true,
        'role':       null, // explicit null — let RoleSelectionScreen set this
      },
      onConflict: 'id',          // if row exists, update it
      ignoreDuplicates: false,   // always apply the update
    );
  }

  // ── Internal: ensure a profile row exists (used by Google sign-in) ──
  static Future<void> _ensureProfile({
    required String userId,
    required String email,
    required String fullName,
  }) async {
    await _supabase.from('profiles').upsert(
      {
        'id':        userId,
        'email':     email,
        'full_name': fullName,
        'is_active': true,
      },
      onConflict:       'id',
      ignoreDuplicates: false,
    );
  }

  // ── Update last sign in ─────────────────────────────────────────────
  static Future<void> updateLastSignIn() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase
          .from('profiles')
          .update({
            'last_sign_in_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (_) {}
  }

  // ── Sign Out ────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    RateLimiter.reset('login');
    RateLimiter.reset('reset');
    try { await GoogleSignIn.instance.signOut(); } catch (_) {}
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
  }

  // ── Check and update inactivity ─────────────────────────────────────
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

  // ── Helpers ─────────────────────────────────────────────────────────
  static User? get currentUser => _supabase.auth.currentUser;
  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}