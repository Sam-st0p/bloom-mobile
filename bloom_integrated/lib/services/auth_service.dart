// lib/services/auth_service.dart
// BLOOM GAD Mobile App — Authentication Service

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/rate_limiter.dart';

final _supabase = Supabase.instance.client;

class AuthService {
  // ── Validate credentials only (no persistent session) ─────────────
  static Future<String?> validateCredentials(String email, String password) async {
    try {
      print('DEBUG: Attempting login with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('DEBUG: Login success, user: ${response.user?.email}');
      // Immediately destroy session — OTP must complete login
      await _supabase.auth.signOut(scope: SignOutScope.local);
      print('DEBUG: Session destroyed, proceeding to OTP');
      return null;
    } on AuthException catch (e) {
      print('DEBUG: AuthException: ${e.message}, statusCode: ${e.statusCode}');
      return e.message;
    } catch (e) {
      print('DEBUG: Unexpected error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign In (validates credentials then sends OTP) ─────────────────
  static Future<String?> signIn(String email, String password) async {
    print('DEBUG: signIn called with email: $email');
    final error = await validateCredentials(email, password);
    if (error != null) {
      print('DEBUG: validateCredentials returned error: $error');
      return error;
    }
    try {
      print('DEBUG: Sending OTP to $email');
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null, // null forces 6-digit code instead of magic link
      );
      print('DEBUG: OTP sent successfully');
      return null;
    } on AuthException catch (e) {
      print('DEBUG: OTP send error: ${e.message}');
      return e.message;
    } catch (e) {
      print('DEBUG: OTP unexpected error: $e');
      return 'Failed to send verification code. Please try again.';
    }
  }

  // ── Sign In with Google ───────────────────────────────────────────────
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
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? googleUser.displayName ?? '',
          'email': user.email,
          'is_active': true,
        });
        await updateLastSignIn();
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      print('GOOGLE SIGN IN ERROR: $e');
      if (msg.contains('cancel') || msg.contains('abort')) {
        return 'Google sign-in cancelled.';
      }
      return 'Google sign-in failed. Please try again.';
    }
  }

  // ── Sign Up ───────────────────────────────────────────────────────────
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

  // ── Complete profile after OTP verified ───────────────────────────────
  static Future<void> signUpCompleteProfile({
    required String email,
    required String fullName,
    required String studentId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('profiles').upsert({
        'id':         user.id,
        'full_name':  fullName,
        'student_id': studentId,
        'email':      email,
        'is_active':  true,
      });
    } catch (_) {}
  }

  // ── Update last sign in ───────────────────────────────────────────────
  static Future<void> updateLastSignIn() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase.from('profiles')
          .update({'last_sign_in_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id);
    } catch (_) {}
  }

  // ── Sign Out ──────────────────────────────────────────────────────────
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

  // ── Check and update inactivity ───────────────────────────────────────
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
      if (lastSignIn == null) { await updateLastSignIn(); return true; }

      final last     = DateTime.parse(lastSignIn);
      final now      = DateTime.now().toUtc();
      final inactive = now.difference(last).inSeconds;
      const kInactivitySeconds = 30 * 24 * 60 * 60;

      if (inactive > kInactivitySeconds) {
        await _supabase.from('profiles')
            .update({'is_active': false}).eq('id', user.id);
        await _supabase.auth.signOut();
        return false;
      }

      await updateLastSignIn();
      return true;
    } catch (_) {
      return true;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  static User? get currentUser => _supabase.auth.currentUser;
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}