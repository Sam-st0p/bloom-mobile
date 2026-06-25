// lib/screens/login_screen.dart
// BLOOM GAD Mobile App — Sign In Screen
//
// Constructor API matches _AuthNavigator in main.dart:
//   onLogin      → called after successful email/password sign-in
//                  (AuthGate's onAuthStateChange fires the role check)
//   onGuestLogin → called after Google sign-in succeeds (guest role, straight to app)
//   onGoSignup   → navigate to SignupScreen
//
// @cvsu.edu.ph email is enforced on the client. AuthService.signIn()
// is a thin wrapper around Supabase signInWithPassword.
// OTP is NOT required for login — only for signup email verification.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  /// Called after successful email/password sign-in.
  /// AuthGate's onAuthStateChange handles navigation from here.
  final VoidCallback onLogin;

  /// Called after Google sign-in succeeds. Skips role selection (guest).
  final VoidCallback onGuestLogin;

  /// Navigate to the sign-up screen.
  final VoidCallback onGoSignup;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onGuestLogin,
    required this.onGoSignup,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();

  bool    _obscurePass = true;
  bool    _loading     = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isCvsuEmail =>
      _emailCtrl.text.trim().toLowerCase().endsWith('@cvsu.edu.ph');

  // ── Email / password sign-in ──────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    final error = await AuthService.signIn(
      AppValidators.normalizeEmail(_emailCtrl.text),
      _passCtrl.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() { _error = error; _loading = false; });
      return;
    }

    // Auth state listener in AuthGate takes it from here.
    widget.onLogin();
  }

  // ── Google sign-in → guest role ───────────────────────────────────────────

  Future<void> _handleGoogleLogin() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final error = await AuthService.signInWithGoogle();
      if (!mounted) return;

      if (error != null) {
        if (error != 'Google sign-in cancelled.') {
          setState(() => _error = error);
        }
        return;
      }

      // Auto-assign guest role so AuthGate skips RoleSelectionScreen.
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id':         userId,
          'role':       'guest',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
      }

      widget.onGuestLogin();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Gradient header ────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft:  Radius.elliptical(220, 80),
              bottomRight: Radius.elliptical(220, 80),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
          child: Column(children: [
            // Logo box
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
              child: const Center(
                child: Icon(Icons.eco_rounded, color: Colors.white, size: 36)),
            ),
            const SizedBox(height: 16),
            Text('Welcome to BLOOM',
                style: GoogleFonts.nunito(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('GADRC · Cavite State University',
                style: GoogleFonts.nunito(
                    color:    Colors.white.withValues(alpha: 0.75),
                    fontSize: 13)),
            const SizedBox(height: 12),
            // CvSU-only badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text('Exclusive to CvSU students & staff',
                      style: GoogleFonts.nunito(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
        ),

        // ── Form body ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Google (Guest) button ────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _handleGoogleLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: AppColors.textLight.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color:        Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300)),
                            child: const Center(
                              child: Text('G',
                                  style: TextStyle(
                                      fontSize:   13,
                                      fontWeight: FontWeight.w700,
                                      color:      Color(0xFF4285F4)))),
                          ),
                          const SizedBox(width: 10),
                          Text('Continue with Google',
                              style: GoogleFonts.nunito(
                                  fontSize:   15,
                                  fontWeight: FontWeight.w700,
                                  color:      AppColors.textDark)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:        Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6)),
                            child: Text('Guest',
                                style: GoogleFonts.nunito(
                                    fontSize:   10,
                                    fontWeight: FontWeight.w700,
                                    color:      AppColors.textLight)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Google accounts are granted guest access only',
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: AppColors.textLight),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Divider ──────────────────────────────────────────
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or sign in with CvSU email',
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13))),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),

                  // ── Error banner ─────────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:        AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: GoogleFonts.nunito(
                                    color: AppColors.danger, fontSize: 13))),
                        ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Email ────────────────────────────────────────────
                  _buildLabel('CVSU EMAIL'),
                  const SizedBox(height: 8),
                  _buildFormField(
                    ctrl:      _emailCtrl,
                    hint:      'you@cvsu.edu.ph',
                    icon:      Icons.mail_outline,
                    inputType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final base = AppValidators.email(v);
                      if (base != null) return base;
                      if (!(v ?? '').trim().toLowerCase()
                          .endsWith('@cvsu.edu.ph')) {
                        return 'Only @cvsu.edu.ph emails are accepted here.';
                      }
                      return null;
                    },
                    suffix: _isCvsuEmail
                        ? const Icon(Icons.verified_outlined,
                            color: Colors.green, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Password ─────────────────────────────────────────
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  _buildFormField(
                    ctrl:      _passCtrl,
                    hint:      'Enter your password',
                    icon:      Icons.lock_outline,
                    obscure:   _obscurePass,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required.';
                      return null;
                    },
                    suffix: IconButton(
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textLight, size: 20),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass)),
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 24),

                  // ── Sign in button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4)),
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text('Sign In',
                              style: GoogleFonts.nunito(
                                  fontSize:   16,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Sign up link ──────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: widget.onGoSignup,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                                text: 'Sign Up',
                                style: GoogleFonts.nunito(
                                    color:      AppColors.primary,
                                    fontWeight: FontWeight.w800)),
                          ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Info note ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'BLOOM is exclusively for Cavite State University '
                            'students and staff. You must use your '
                            '@cvsu.edu.ph institutional email to sign in.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color:    AppColors.textMid,
                                height:   1.5))),
                      ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Reusable field builders ───────────────────────────────────────────────

  Widget _buildFormField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool    obscure = false,
    Widget? suffix,
    TextInputType?        inputType,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller:       ctrl,
      obscureText:      obscure,
      keyboardType:     inputType,
      validator:        validator,
      onChanged:        onChanged,
      onFieldSubmitted: onFieldSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  GoogleFonts.nunito(
            color: AppColors.textLight, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        suffixIcon: suffix,
        filled:     true,
        fillColor:  Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger, width: 2)),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: GoogleFonts.nunito(
          fontSize:      12,
          fontWeight:    FontWeight.w700,
          color:         AppColors.textMid,
          letterSpacing: 0.5));
}