// lib/main.dart
// BLOOM GAD Mobile App — Main entry point + AuthGate

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 await Supabase.initialize(
  url:     'https://vfpgzuehfebhawlidhsz.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmcGd6dWVoZmViaGF3bGlkaHN6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMjk4ODMsImV4cCI6MjA4ODYwNTg4M30.ZzaOTYxShnwwLDMNH1uZKb59lYsB6pnNk1mPik2VRR0',
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.implicit,
  ),
);
  runApp(const BloomApp());
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'BLOOM GAD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ── Auth status ───────────────────────────────────────────────────────────────
enum _AuthStatus {
  loading,
  unauthenticated,
  needsRole,
  authenticated,
  passwordRecovery,
}

// ── Recovery URL detection ────────────────────────────────────────────────────
// Supabase puts tokens in the hash fragment after verifying the recovery link:
//   http://localhost:8080/#access_token=...&type=recovery
// We check BOTH fragment and query params to be safe.
bool _isRecoveryUrl() {
  if (!kIsWeb) return false;

  debugPrint('🔍 BASE URI:  ${Uri.base}');
  debugPrint('🔍 FRAGMENT:  ${Uri.base.fragment}');
  debugPrint('🔍 QUERY:     ${Uri.base.queryParameters}');

  // Implicit flow: token arrives in hash fragment
  //   http://localhost:8080/#access_token=...&type=recovery
  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty) {
    final params = Uri.splitQueryString(fragment);
    debugPrint('🔍 FRAGMENT PARAMS: $params');
    if (params['type'] == 'recovery') return true;
  }

  // PKCE flow: code arrives as query param, type also in query
  //   http://localhost:8080/?code=...&type=recovery  (some Supabase versions)
  final query = Uri.base.queryParameters;
  debugPrint('🔍 QUERY PARAMS: $query');
  if (query['type'] == 'recovery') return true;

  return false;
}

