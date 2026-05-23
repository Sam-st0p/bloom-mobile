// lib/screens/signup_screen.dart
// BLOOM GAD Mobile App — Signup Screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  // Called when signUp() succeeds — passes email + fullName to parent
  // so it can show OtpScreen inline without a Navigator push.
  final void Function({required String email, required String fullName})
      onNeedsOtp;

  const SignupScreen({
    super.key,
    required this.onGoLogin,
    required this.onNeedsOtp,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey      = GlobalKey<FormState>();
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

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final fullName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

    try {
      final error = await AuthService.signUp(
        email:     _emailCtrl.text.trim(),
        password:  _passCtrl.text,
        fullName:  fullName,
        studentId: '',
      );

      if (!mounted) return;

      if (error != null) {
        setState(() { _error = error; _loading = false; });
        return;
      }

      // signUp() succeeded — OTP sent.
      // Tell parent to show OtpScreen inline (no Navigator.push).
      widget.onNeedsOtp(
        email:    _emailCtrl.text.trim(),
        fullName: fullName,
      );

    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error   = 'Signup failed. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _handleGoogleSignup() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() =>
          _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                GestureDetector(
                  onTap: widget.onGoLogin,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                      Text('Back to Login',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text('Create Account',
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 6),
                Text('Join BLOOM — GADRC CvSU',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textLight)),

                const SizedBox(height: 32),

                // Error banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!,
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.danger))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // First + Last name row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildField(
                      controller: _firstNameCtrl,
                      label: 'First Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField(
                      controller: _lastNameCtrl,
                      label: 'Last Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.email,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _passCtrl,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textLight, size: 20),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: AppValidators.password,
                ),
                const SizedBox(height: 16),

                _buildField(
                  controller: _confirmCtrl,
                  label: 'Confirm Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textLight, size: 20),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password.';
                    }
                    if (v != _passCtrl.text) return 'Passwords do not match.';
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      disabledBackgroundColor:
                          AppColors.primaryDark.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Create Account',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 20),

                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textLight)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _handleGoogleSignup,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 20, height: 20,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.g_mobiledata_rounded,
                          size: 22, color: AppColors.textMid),
                    ),
                    label: Text('Continue with Google',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Center(
                  child: GestureDetector(
                    onTap: widget.onGoLogin,
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textLight),
                        children: [
                          TextSpan(
                            text: 'Log In',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600)),
                        ]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller:  controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator:   validator,
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
            suffixIcon: suffixIcon,
            filled:     true,
            fillColor:  Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primaryDark, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.danger)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.danger, width: 1.5)),
          ),
        ),
      ],
    );
  }
}