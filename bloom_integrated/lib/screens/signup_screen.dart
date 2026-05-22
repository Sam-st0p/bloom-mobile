// lib/screens/signup_screen.dart
// BLOOM GAD Mobile App – Signup Screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/input_formatters.dart';
import '../utils/validators.dart';
import 'otp_screen.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  final VoidCallback onSignup;

  const SignupScreen({
    super.key,
    required this.onGoLogin,
    required this.onSignup,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool    _loading        = false;
  String? _error;
  bool    _showOtp        = false;
  String  _email          = '';
  String  _normalizedName = '';
  String  _normalizedId   = '';

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _idCtrl        = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _idCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────
  String? _validate() {
    if (_firstNameCtrl.text.trim().isEmpty) return 'Please enter your First Name.';
    if (_lastNameCtrl.text.trim().isEmpty)  return 'Please enter your Last Name.';
    if (_idCtrl.text.trim().isEmpty)        return 'Student ID is required.';
    if (!isValidStudentId(formatStudentId(_idCtrl.text))) {
      return 'Invalid student ID format. Example: 2023-12345';
    }
    final emailError = AppValidators.email(_emailCtrl.text);
    if (emailError != null) return emailError;
    final passError = AppValidators.password(_passCtrl.text);
    if (passError != null) return passError;
    if (_confirmCtrl.text.isEmpty)           return 'Please confirm your password.';
    if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match.';
    return null;
  }

  // ── Signup handler ─────────────────────────────────────────────
  Future<void> _handleSignup() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() { _loading = true; _error = null; });

    final normalizedName = formatFullName(
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}');
    final normalizedId = formatStudentId(_idCtrl.text);
    final email        = AppValidators.sanitize(_emailCtrl.text).toLowerCase();

    final error = await AuthService.signUp(
      email:     email,
      password:  _passCtrl.text,
      fullName:  normalizedName,
      studentId: normalizedId,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        setState(() => _error = _friendlyError(error));
      } else {
        setState(() {
          _email          = email;
          _normalizedName = normalizedName;
          _normalizedId   = normalizedId;
          _showOtp        = true;
        });
      }
    }
  }

  // ── Google Sign-In handler ─────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final error = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (error == null) {
        widget.onSignup();
      } else if (error != 'Google sign-in cancelled.') {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('already registered') || r.contains('already exists')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (r.contains('invalid email'))  return 'Please enter a valid email address.';
    if (r.contains('password'))       return 'Password does not meet the requirements.';
    if (r.contains('network') || r.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Sign up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (_showOtp) {
      return OtpScreen(
        email:      _email,
        type:       'signup',
        onVerified: widget.onGoLogin,
        fullName:   _normalizedName,
        studentId:  _normalizedId,
        onBack: () => setState(() => _showOtp = false),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, Color(0xFF1B6B4A)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onGoLogin,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('Create Account',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),

          // ── Form ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal Information',
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Fill in your details to create an account',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textLight)),
                  const SizedBox(height: 24),

                  // ── Google Sign-Up button ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: AppColors.textLight.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.grey.shade300),
                            ),
                            child: const Center(
                              child: Text('G',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('Continue with Google',
                              style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── OR divider ─────────────────────────────────
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or sign up with email',
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13)),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),

                  // ── Error banner ───────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                            style: GoogleFonts.nunito(
                                color: AppColors.danger, fontSize: 13))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Name ───────────────────────────────────────
                  _buildLabel('NAME'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _buildTextField(
                        ctrl: _firstNameCtrl,
                        hint: 'First name',
                        icon: Icons.person_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(
                        ctrl: _lastNameCtrl,
                        hint: 'Last name',
                        icon: Icons.person_outline)),
                  ]),
                  const SizedBox(height: 16),

                  // ── Student ID ─────────────────────────────────
                  _buildLabel('STUDENT ID'),
                  const SizedBox(height: 8),
                  _buildTextField(
                      ctrl: _idCtrl,
                      hint: '2024-00001',
                      icon: Icons.badge_outlined),
                  const SizedBox(height: 16),

                  // ── Email ──────────────────────────────────────
                  _buildLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  _buildTextField(
                      ctrl: _emailCtrl,
                      hint: 'you@gmail.com',
                      icon: Icons.mail_outline,
                      inputType: TextInputType.emailAddress),
                  const SizedBox(height: 16),

                  // ── Password ───────────────────────────────────
                  _buildLabel('PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePass,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Min. 8 characters, 1 uppercase, 1 number',
                      hintStyle: GoogleFonts.nunito(
                          color: AppColors.textLight, fontSize: 12),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textLight, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight, size: 20),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass)),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                    ),
                  ),
                  _buildPasswordStrengthBar(_passCtrl.text),
                  const SizedBox(height: 16),

                  // ── Confirm Password ───────────────────────────
                  _buildLabel('CONFIRM PASSWORD'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Re-enter password',
                      hintStyle:
                          GoogleFonts.nunito(color: AppColors.textLight),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textLight, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight, size: 20),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm)),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Info note ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                            'A verification code will be sent to your email after signing up.',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textMid,
                                height: 1.5))),
                        ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Create Account button ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _handleSignup,
                      icon: _loading
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 20, color: Colors.white),
                      label: _loading
                          ? const SizedBox.shrink()
                          : Text('Create Account',
                              style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Sign in link ───────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: widget.onGoLogin,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13),
                          children: [
                            const TextSpan(
                                text: 'Already have an account? '),
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
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthBar(String password) {
    if (password.isEmpty) return const SizedBox(height: 6);
    final score  = AppValidators.passwordStrength(password);
    final colors = [
      Colors.transparent, Colors.red, Colors.orange,
      Colors.lightGreen, Colors.green,
    ];
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: List.generate(4, (i) => Expanded(child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
          decoration: BoxDecoration(
            color: i < score ? colors[score] : AppColors.border,
            borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(score > 0 ? labels[score] : '',
            style: GoogleFonts.nunito(
                fontSize: 11,
                color: score > 0 ? colors[score] : Colors.transparent,
                fontWeight: FontWeight.w700)),
        Text(
          score < 4
              ? 'Add uppercase & numbers for stronger password'
              : 'Strong password',
          style: GoogleFonts.nunito(
              fontSize: 10,
              color: score == 4 ? Colors.green : AppColors.textLight)),
      ]),
    ]);
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType? inputType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2))),
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