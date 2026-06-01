// lib/main.dart
// BLOOM GAD Mobile App — Main entry point + AuthGate

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
  needsRole,
  authenticated,
  passwordRecovery,
  deactivated,      // ← NEW: account was deactivated while logged in
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
  RealtimeChannel?    _profileChannel;   // ← NEW
  Timer?              _pollTimer;        // ← NEW
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

  // ── Realtime + polling watcher ────────────────────────────────────────────
  void _startDeactivationWatcher(String userId) {
    _stopDeactivationWatcher(); // tear down any existing watcher first

    // 1. Supabase Realtime — instant detection
    _profileChannel = _supabase
        .channel('profile-deactivation-$userId')
        .onPostgresChanges(
          event:    PostgresChangeEvent.update,
          schema:   'public',
          table:    'profiles',
          filter:   PostgresChangeFilter(
            type:   FilterType.eq,
            column: 'id',
            value:  userId,
          ),
          callback: (payload) {
            debugPrint('[Realtime] profiles UPDATE: ${payload.newRecord}');
            final isActive = payload.newRecord['is_active'];
            if (isActive == false) {
              debugPrint('[Realtime] Account deactivated — forcing logout');
              _handleDeactivated();
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[Realtime] subscription status: $status  error: $error');
        });

    // 2. Polling every 30 s — catches Realtime misses
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      try {
        final row = await _supabase
            .from('profiles')
            .select('is_active')
            .eq('id', user.id)
            .maybeSingle();
        debugPrint('[Poll] is_active = ${row?['is_active']}');
        if (row != null && row['is_active'] == false) {
          debugPrint('[Poll] Account deactivated — forcing logout');
          _handleDeactivated();
        }
      } catch (e) {
        debugPrint('[Poll] error: $e');
      }
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

  // Called when deactivation is detected (Realtime or poll)
  Future<void> _handleDeactivated() async {
    _stopDeactivationWatcher();
    try { await _supabase.auth.signOut(); } catch (_) {}
    if (mounted) setState(() => _status = _AuthStatus.deactivated);
  }

  // ── Deep link listener (mobile only) ──────────────────────────────────────
  void _initDeepLinks() {
    if (kIsWeb) return;
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    _linkSub = appLinks.uriLinkStream.listen((uri) => _handleDeepLink(uri));
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'reset-callback') {
      if (mounted) setState(() => _status = _AuthStatus.passwordRecovery);
    }
  }

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
        debugPrint('AUTH EVENT: $event | user: ${data.session?.user.email ?? "none"}');

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
          _stopDeactivationWatcher();
          if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
          return;
        }
      },
      onError: (e) {
        debugPrint('Auth stream error: $e');
        if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
      },
    );
  }

  Future<void> _resolveAuthenticatedStatus() async {
    final myCheckId = ++_checkId;
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _status = _AuthStatus.unauthenticated);
      return;
    }

    try {
      // ── FIX: fetch BOTH role AND is_active ──────────────────────────
      final profile = await _supabase
          .from('profiles')
          .select('role, is_active')          // ← was 'role' only
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (!mounted || myCheckId != _checkId) return;

      // ── FIX: block deactivated accounts immediately ─────────────────
      if (profile != null && profile['is_active'] == false) {
        debugPrint('Account is deactivated — signing out');
        _stopDeactivationWatcher();
        await _supabase.auth.signOut();
        if (mounted) setState(() => _status = _AuthStatus.deactivated);
        return;
      }

      final role = profile?['role'];

      if (role == null || (role as String).isEmpty) {
        // Start watcher even for users who still need to pick a role
        _startDeactivationWatcher(user.id);
        if (mounted) setState(() => _status = _AuthStatus.needsRole);
      } else {
        // ── FIX: start watcher when user is fully authenticated ────────
        _startDeactivationWatcher(user.id);
        if (mounted) setState(() => _status = _AuthStatus.authenticated);
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
      if (!mounted || myCheckId != _checkId) return;
      // On error, still start watcher if we have a user
      _startDeactivationWatcher(user.id);
      if (mounted) setState(() => _status = _AuthStatus.authenticated);
    }
  }

  void _handleSignOut() {
    _stopDeactivationWatcher();
    setState(() => _status = _AuthStatus.unauthenticated);
  }

  void _handleRoleSelected()  => setState(() => _status = _AuthStatus.authenticated);
  void _handleResetComplete() => setState(() => _status = _AuthStatus.unauthenticated);

  @override
  Widget build(BuildContext context) {
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

        // ── NEW: Deactivated screen ─────────────────────────────────
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
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// ── Deactivated Screen ────────────────────────────────────────────────────────
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 40,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Account Deactivated',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2E1A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                const Text(
                  'Your account has been deactivated by an administrator.\n\nPlease contact your administrator for assistance.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // OK button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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