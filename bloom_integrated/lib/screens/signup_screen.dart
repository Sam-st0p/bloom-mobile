// lib/screens/signup_screen.dart
// BLOOM GAD Mobile App — Signup Screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  int     _step    = 1;
  bool    _loading = false;
  String? _error;
  bool    _showOtp       = false;
  String  _email         = '';
  String  _normalizedName = '';
  String  _normalizedId   = '';

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _idCtrl        = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  String? _selectedDepartment;
  int     _selectedYearLevel = 1;

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

  // ── Step 1 validation ──────────────────────────────────
  String? _validateStep1() {
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();
    final id        = _idCtrl.text.trim();

    if (firstName.isEmpty) return 'Please enter your First Name.';
    if (lastName.isEmpty)  return 'Please enter your Last Name.';
    if (id.isEmpty)        return 'Student ID is required.';
    if (!isValidStudentId(formatStudentId(id))) {
      return 'Invalid student ID format. Example: 2023-12345';
    }
    if (_selectedDepartment == null) {
      return 'Please select your department / course.';
    }
    return null;
  }

  // ── Step 2 validation ──────────────────────────────────
  String? _validateStep2() {
    final emailError = AppValidators.email(_emailCtrl.text);
    if (emailError != null) return emailError;
    final passError = AppValidators.password(_passCtrl.text);
    if (passError != null) return passError;
    if (_confirmCtrl.text.isEmpty) return 'Please confirm your password.';
    if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match.';
    return null;
  }

  // ── Signup handler — creates account then shows OTP ────
  Future<void> _handleSignup() async {
    final validationError = _validateStep2();
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
      email:      email,
      password:   _passCtrl.text,
      fullName:   normalizedName,
      studentId:  normalizedId,
      department: _selectedDepartment!,
      yearLevel:  _selectedYearLevel,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        setState(() => _error = _friendlySignupError(error));
      } else {
        // Account created — show OTP screen
        setState(() {
          _email          = email;
          _normalizedName = normalizedName;
          _normalizedId   = normalizedId;
          _showOtp        = true;
        });
      }
    }
  }

  // ── Friendly error mapper ──────────────────────────────
  String _friendlySignupError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('already registered') || r.contains('already exists')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (r.contains('invalid email')) return 'Please enter a valid email address.';
    if (r.contains('password'))      return 'Password does not meet the requirements.';
    if (r.contains('network') || r.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Sign up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    // Show OTP screen after successful account creation
    if (_showOtp) {
      return OtpScreen(
        email:      _email,
        type:       'signup',
        onVerified: widget.onSignup,
        fullName:   _normalizedName,
        studentId:  _normalizedId,
        department: _selectedDepartment,
        yearLevel:  _selectedYearLevel,
        onBack: () => setState(() {
          _showOtp = false;
          _step    = 2;
        }),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────
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
                      onTap: _step == 2
                          ? () => setState(() { _step = 1; _error = null; })
                          : widget.onGoLogin,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Account',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('Step $_step of 2',
                            style: GoogleFonts.nunito(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 6),
                  Expanded(child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                        color: _step >= 2
                            ? Colors.white
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2)))),
                ]),
              ],
            ),
          ),

          // ── Form ──────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────
  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!,
              style: GoogleFonts.nunito(
                  color: AppColors.danger, fontSize: 13))),
        ]),
      ),
    );
  }

  // ── Step 1 ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Personal Information',
          style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark)),
      const SizedBox(height: 4),
      Text('Tell us about yourself',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 24),
      _errorBanner(),

      _buildLabel('NAME'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _buildTextField(
          ctrl: _firstNameCtrl, hint: 'First name',
          icon: Icons.person_outline)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextField(
          ctrl: _lastNameCtrl, hint: 'Last name',
          icon: Icons.person_outline)),
      ]),
      const SizedBox(height: 16),

      _buildLabel('STUDENT ID'),
      const SizedBox(height: 8),
      _buildTextField(
          ctrl: _idCtrl, hint: '2024-00001',
          icon: Icons.badge_outlined),
      const SizedBox(height: 16),

      _buildLabel('DEPARTMENT / COURSE'),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _selectedDepartment,
        hint: Text('Select Department',
            style: GoogleFonts.nunito(color: AppColors.textLight)),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.school_outlined,
              color: AppColors.textLight, size: 20),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
        items: kDepartments.map((d) => DropdownMenuItem(
            value: d,
            child: Text(d, style: GoogleFonts.nunito(fontSize: 13)))).toList(),
        onChanged: (v) => setState(() => _selectedDepartment = v),
      ),
      const SizedBox(height: 16),

      _buildLabel('YEAR LEVEL'),
      const SizedBox(height: 8),
      Row(children: kYearLevels.map((yr) {
        final selected = _selectedYearLevel == yr;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _selectedYearLevel = yr),
          child: Container(
            margin: EdgeInsets.only(right: yr < kYearLevels.last ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.5)),
            child: Center(child: Text('$yr',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 14,
                    color: selected ? Colors.white : AppColors.textMid))),
          ),
        ));
      }).toList()),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final err = _validateStep1();
            if (err != null) { setState(() => _error = err); return; }
            setState(() { _step = 2; _error = null; });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text('Continue →',
              style: GoogleFonts.nunito(
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
      _buildLoginLink(),
    ]);
  }

  // ── Step 2 ─────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Account Security',
          style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: AppColors.textDark)),
      const SizedBox(height: 4),
      Text('Set up your login credentials',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 24),
      _errorBanner(),

      _buildLabel('STUDENT EMAIL'),
      const SizedBox(height: 8),
      _buildTextField(
          ctrl: _emailCtrl, hint: 'you@cvsu.edu.ph',
          icon: Icons.mail_outline,
          inputType: TextInputType.emailAddress),
      const SizedBox(height: 16),

      _buildLabel('PASSWORD'),
      const SizedBox(height: 8),
      TextField(
        controller: _passCtrl,
        obscureText: _obscurePass,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
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
            onPressed: () => setState(() => _obscurePass = !_obscurePass)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
      _buildPasswordStrengthBar(_passCtrl.text),
      const SizedBox(height: 16),

      _buildLabel('CONFIRM PASSWORD'),
      const SizedBox(height: 8),
      TextField(
        controller: _confirmCtrl,
        obscureText: _obscureConfirm,
        style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'Re-enter password',
          hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
          prefixIcon: const Icon(Icons.lock_outline,
              color: AppColors.textLight, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight, size: 20),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ℹ️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            "By signing up, you agree to CvSU GADRC's Terms of Service and Privacy Policy.",
            style: GoogleFonts.nunito(
                fontSize: 12, color: AppColors.textMid, height: 1.5))),
        ]),
      ),
      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _handleSignup,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _loading
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text('Create Account 🎉',
                  style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => setState(() { _step = 1; _error = null; }),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
          child: Text('← Back',
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textMid)),
        ),
      ),
      _buildLoginLink(),
    ]);
  }

  // ── Password strength bar ──────────────────────────────
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
              : '✓ Strong password',
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
    bool obscure = false,
    TextInputType? inputType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      keyboardType: inputType, onChanged: onChanged,
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
            borderSide: const BorderSide(color: AppColors.primary, width: 2))),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.textMid, letterSpacing: 0.5));
  }

  Widget _buildLoginLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: GestureDetector(
          onTap: widget.onGoLogin,
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.nunito(
                  color: AppColors.textLight, fontSize: 13),
              children: [
                const TextSpan(text: 'Already have an account? '),
                TextSpan(text: 'Sign In',
                    style: GoogleFonts.nunito(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800)),
              ]),
          ),
        ),
      ),
    );
  }
}