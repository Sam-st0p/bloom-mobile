import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../utils/rate_limiter.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onGoSignup;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onGoSignup,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController  = TextEditingController();
  bool    _obscurePass   = true;
  bool    _loading       = false;
  String? _error;
  bool    _showOtp       = false;
  String  _email         = '';

  // ── Cooldown timer ─────────────────────────────────────
  int  _cooldownSeconds = 0;
  bool _isCoolingDown   = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ── Cooldown countdown ─────────────────────────────────
  void _startCooldownTimer(int seconds) {
    setState(() { _cooldownSeconds = seconds; _isCoolingDown = true; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        setState(() { _isCoolingDown = false; _error = null; });
        return false;
      }
      return true;
    });
  }

  // ── Login handler ──────────────────────────────────────
  Future<void> _handleLogin() async {
    setState(() => _error = null);

    if (RateLimiter.isLocked('login')) {
      final secs = RateLimiter.remainingCooldown('login')?.inSeconds ?? 30;
      setState(() => _error = 'Too many attempts. Please wait $secs seconds.');
      _startCooldownTimer(secs);
      return;
    }

    final emailError = AppValidators.email(_emailController.text);
    if (emailError != null) { setState(() => _error = emailError); return; }
    final passError = AppValidators.loginPassword(_passController.text);
    if (passError != null)  { setState(() => _error = passError);  return; }

    setState(() => _loading = true);

    try {
      await AuthService.signIn(
        AppValidators.sanitize(_emailController.text).toLowerCase(),
        _passController.text,
      );
      RateLimiter.reset('login');

      if (mounted) {
        setState(() {
          _loading = false;
          _email   = AppValidators.sanitize(_emailController.text).toLowerCase();
          _showOtp = true;
        });
      }

    } on AuthException catch (e) {
      final justLocked = RateLimiter.recordFailure(
          'login', maxAttempts: 6, cooldownSecs: 30);
      if (justLocked) {
        setState(() => _error = 'Too many attempts. Please wait 30 seconds.');
        _startCooldownTimer(30);
      } else {
        final used      = RateLimiter.attemptCount('login');
        final remaining = 6 - used;
        final message   = _friendlyAuthError(e.message);
        setState(() => _error = remaining > 0
            ? '$message ($remaining attempt${remaining == 1 ? '' : 's'} remaining)'
            : message);
      }
      setState(() => _loading = false);

    } catch (_) {
      setState(() {
        _error   = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  // ── Forgot password handler ────────────────────────────
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above, then tap Forgot Password.');
      return;
    }
    final emailError = AppValidators.email(email);
    if (emailError != null) { setState(() => _error = emailError); return; }

    if (RateLimiter.isLocked('reset')) {
      setState(() => _error = 'Too many reset attempts. Please wait a minute.');
      return;
    }
    RateLimiter.recordFailure('reset',
        maxAttempts: 3, windowSecs: 300, cooldownSecs: 60);

    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        AppValidators.sanitize(email).toLowerCase());
      if (mounted) _showResetSentDialog(email);
    } catch (_) {
      if (mounted) _showResetSentDialog(email);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResetSentDialog(String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Check your email',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark)),
        ]),
        content: Text(
          'If an account exists for $email, a password reset link has been sent.\n\n'
          'Check your inbox and follow the link to reset your password.',
          style: GoogleFonts.nunito(
              fontSize: 14, color: AppColors.textMid, height: 1.5)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            child: Text('Got it',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  String _friendlyAuthError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('invalid_credentials')) return 'Incorrect email or password.';
    if (r.contains('invalid login'))       return 'Incorrect email or password.';
    if (r.contains('email not found'))     return 'No account found with this email.';
    if (r.contains('too many'))            return 'Too many attempts. Please wait and try again.';
    if (r.contains('network'))             return 'No internet connection. Please check your network.';
    return 'Incorrect email or password.';
  }

  @override
  Widget build(BuildContext context) {
    if (_showOtp) {
      return OtpScreen(
        email:      _email,
        type:       'login',
        onVerified: widget.onLogin,
        onBack: () => setState(() {
          _showOtp = false;
          Supabase.instance.client.auth.signOut(
              scope: SignOutScope.local);
        }),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Oval gradient header ───────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.elliptical(220, 80),
                bottomRight: Radius.elliptical(220, 80),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
            child: Column(children: [
              // ── Logo icon replacing ⚧ emoji ───────────
              Container(
                width: 76, height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1.5)),
                child: const Center(
                  child: Icon(
                    Icons.diversity_3_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('GADRC CvSU',
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('Gender & Development Resource Center',
                  style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.75), fontSize: 13)),
              const SizedBox(height: 8),
            ]),
          ),

          // ── Form area ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back!',
                      style: GoogleFonts.nunito(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Text('Sign in to continue your GAD journey',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textLight)),
                  const SizedBox(height: 28),

                  // ── Error / cooldown banner ────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3))),
                      child: Row(children: [
                        Icon(
                            _isCoolingDown
                                ? Icons.timer_outlined
                                : Icons.error_outline,
                            color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _isCoolingDown
                              ? 'Too many attempts. Try again in $_cooldownSeconds seconds.'
                              : _error!,
                          style: GoogleFonts.nunito(
                              color: AppColors.danger, fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Email ──────────────────────────────
                  _buildLabel('STUDENT EMAIL'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'you@cvsu.edu.ph',
                      hintStyle: GoogleFonts.nunito(
                          color: AppColors.textLight),
                      prefixIcon: const Icon(Icons.mail_outline,
                          color: AppColors.textLight, size: 20))),
                  const SizedBox(height: 16),

                  // ── Password ───────────────────────────
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passController,
                    obscureText: _obscurePass,
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: GoogleFonts.nunito(
                          color: AppColors.textLight),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textLight, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight, size: 20),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass)))),
                  const SizedBox(height: 10),

                  // ── Forgot password ────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _handleForgotPassword,
                      child: Text('Forgot password?',
                          style: GoogleFonts.nunito(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  ),
                  const SizedBox(height: 8),

                  // ── Sign In button ─────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_loading || _isCoolingDown)
                          ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: AppColors.primary.withOpacity(0.4)),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : _isCoolingDown
                              ? Text('Wait $_cooldownSeconds s...',
                                  style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800))
                              : Text('Sign In',
                                  style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Sign up link ───────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: widget.onGoSignup,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(text: 'Sign Up',
                                style: GoogleFonts.nunito(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800)),
                          ])),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.textMid, letterSpacing: 0.5));
  }
}