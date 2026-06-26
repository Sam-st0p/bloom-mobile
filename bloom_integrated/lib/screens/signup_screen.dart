// lib/screens/signup_screen.dart
// BLOOM GAD Mobile App — Signup Screen
//
// Flow:
//   1. User enters @cvsu.edu.ph email + password + name
//   2. App queries masterlist — if NOT found, block with error
//   3. If found, proceed with Supabase signUp → OTP sent
//   4. Navigate to OTP screen, passing masterlist data
//   5. OTP screen writes full profile from masterlist (role auto-assigned)
//   No role selection screen needed.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  final void Function({
    required String email,
    required String fullName,
    required String role,
    required String? studentId,
    required String? department,
    required String? course,
    required int?    yearLevel,
  }) onNeedsOtp;
  final VoidCallback? onGuestSignup;

  const SignupScreen({
    super.key,
    required this.onGoLogin,
    required this.onNeedsOtp,
    this.onGuestSignup,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  bool    _loading        = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _isCvsuEmail =>
      _emailCtrl.text.trim().toLowerCase().endsWith('@cvsu.edu.ph');

  // ── Check masterlist ───────────────────────────────────────────────────────
  // Returns the masterlist row if found, null if not.
  Future<Map<String, dynamic>?> _checkMasterlist(String email) async {
    try {
      final result = await Supabase.instance.client
          .from('masterlist')
          .select('cvsu_email, role, full_name, student_id, department, course, year_level')
          .eq('cvsu_email', email.toLowerCase().trim())
          .eq('is_active', true)
          .maybeSingle();
      return result;
    } catch (_) {
      return null;
    }
  }

  // ── Email/password signup ──────────────────────────────────────────────────
  Future<void> _handleSignup() async {
    if (_loading) return;
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    if (!_isCvsuEmail) {
      setState(() => _error =
          'Only @cvsu.edu.ph institutional emails can create an account here.\n'
          'Use "Continue with Google" for other accounts.');
      return;
    }

    setState(() => _loading = true);

    final cleanEmail = AppValidators.normalizeEmail(_emailCtrl.text);

    // ── Step 1: Check masterlist ──────────────────────────────────────────
    final masterRow = await _checkMasterlist(cleanEmail);

    if (!mounted) return;

    if (masterRow == null) {
      setState(() {
        _error =
            'Your email is not in the CvSU enrollment records.\n\n'
            'Only currently enrolled students and faculty members '
            'can register. Please contact your administrator if you '
            'believe this is an error.';
        _loading = false;
      });
      return;
    }

    // ── Step 2: Proceed with signup ───────────────────────────────────────
    final fullName = masterRow['full_name'] as String? ??
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

    final error = await AuthService.signUp(
      email:     cleanEmail,
      password:  _passCtrl.text,
      fullName:  fullName,
      studentId: masterRow['student_id'] as String? ?? '',
    );

    if (!mounted) return;

    if (error != null) {
      setState(() { _error = error; _loading = false; });
      return;
    }

    // ── Step 3: Pass masterlist data to OTP screen ────────────────────────
    widget.onNeedsOtp(
      email:      cleanEmail,
      fullName:   fullName,
      role:       masterRow['role']       as String,
      studentId:  masterRow['student_id'] as String?,
      department: masterRow['department'] as String?,
      course:     masterRow['course']     as String?,
      yearLevel:  masterRow['year_level'] as int?,
    );
  }

  // ── Google signup → guest ──────────────────────────────────────────────────
  Future<void> _handleGoogleSignup() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final error = await AuthService.signInWithGoogle();
      if (!mounted) return;

      if (error != null) {
        if (error != 'Google sign-in cancelled.') setState(() => _error = error);
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id':         userId,
          'role':       'guest',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
      }

      (widget.onGuestSignup ?? widget.onGoLogin)();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Header ────────────────────────────────────────────────────
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
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: widget.onGoLogin,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 22)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
              child: const Center(
                child: Icon(Icons.diversity_3_rounded,
                    color: Colors.white, size: 36)),
            ),
            const SizedBox(height: 16),
            Text('Create Account',
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Join the GADRC CvSU community',
                style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13)),
          ]),
        ),

        // ── Form ──────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Google (Guest) button ──────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _handleGoogleSignup,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300)),
                            child: const Center(
                              child: Text('G',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4)))),
                          ),
                          const SizedBox(width: 10),
                          Text('Continue with Google',
                              style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6)),
                            child: Text('Guest',
                                style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textLight)),
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

                  // ── Divider ────────────────────────────────────────
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or sign up with CvSU email',
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13))),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),

                  // ── Error banner ───────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
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
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    height: 1.5)),
                          ),
                        ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Masterlist notice ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            color: AppColors.info, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only currently enrolled CvSU students and '
                            'faculty members can register. Your email must '
                            'be in the official enrollment masterlist.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Full name (display only — real name from masterlist) ──
                  _buildLabel('FULL NAME'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildFormField(
                        ctrl:      _firstNameCtrl,
                        hint:      'First name',
                        icon:      Icons.person_outline,
                        validator: (v) => AppValidators.name(v, field: 'First name'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _buildFormField(
                        ctrl:      _lastNameCtrl,
                        hint:      'Last name',
                        icon:      Icons.person_outline,
                        validator: (v) => AppValidators.name(v, field: 'Last name'),
                      )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your official name will be used from the masterlist.',
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 16),

                  // ── CvSU email ─────────────────────────────────────
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

                  // ── Password ───────────────────────────────────────
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  _buildFormField(
                    ctrl:      _passCtrl,
                    hint:      'Min. 8 chars, uppercase, number, symbol',
                    icon:      Icons.lock_outline,
                    obscure:   _obscurePass,
                    validator: AppValidators.password,
                    onChanged: (_) => setState(() {}),
                    suffix: IconButton(
                      icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textLight, size: 20),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass)),
                  ),
                  _buildStrengthBar(_passCtrl.text),
                  const SizedBox(height: 16),

                  // ── Confirm password ───────────────────────────────
                  _buildLabel('CONFIRM PASSWORD'),
                  const SizedBox(height: 8),
                  _buildFormField(
                    ctrl:      _confirmCtrl,
                    hint:      'Re-enter password',
                    icon:      Icons.lock_outline,
                    obscure:   _obscureConfirm,
                    validator: (v) =>
                        AppValidators.confirmPassword(v, _passCtrl.text),
                    suffix: IconButton(
                      icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textLight, size: 20),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm)),
                  ),
                  const SizedBox(height: 20),

                  // ── Info note ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A 6-digit verification code will be sent to your '
                            '@cvsu.edu.ph email. Your role will be '
                            'automatically assigned based on your enrollment records.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textMid,
                                height: 1.5))),
                      ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Create Account button ──────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleSignup,
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
                          : Text('Create Account',
                              style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Sign in link ───────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: widget.onGoLogin,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                                text: 'Sign In',
                                style: GoogleFonts.nunito(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800)),
                          ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildStrengthBar(String password) {
    if (password.isEmpty) return const SizedBox(height: 6);
    final score  = AppValidators.passwordStrength(password);
    final colors = [
      Colors.transparent, Colors.red, Colors.red,
      Colors.orange, Colors.lightGreen, Colors.green,
    ];
    final labels = ['', 'Very Weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final color  = score < colors.length ? colors[score] : Colors.green;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: List.generate(5, (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
            decoration: BoxDecoration(
              color: i < score ? color : AppColors.border,
              borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(height: 4),
      Text(score > 0 ? labels[score] : '',
          style: GoogleFonts.nunito(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildFormField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
    TextInputType? inputType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller:       ctrl,
      obscureText:      obscure,
      keyboardType:     inputType,
      validator:        validator,
      onChanged:        onChanged,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
      autovalidateMode: AutovalidateMode.onUserInteraction,
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

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMid,
            letterSpacing: 0.5));
  }
}