// lib/main.dart
// BLOOM GAD Mobile App — Main entry point + AuthGate
//
// Role routing rules:
//   • Non-@cvsu.edu.ph (Google) → always guest → MainShell
//   • @cvsu.edu.ph → role already written at OTP verification from masterlist
//                  → AuthGate checks role → MainShell
//   • role empty (edge case: OTP write failed) → query masterlist again,
//     write profile, proceed → MainShell. RoleSelectionScreen no longer shown.

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_screen.dart';
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

  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
    );
  }

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
  authenticated,
  passwordRecovery,
  deactivated,
}

// ── Recovery URL detection (web only) ────────────────────────────────────────
bool _isRecoveryUrl() {
  if (!kIsWeb) return false;
  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty) {
    final params = Uri.splitQueryString(fragment);
    if (params['type'] == 'recovery') return true;
  }
  return Uri.base.queryParameters['type'] == 'recovery';
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
  StreamSubscription? _linkSub;
  RealtimeChannel?    _profileChannel;
  Timer?              _pollTimer;
  int                 _checkId = 0;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initAuth();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _linkSub?.cancel();
    _stopDeactivationWatcher();
    super.dispose();
  }

  // ── Deactivation watcher ──────────────────────────────────────────────────
  void _startDeactivationWatcher(String userId) {
    _stopDeactivationWatcher();
    _profileChannel = _supabase
        .channel('profile-deactivation-$userId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.update,
          schema: 'public',
          table:  'profiles',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'id',
            value:  userId,
          ),
          callback: (payload) {
            final isActive = payload.newRecord['is_active'];
            if (isActive == false) _handleDeactivated();
          },
        )
        .subscribe();

    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      try {
        final row = await _supabase
            .from('profiles')
            .select('is_active')
            .eq('id', user.id)
            .maybeSingle();
        if (row != null && row['is_active'] == false) _handleDeactivated();
      } catch (_) {}
    });
  }

  void _stopDeactivationWatcher() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_profileChannel != null) {
      _supabase.removeChannel(_profileChannel!);
      _profileChannel = null;
    }
  }

  Future<void> _handleDeactivated() async {
    _stopDeactivationWatcher();
    try { await _supabase.auth.signOut(); } catch (_) {}
    if (mounted) setState(() => _status = _AuthStatus.deactivated);
  }

  // ── Deep links ────────────────────────────────────────────────────────────
  void _initDeepLinks() {
    if (kIsWeb) return;
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    _linkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'reset-callback') {
      if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
    }
  }

  // ── Auth init ─────────────────────────────────────────────────────────────
  Future<void> _initAuth() async {
    if (_isRecoveryUrl()) {
      if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
      _subscribeToAuthEvents();
      return;
    }
    _subscribeToAuthEvents();
    final session = _supabase.auth.currentSession;
    if (session != null) {
      await _resolveAuthenticatedStatus();
    } else {
      if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
    }
  }

  void _subscribeToAuthEvents() {
    _authSub = _supabase.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        if (event == AuthChangeEvent.tokenRefreshed) return;

        if (event == AuthChangeEvent.passwordRecovery) {
          if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
          return;
        }

        if (event == AuthChangeEvent.signedIn) {
          if (_isRecoveryUrl()) {
            if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
            return;
          }
          await _resolveAuthenticatedStatus();
          return;
        }

        if (event == AuthChangeEvent.signedOut) {
          if (_status == _AuthStatus.authenticated) {
            _stopDeactivationWatcher();
            if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
          }
          return;
        }
      },
      onError: (_) {
        if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
      },
    );
  }

  // ── Resolve status ────────────────────────────────────────────────────────
  //
  // Non-@cvsu.edu.ph → guest → MainShell
  // @cvsu.edu.ph → role set by OTP screen from masterlist
  //              → if role still empty (OTP write failed), recover from masterlist
  //              → deactivated → DeactivatedScreen
  //
  Future<void> _resolveAuthenticatedStatus() async {
    final myCheckId = ++_checkId;
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
      return;
    }

    final email  = (user.email ?? '').toLowerCase().trim();
    final isCvsu = email.endsWith('@cvsu.edu.ph');

    // ── Non-CvSU (Google) → always guest ─────────────────────────────────
    if (!isCvsu) {
      try {
        await _supabase.from('profiles').upsert({
          'id':         user.id,
          'role':       'guest',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id');
      } catch (_) {}
      if (!mounted || myCheckId != _checkId) return;
      _startDeactivationWatcher(user.id);
      setState(() => _status = _AuthStatus.authenticated);
      return;
    }

    // ── CvSU user → check profile ─────────────────────────────────────────
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role, is_active')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (!mounted || myCheckId != _checkId) return;

      if (profile != null && profile['is_active'] == false) {
        _stopDeactivationWatcher();
        await _supabase.auth.signOut();
        if (mounted) setState(() => _status = _AuthStatus.deactivated);
        return;
      }

      _startDeactivationWatcher(user.id);

      final role = (profile?['role'] as String? ?? '').trim();

      if (role.isEmpty) {
        // OTP screen write may have failed — recover from masterlist.
        await _recoverRoleFromMasterlist(user.id, email);
        if (!mounted || myCheckId != _checkId) return;
      }

      if (mounted) setState(() => _status = _AuthStatus.authenticated);
    } catch (_) {
      if (!mounted || myCheckId != _checkId) return;
      _startDeactivationWatcher(user.id);
      if (mounted) setState(() => _status = _AuthStatus.authenticated);
    }
  }

  /// Fallback: if profile has no role yet, pull from masterlist and write it.
  Future<void> _recoverRoleFromMasterlist(String userId, String email) async {
    try {
      final row = await _supabase
          .from('masterlist')
          .select('role, full_name, student_id, department, course, year_level')
          .eq('cvsu_email', email)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) return; // Not in masterlist — profile stays empty, app still opens.

      final rawYear  = row['year_level'];
      final yearIdx  = rawYear is int ? rawYear : null;

      await _supabase.from('profiles').upsert({
        'id':         userId,
        'full_name':  row['full_name'],
        'role':       row['role'],
        'student_id': row['student_id'],
        'department': row['department'],
        'course':     row['course'],
        'year_level': yearIdx,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
    } catch (_) {
      // Non-fatal — app still opens.
    }
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────
  void _handleOtpVerified() {}   // auth stream handles navigation
  void _handleGuestAuth()  => setState(() => _status = _AuthStatus.authenticated);
  void _handleSignOut() {
    _stopDeactivationWatcher();
    setState(() => _status = _AuthStatus.unauthenticated);
  }
  void _handleResetComplete() => setState(() => _status = _AuthStatus.unauthenticated);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_status) {

        _AuthStatus.loading =>
          const _SplashScreen(),

        _AuthStatus.unauthenticated =>
          _AuthNavigator(
            key:           const ValueKey('authNav'),
            onGuestAuth:   _handleGuestAuth,
            onOtpVerified: _handleOtpVerified,
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

        _AuthStatus.deactivated =>
          _DeactivatedScreen(
            key:     const ValueKey('deactivated'),
            onClose: () => setState(() => _status = _AuthStatus.unauthenticated),
          ),
      },
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );
}

