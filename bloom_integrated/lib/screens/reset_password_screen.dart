// lib/screens/reset_password_screen.dart
// BLOOM GAD Mobile App — Reset Password Screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ResetPasswordScreen({super.key, required this.onComplete});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool    _obscurePass    = true;
  bool    _obscureConfirm = true;
  bool    _loading        = false;
  bool    _success        = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_loading) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passCtrl.text),
      );

      if (!mounted) return;
      setState(() { _loading = false; _success = true; });

      // Sign out recovery session — force fresh login
      await Future.delayed(const Duration(seconds: 2));
      await Supabase.instance.client.auth.signOut();

      if (mounted) widget.onComplete();

    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      String friendly;
      if (msg.contains('same password') || msg.contains('different')) {
        friendly = 'New password must be different from your current password.';
      } else if (msg.contains('weak') || msg.contains('short')) {
        friendly = 'Password is too weak. Please choose a stronger password.';
      } else if (msg.contains('expired') || msg.contains('invalid')) {
        friendly = 'Reset link has expired. Please request a new one.';
      } else {
        friendly = 'Failed to update password. Please try again.';
      }
      setState(() { _loading = false; _error = friendly; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'An unexpected error occurred. Please try again.'; });
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
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
              child: const Center(
                child: Icon(Icons.lock_reset_rounded, color: Colors.white, size: 36)),
            ),
            const SizedBox(height: 16),
            Text('Reset Password',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Enter your new password below',
                style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: _success ? _buildSuccess() : _buildForm(),
          ),
        ),
      ]),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 48),
        ),
        const SizedBox(height: 24),
        Text('Password Updated!',
            style: GoogleFonts.nunito(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        Text(
          'Your password has been changed successfully.\nRedirecting you to login...',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
              fontSize: 14, color: AppColors.textLight, height: 1.6)),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: AppColors.primary),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Error banner ──────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // ── Info note ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Choose a strong password with at least 8 characters, including uppercase, lowercase, a number, and a special character.',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textMid, height: 1.5))),
              ]),
          ),
          const SizedBox(height: 24),

          // ── New Password ──────────────────────────────────────────
          _buildLabel('NEW PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller:  _passCtrl,
            obscureText: _obscurePass,
            validator:   AppValidators.password,
            onChanged:   (_) => setState(() {}),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
            decoration: _inputDecoration(
              hint:   'Min. 8 chars, uppercase, number, symbol',
              icon:   Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textLight, size: 20),
                onPressed: () => setState(() => _obscurePass = !_obscurePass)),
            ),
          ),
          _buildStrengthBar(_passCtrl.text),
          const SizedBox(height: 16),

          // ── Confirm Password ──────────────────────────────────────
          _buildLabel('CONFIRM NEW PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller:  _confirmCtrl,
            obscureText: _obscureConfirm,
            validator:   (v) => AppValidators.confirmPassword(v, _passCtrl.text),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
            decoration: _inputDecoration(
              hint:   'Re-enter new password',
              icon:   Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textLight, size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
            ),
          ),
          const SizedBox(height: 32),

          // ── Update button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4)),
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Update Password',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText:   hint,
      hintStyle:  GoogleFonts.nunito(color: AppColors.textLight, fontSize: 13),
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
      Row(children: List.generate(5, (i) => Expanded(child: Container(
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

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.textMid, letterSpacing: 0.5));
  }
}