// ── AuthGate ──────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _AuthStatus         _status  = _AuthStatus.loading;
  StreamSubscription? _authSub;
  int                 _checkId = 0;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _initAuth() async {
    debugPrint('🚀 _initAuth() called');

    // ── Priority 1: Recovery URL check ──────────────────────────────────
    // Must happen before ANYTHING else — before session check, before
    // subscribing to auth events. The hash fragment is available immediately
    // on page load, before Supabase processes it.
    if (_isRecoveryUrl()) {
      debugPrint('✅ Recovery URL detected in _initAuth — showing ResetPasswordScreen');
      if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
      _subscribeToAuthEvents();
      return;
    }

    // ── Priority 2: Subscribe first, THEN check session ─────────────────
    // Subscribe before session check so we don't miss events that fire
    // during the async gap between subscribe and session resolution.
    _subscribeToAuthEvents();

    // ── Priority 3: Existing session check ──────────────────────────────
    final session = Supabase.instance.client.auth.currentSession;
    debugPrint('🔍 Existing session: ${session != null ? "YES (user: ${session.user.email})" : "NO"}');

    if (session != null) {
      await _resolveAuthenticatedStatus();
    } else {
      if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
    }
  }

  void _subscribeToAuthEvents() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        debugPrint('🔔 AUTH EVENT: $event  |  user: ${data.session?.user.email ?? "none"}');

        // Token refreshes never change routing
        if (event == AuthChangeEvent.tokenRefreshed) return;

        // PASSWORD_RECOVERY fires on mobile (deep link)
        if (event == AuthChangeEvent.passwordRecovery) {
          debugPrint('✅ PASSWORD_RECOVERY event — showing ResetPasswordScreen');
          if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
          return;
        }

        // On web, Supabase fires SIGNED_IN when it exchanges the recovery
        // token from the URL hash. Re-check the URL to distinguish this
        // from a normal login SIGNED_IN event.
        if (event == AuthChangeEvent.signedIn) {
          debugPrint('🔍 SIGNED_IN event — checking if recovery URL...');
          if (_isRecoveryUrl()) {
            debugPrint('✅ Recovery URL confirmed on SIGNED_IN — showing ResetPasswordScreen');
            if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
            return;
          }
          debugPrint('ℹ️ Normal SIGNED_IN — resolving authenticated status');
          await _resolveAuthenticatedStatus();
          return;
        }

        if (event == AuthChangeEvent.signedOut) {
          debugPrint('🔒 SIGNED_OUT — showing unauthenticated');
          if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
          return;
        }
      },
      onError: (e) {
        debugPrint('❌ Auth stream error: $e');
        if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
      },
    );
  }

  Future<void> _resolveAuthenticatedStatus() async {
    final myCheckId = ++_checkId;
    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('🔍 _resolveAuthenticatedStatus — user: ${user?.email ?? "null"}');

    if (user == null) {
      if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (!mounted || myCheckId != _checkId) return;

      final role = profile?['role'];
      debugPrint('🔍 Profile role: $role');

      if (role == null || (role as String).isEmpty) {
        setState(() => _status = _AuthStatus.needsRole);
      } else {
        setState(() => _status = _AuthStatus.authenticated);
      }
    } catch (e) {
      debugPrint('❌ Profile fetch error: $e');
      if (!mounted || myCheckId != _checkId) return;
      setState(() => _status = _AuthStatus.authenticated);
    }
  }

  void _handleSignOut()       => setState(() => _status = _AuthStatus.unauthenticated);
  void _handleRoleSelected()  => setState(() => _status = _AuthStatus.authenticated);
  void _handleResetComplete() => setState(() => _status = _AuthStatus.unauthenticated);

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️  AuthGate build — status: $_status');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_status) {
        _AuthStatus.loading =>
          const _SplashScreen(),

        _AuthStatus.unauthenticated =>
          const _AuthNavigator(),

        _AuthStatus.needsRole =>
          RoleSelectionScreen(
            key:            const ValueKey('roleSelection'),
            onRoleSelected: _handleRoleSelected,
          ),

        _AuthStatus.authenticated =>
          MainShell(
            key:       const ValueKey('mainShell'),
            onSignOut: _handleSignOut,
          ),

        _AuthStatus.passwordRecovery =>
          ResetPasswordScreen(
            key:        const ValueKey('resetPassword'),
            onComplete: _handleResetComplete,
          ),
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// ── Auth navigator ────────────────────────────────────────────────────────────
enum _AuthView { login, signup, signupOtp }

class _AuthNavigator extends StatefulWidget {
  const _AuthNavigator();

  @override
  State<_AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<_AuthNavigator> {
  _AuthView _view       = _AuthView.login;
  String?   _otpEmail;
  String?   _otpFullName;
  String?   _otpStudentId;

  void _goToLogin()  => setState(() => _view = _AuthView.login);
  void _goToSignup() => setState(() => _view = _AuthView.signup);

  void _goToSignupOtp({
    required String email,
    required String fullName,
    String? studentId,
  }) {
    setState(() {
      _otpEmail     = email;
      _otpFullName  = fullName;
      _otpStudentId = studentId ?? '';
      _view         = _AuthView.signupOtp;
    });
  }

  void _onSignupVerified() {}

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (_view) {

        _AuthView.login => LoginScreen(
          key:        const ValueKey('login'),
          onLogin:    _onSignupVerified,
          onGoSignup: _goToSignup,
        ),

        _AuthView.signup => SignupScreen(
          key:       const ValueKey('signup'),
          onGoLogin: _goToLogin,
          onNeedsOtp: ({
            required String email,
            required String fullName,
            String? studentId,
          }) => _goToSignupOtp(
            email:     email,
            fullName:  fullName,
            studentId: studentId,
          ),
        ),

        _AuthView.signupOtp => OtpScreen(
          key:        const ValueKey('signupOtp'),
          email:      _otpEmail!,
          type:       'signup',
          fullName:   _otpFullName,
          studentId:  _otpStudentId,
          onVerified: _onSignupVerified,
          onBack:     _goToSignup,
        ),
      },
    );
  }
}