// lib/services/auth_service.dart
// BLOOM GAD Mobile App — Authentication Service

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/rate_limiter.dart';
import '../utils/validators.dart';

final _supabase = Supabase.instance.client;

class AuthService {

  // ── Validate credentials only (no persistent session) ─────────────
  static Future<String?> validateCredentials(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email, password: password);
      // Immediately destroy session — OTP must complete login
      await _supabase.auth.signOut(scope: SignOutScope.local);
      return null;
    } on AuthException catch (e) {
      // Generic message — never reveal if email exists or not
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('credentials') ||
          msg.contains('not found') || msg.contains('wrong')) {
        return 'Invalid email or password.';
      }
      if (msg.contains('too many') || msg.contains('rate')) {
        return 'Too many attempts. Please wait and try again.';
      }
      return 'Invalid email or password.';
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign In (validates credentials then sends OTP) ─────────────────
  static Future<String?> signIn(String email, String password) async {
    // Sanitize inputs
    final cleanEmail = AppValidators.normalizeEmail(email);

    final error = await validateCredentials(cleanEmail, password);
    if (error != null) return error;

    try {
      await _supabase.auth.signInWithOtp(
        email:            cleanEmail,
        shouldCreateUser: false,
        emailRedirectTo:  null,
      );
      return null;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate') || msg.contains('too many')) {
        return 'Too many requests. Please wait a moment and try again.';
      }
      return 'Failed to send verification code. Please try again.';
    } catch (_) {
      return 'Failed to send verification code. Please try again.';
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────────
  //
  // Supabase silently returns HTTP 200 for duplicate signups when email
  // confirmation is enabled — no AuthException is thrown. The response
  // object is the only reliable signal: a genuine new account always has
  // at least one entry in user.identities, while a duplicate signup returns
  // an identities list that is empty []. This is Supabase's documented
  // behaviour for detecting duplicate registrations on the client side.
  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    final cleanEmail    = AppValidators.normalizeEmail(email);
    final cleanFullName = AppValidators.sanitizeName(fullName);

    try {
      final response = await _supabase.auth.signUp(
        email:    cleanEmail,
        password: password,
        data: {
          'full_name': cleanFullName,
        },
      );

      // ── Duplicate email detection ──────────────────────────────────
      // When email confirmations are ON, Supabase returns a fake-success
      // response instead of an error. The tell is an empty identities list.
      // A real new user always has identities.length >= 1.
      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        return 'This email is already associated with an existing account. '
               'Please log in or use a different email address.';
      }

      return null;

    } on AuthException catch (e) {
      // Fallback for Supabase configs that DO throw on duplicates,
      // and for any other auth-layer errors.
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        return 'This email is already associated with an existing account. '
               'Please log in or use a different email address.';
      }
      if (msg.contains('password')) {
        return 'Password does not meet the requirements.';
      }
      if (msg.contains('invalid email')) {
        return 'Please enter a valid email address.';
      }
      return 'Sign up failed. Please try again.';
    } catch (_) {
      return 'Sign up failed. Please try again.';
    }
  }

  // ── Complete profile after OTP verified (signup) ───────────────────
  static Future<void> signUpCompleteProfile({
    required String email,
    required String fullName,
    String? studentId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profiles').upsert({
        'id':        user.id,
        'full_name': AppValidators.sanitizeName(fullName),
        'email':     AppValidators.normalizeEmail(email),
        'is_active': true,
        'role':      null, // role set separately in RoleSelectionScreen
      }, onConflict: 'id', ignoreDuplicates: false);
    } catch (_) {
      // Non-blocking — AuthGate will handle routing via role check
    }
  }

  // ── Sign In with Google ────────────────────────────────────────────
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
          clientId:       androidClientId,
          serverClientId: webClientId,
        );
        _googleInitialized = true;
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken    = googleUser.authentication.idToken;
      if (idToken == null) return 'Google sign-in failed. Please try again.';

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken:  idToken,
      );

      await _ensureProfile();
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

  // ── Ensure profile row exists (Google users) ───────────────────────
  static Future<void> _ensureProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final existing = await _supabase
          .from('profiles')
          .select('id, role')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').insert({
          'id':        user.id,
          'full_name': AppValidators.sanitizeName(
              user.userMetadata?['full_name']?.toString() ?? ''),
          'email':     user.email ?? '',
          'is_active': true,
          'role':      null,
        });
      }

      await updateLastSignIn();
    } catch (_) {}
  }

  // ── Update last sign in ────────────────────────────────────────────
  static Future<void> updateLastSignIn() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      await _supabase
          .from('profiles')
          .update({'last_sign_in_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id);
    } catch (_) {}
  }

  // ── Sign Out ───────────────────────────────────────────────────────
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

  // ── Check and update inactivity ────────────────────────────────────
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

  // ── Helpers ────────────────────────────────────────────────────────
  static User?              get currentUser       => _supabase.auth.currentUser;
  static Stream<AuthState>  get authStateChanges  => _supabase.auth.onAuthStateChange;
}