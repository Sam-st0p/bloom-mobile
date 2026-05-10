// lib/screens/otp_screen.dart
// BLOOM GAD Mobile App — OTP Verification Screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String       email;
  final String       type; // 'signup' or 'login'
  final VoidCallback onVerified;
  final VoidCallback onBack;

  // Only needed for signup
  final String? fullName;
  final String? studentId;

  const OtpScreen({
    super.key,
    required this.email,
    required this.type,
    required this.onVerified,
    required this.onBack,
    this.fullName,
    this.studentId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool    _loading   = false;
  bool    _resending = false;
  String? _error;

  int  _resendCooldown = 0;
  bool _canResend      = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(60);
    for (final f in _focusNodes) {
      f.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  void _startResendCooldown(int seconds) {
    setState(() { _resendCooldown = seconds; _canResend = false; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  // ── Verify OTP ─────────────────────────────────────────
  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otp,
        type:  OtpType.email,
      );

      // Signup — save profile, sign out, show success dialog
      if (widget.type == 'signup' &&
          widget.fullName  != null &&
          widget.studentId != null) {
        await AuthService.signUpCompleteProfile(
          email:     widget.email,
          fullName:  widget.fullName!,
          studentId: widget.studentId!,
        );
        // Sign out temp session so user signs in fresh
        await Supabase.instance.client.auth.signOut(
            scope: SignOutScope.local);

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Account Verified!',
                      style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(
                    'Your account has been created successfully. Sign in to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textLight,
                        height: 1.5)),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onVerified(); // goes to Sign In
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('Go to Sign In',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Login — update last sign in then go to home
      if (widget.type == 'login') {
        await AuthService.updateLastSignIn();
        if (mounted) widget.onVerified();
      }

    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = _friendlyError(e.message);
        });
        for (final c in _controllers) { c.clear(); }
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _focusNodes[0].requestFocus();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = 'Verification failed. Please try again.';
        });
      }
    }
  }

  // ── Resend OTP ─────────────────────────────────────────
  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() { _resending = true; _error = null; });
    try {
      if (widget.type == 'signup') {
        await Supabase.instance.client.auth.resend(
          type:  OtpType.signup,
          email: widget.email,
        );
      } else {
        await Supabase.instance.client.auth.signInWithOtp(
          email: widget.email,
        );
      }
      if (mounted) {
        setState(() => _resending = false);
        _startResendCooldown(60);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('A new code has been sent to ${widget.email}',
              style: GoogleFonts.nunito()),
          backgroundColor: AppColors.primary,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resending = false;
          _error     = 'Failed to resend code. Please try again.';
        });
      }
    }
  }

  String _friendlyError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('expired'))   return 'Code has expired. Please request a new one.';
    if (r.contains('invalid'))   return 'Incorrect code. Please check and try again.';
    if (r.contains('not found')) return 'Code not found. Please request a new one.';
    return 'Incorrect or expired code. Please try again.';
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _focusNodes[index + 1].requestFocus();
        });
      } else {
        _focusNodes[index].unfocus();
        Future.delayed(const Duration(milliseconds: 100), _verify);
      }
    } else if (value.isEmpty && index > 0) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _focusNodes[index - 1].requestFocus();
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Header ─────────────────────────────────────
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
                onTap: widget.onBack,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
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
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1.5)),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'signup'
                  ? 'Verify your email'
                  : 'Two-step verification',
              style: GoogleFonts.nunito(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('GADRC CvSU',
                style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.75), fontSize: 13)),
          ]),
        ),

        // ── Body ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Enter verification code',
                    style: GoogleFonts.nunito(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: AppColors.textLight),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to\n'),
                      TextSpan(
                        text: widget.email,
                        style: GoogleFonts.nunito(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800)),
                    ]),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.type == 'signup'
                      ? 'Verify to complete your registration'
                      : 'Enter the code to sign in',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textLight),
                ),
                const SizedBox(height: 32),

                // ── Error banner ──────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: GoogleFonts.nunito(
                              color: AppColors.danger, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 6 digit boxes ─────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final isFocused = _focusNodes[i].hasFocus;
                    final hasValue  = _controllers[i].text.isNotEmpty;
                    return Container(
                      width: 46, height: 56,
                      margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasValue || isFocused
                              ? AppColors.primary
                              : AppColors.border,
                          width: isFocused ? 2 : 1.5),
                        boxShadow: [
                          if (isFocused)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ]),
                      child: TextField(
                        controller:   _controllers[i],
                        focusNode:    _focusNodes[i],
                        textAlign:    TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength:    1,
                        style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark),
                        decoration: const InputDecoration(
                          counterText:   '',
                          border:        InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly],
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // ── Verify button ─────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading || _otp.length < 6
                        ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4)),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text('Verify Code',
                            style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Resend ────────────────────────────
                if (_canResend)
                  TextButton(
                    onPressed: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2))
                        : Text('Resend code',
                            style: GoogleFonts.nunito(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)))
                else
                  Text('Resend code in $_resendCooldown seconds',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textLight)),
                const SizedBox(height: 16),

                // ── Hint ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        widget.type == 'signup'
                            ? 'Check your inbox and spam folder. Once verified, tap "Go to Sign In" to continue.'
                            : 'Check your inbox and spam folder. The code expires in 10 minutes.',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textMid,
                            height: 1.5))),
                    ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}