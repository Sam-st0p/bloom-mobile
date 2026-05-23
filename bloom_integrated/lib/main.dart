// lib/main.dart
// BLOOM GAD Mobile App

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/main_shell.dart';
import 'screens/role_selection_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configString = await rootBundle.loadString('assets/config.json');
  final config = jsonDecode(configString) as Map<String, dynamic>;

  final supabaseUrl     = config['SUPABASE_URL']     as String?;
  final supabaseAnonKey = config['SUPABASE_ANON_KEY'] as String?;

  assert(supabaseUrl     != null && supabaseUrl.isNotEmpty,
      'SUPABASE_URL is missing in config.json');
  assert(supabaseAnonKey != null && supabaseAnonKey.isNotEmpty,
      'SUPABASE_ANON_KEY is missing in config.json');

  await Supabase.initialize(url: supabaseUrl!, anonKey: supabaseAnonKey!);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          AppColors.primaryDark,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const BloomApp());
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'BLOOM — GADRC CvSU',
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.theme,
      home:                       const AuthGate(),
    );
  }
}

enum _AuthStatus { loading, unauthenticated, needsRole, authenticated }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _AuthStatus _status        = _AuthStatus.loading;
  int         _pendingCheckId = 0;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        // Ignore token refreshes — they don't change auth state.
        if (data.event == AuthChangeEvent.tokenRefreshed) return;
        _handleAuthChange(data.session);
      },
    );

    // Evaluate existing session on cold start / page reload.
    _handleAuthChange(Supabase.instance.client.auth.currentSession);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(Session? session) async {
    final myId = ++_pendingCheckId;
    if (!mounted) return;

    if (session == null) {
      if (myId == _pendingCheckId && mounted) {
        setState(() => _status = _AuthStatus.unauthenticated);
      }
      return;
    }

    if (_status != _AuthStatus.loading) {
      if (myId == _pendingCheckId && mounted) {
        setState(() => _status = _AuthStatus.loading);
      }
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (myId != _pendingCheckId || !mounted) return;

      final role = (profile?['role'] as String?)?.trim() ?? '';
      setState(() => _status = role.isEmpty
          ? _AuthStatus.needsRole
          : _AuthStatus.authenticated);

    } on TimeoutException {
      if (myId == _pendingCheckId && mounted) {
        setState(() => _status = _AuthStatus.needsRole);
      }
    } catch (_) {
      if (myId == _pendingCheckId && mounted) {
        setState(() => _status = _AuthStatus.needsRole);
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Widget _buildForStatus() {
    switch (_status) {
      case _AuthStatus.loading:
        return const _SplashScreen(key: ValueKey('splash'));
      case _AuthStatus.unauthenticated:
        return _AuthNavigator(
          key:      const ValueKey('auth'),
          onSignIn: () {},
        );
      case _AuthStatus.needsRole:
        return RoleSelectionScreen(
          key:            const ValueKey('role'),
          onRoleSelected: () {
            if (mounted) setState(() => _status = _AuthStatus.authenticated);
          },
        );
      case _AuthStatus.authenticated:
        return MainShell(
          key:       const ValueKey('shell'),
          onSignOut: _signOut,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildForStatus(),
    );
  }
}

// ── Auth navigator: login ↔ signup ↔ OTP (all inline, no Navigator.push) ──

class _AuthNavigator extends StatefulWidget {
  final VoidCallback onSignIn;
  const _AuthNavigator({super.key, required this.onSignIn});
  @override
  State<_AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<_AuthNavigator> {
  // Which screen to show
  _AuthView _view = _AuthView.login;

  // Signup OTP state — carried here so no Navigator stack exists
  String _otpEmail    = '';
  String _otpFullName = '';

  void _goLogin()  => setState(() => _view = _AuthView.login);
  void _goSignup() => setState(() => _view = _AuthView.signup);

  void _goSignupOtp({ required String email, required String fullName }) {
    setState(() {
      _otpEmail    = email;
      _otpFullName = fullName;
      _view        = _AuthView.signupOtp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end:   Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _buildView(),
    );
  }

  Widget _buildView() {
    switch (_view) {
      case _AuthView.login:
        return LoginScreen(
          key:        const ValueKey('login'),
          onLogin:    widget.onSignIn,
          onGoSignup: _goSignup,
        );

      case _AuthView.signup:
        return SignupScreen(
          key:       const ValueKey('signup'),
          onGoLogin: _goLogin,
          // SignupScreen calls this when signUp() succeeds,
          // passing email + fullName so we can show OTP inline.
          onNeedsOtp: _goSignupOtp,
        );

      case _AuthView.signupOtp:
        return OtpScreen(
          key:        const ValueKey('signupOtp'),
          email:      _otpEmail,
          type:       'signup',
          fullName:   _otpFullName,
          studentId:  '',
          // onVerified is a no-op — AuthGate drives routing.
          onVerified: () {},
          onBack:     _goSignup,
        );
    }
  }
}

enum _AuthView { login, signup, signupOtp }

// ── Splash ──────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.diversity_3_outlined,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('BLOOM',
                style: TextStyle(
                    color:         Colors.white,
                    fontSize:      28,
                    fontWeight:    FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('GADRC CvSU',
                style: TextStyle(
                    color:    Colors.white.withOpacity(0.6),
                    fontSize: 14)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}