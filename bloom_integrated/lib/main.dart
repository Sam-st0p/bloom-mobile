import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load config from JSON asset (works on Web + Mobile)
  final configString = await rootBundle.loadString('assets/config.json');
  final config = jsonDecode(configString) as Map<String, dynamic>;

  final supabaseUrl = config['SUPABASE_URL'] as String?;
  final supabaseAnonKey = config['SUPABASE_ANON_KEY'] as String?;

  assert(supabaseUrl != null && supabaseUrl.isNotEmpty, 'SUPABASE_URL is missing in config.json');
  assert(supabaseAnonKey != null && supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY is missing in config.json');

  // Initialize Supabase — must happen before runApp()
  await Supabase.initialize(
    url: supabaseUrl!,
    anonKey: supabaseAnonKey!,
  );

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.primaryDark,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const BloomApp());
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLOOM — GADRC CvSU',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
    );
  }
}

/// Listens to Supabase auth state and routes automatically.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        final session = snapshot.data?.session;
        if (session != null) {
          return MainShell(
            onSignOut: () async {
              await Supabase.instance.client.auth.signOut();
            },
          );
        }
        return const _AuthNavigator();
      },
    );
  }
}

class _AuthNavigator extends StatefulWidget {
  const _AuthNavigator();
  @override
  State<_AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends State<_AuthNavigator> {
  bool _showSignup = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _showSignup
          ? SignupScreen(
              key: const ValueKey('signup'),
              onGoLogin: () => setState(() => _showSignup = false),
              onSignup: () => setState(() => _showSignup = false),
            )
          : LoginScreen(
              key: const ValueKey('login'),
              onLogin: () {},
              onGoSignup: () => setState(() => _showSignup = true),
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('⚧', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'BLOOM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'GADRC CvSU',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}