// ── Deactivated ───────────────────────────────────────────────────────────────
class _DeactivatedScreen extends StatelessWidget {
  final VoidCallback onClose;
  const _DeactivatedScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.shield_outlined,
                    size: 40, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 24),
              const Text('Account Deactivated',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2E1A)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Your account has been deactivated by an administrator.\n\n'
                'Please contact your administrator for assistance.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
                textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                  child: const Text('OK',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Auth navigator ────────────────────────────────────────────────────────────
enum _AuthView { login, signup, signupOtp, loginOtp }

class _AuthNavigator extends StatefulWidget {
  final VoidCallback onGuestAuth;
  final VoidCallback onOtpVerified;

  const _AuthNavigator({
    super.key,
    required this.onGuestAuth,
    required this.onOtpVerified,
  });

  @override
  State<_AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<_AuthNavigator> {
  _AuthView _view = _AuthView.login;

  // Signup OTP data — includes masterlist fields
  String?  _otpEmail;
  String?  _otpFullName;
  String   _otpRole       = '';
  String?  _otpStudentId;
  String?  _otpDepartment;
  String?  _otpCourse;
  int?     _otpYearLevel;

  // Login OTP data
  String?  _loginOtpEmail;

  void _goToLogin()  => setState(() => _view = _AuthView.login);
  void _goToSignup() => setState(() => _view = _AuthView.signup);

  void _goToSignupOtp({
    required String  email,
    required String  fullName,
    required String  role,
    required String? studentId,
    required String? department,
    required String? course,
    required int?    yearLevel,
  }) {
    setState(() {
      _otpEmail      = email;
      _otpFullName   = fullName;
      _otpRole       = role;
      _otpStudentId  = studentId;
      _otpDepartment = department;
      _otpCourse     = course;
      _otpYearLevel  = yearLevel;
      _view          = _AuthView.signupOtp;
    });
  }

  void _goToLoginOtp({ required String email }) {
    setState(() {
      _loginOtpEmail = email;
      _view          = _AuthView.loginOtp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (_view) {

        _AuthView.login => LoginScreen(
          key:          const ValueKey('login'),
          onLogin:      (String email) => _goToLoginOtp(email: email),
          onGuestLogin: widget.onGuestAuth,
          onGoSignup:   _goToSignup,
        ),

        _AuthView.signup => SignupScreen(
          key:           const ValueKey('signup'),
          onGoLogin:     _goToLogin,
          onNeedsOtp:    ({
            required String  email,
            required String  fullName,
            required String  role,
            required String? studentId,
            required String? department,
            required String? course,
            required int?    yearLevel,
          }) => _goToSignupOtp(
            email:      email,
            fullName:   fullName,
            role:       role,
            studentId:  studentId,
            department: department,
            course:     course,
            yearLevel:  yearLevel,
          ),
          onGuestSignup: widget.onGuestAuth,
        ),

        _AuthView.signupOtp => OtpScreen(
          key:        const ValueKey('signupOtp'),
          email:      _otpEmail!,
          fullName:   _otpFullName!,
          role:       _otpRole,
          studentId:  _otpStudentId,
          department: _otpDepartment,
          course:     _otpCourse,
          yearLevel:  _otpYearLevel,
          onVerified: widget.onOtpVerified,
          onBack:     _goToSignup,
        ),

        _AuthView.loginOtp => OtpScreen(
          key:        const ValueKey('loginOtp'),
          email:      _loginOtpEmail!,
          fullName:   '',
          onVerified: widget.onOtpVerified,
          onBack:     _goToLogin,
        ),
      },
    );
  }
}