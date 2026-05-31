// lib/services/auth_service.dart
// BLOOM GAD Mobile App — Auth Service

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  // ── Sign In (email + password → OTP flow) ──────────────────────────────────
  // Called by LoginScreen as: AuthService.signIn(email, password)
  // Returns null on success, or an error string on failure.
  static Future<String?> signIn(String email, String password) async {
    try {
      // Step 1: Verify credentials
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = authResponse.user?.id;
      if (userId == null) return 'Invalid email or password.';

      // Step 2: Check is_active before allowing OTP
      final profile = await _supabase
          .from('profiles')
          .select('is_active')
          .eq('id', userId)
          .maybeSingle();

      // Sign out immediately — session is established only after OTP
      await _supabase.auth.signOut();

      if (profile == null) return 'Account not found.';

      final isActive = profile['is_active'] as bool? ?? false;
      if (!isActive) {
        return 'Your account has been deactivated. Please contact support.';
      }

      // Step 3: Send OTP to the verified, active user
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );

      return null; // success — OTP sent
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Sign Up ─────────────────────────────────────────────────────────────────
  // Called by SignupScreen as:
  //   AuthService.signUp(email: ..., password: ..., fullName: ..., studentId: ...)
  // Returns null on success, or an error string on failure.
  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name':  fullName,
          'student_id': studentId,
        },
      );

      if (response.user == null) {
        return 'Sign up failed. Please try again.';
      }

      return null; // success — OTP sent by Supabase automatically
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        return 'An account with this email already exists.';
      }
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Complete Profile after signup OTP ───────────────────────────────────────
  // Called by OtpScreen as:
  //   AuthService.signUpCompleteProfile(email: ..., fullName: ..., studentId: ...)
  // Writes/updates the profiles row. Non-fatal — caller wraps in try/catch.
  static Future<void> signUpCompleteProfile({
    required String email,
    required String fullName,
    required String studentId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('profiles').upsert({
      'id':         userId,
      'email':      email,
      'full_name':  fullName,
      'student_id': studentId,
      'is_active':  true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Update last_sign_in timestamp ───────────────────────────────────────────
  // Called by OtpScreen after a successful login OTP verification.
  static Future<void> updateLastSignIn() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('profiles').update({
      'last_sign_in_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  // Called by both LoginScreen and SignupScreen as: AuthService.signInWithGoogle()
  // Returns null on success, 'Google sign-in cancelled.' if user cancelled,
  // or an error string on failure.
  static Future<String?> signInWithGoogle() async {
    try {
      // Web: use Supabase OAuth redirect
      if (kIsWeb) {
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:8080',
        );
        return null;
      }

      // Mobile (Android / iOS): google_sign_in v7+ uses GoogleSignIn.instance
      // and authenticateOrReauthenticate() instead of the old constructor + signIn().
      final googleSignIn = GoogleSignIn.instance;

      // Initialise once — safe to call multiple times (no-op if already done).
      await googleSignIn.initialize();

      // Attempt silent sign-in first (returns quickly if already signed in).
      GoogleSignInAccount? googleUser =
          await googleSignIn.attemptLightweightAuthentication();

      // Fall back to the full interactive flow if silent sign-in didn't work.
      googleUser ??=
          googleUser ??= await googleSignIn.authenticate();

      if (googleUser == null) return 'Google sign-in cancelled.';

      final googleAuth  = googleUser.authentication;
      final idToken     = googleAuth.idToken;

      if (idToken == null) return 'Google sign-in failed. Please try again.';

      await _supabase.auth.signInWithIdToken(
        provider:    OAuthProvider.google,
        idToken:     idToken,
      );

      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('cancelled')) {
        return 'Google sign-in cancelled.';
      }
      return 'Google sign-in failed. Please try again.';
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}