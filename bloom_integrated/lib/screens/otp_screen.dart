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
  final String       type;
  final VoidCallback onVerified;
  final VoidCallback onBack;
  final String?      fullName;
  final String?      studentId;

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
  // Single hidden controller — simpler and more reliable
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool    _loading        = false;
  bool    _resending      = false;
  String? _error;
  int     _resendCooldown = 0;
  bool    _canResend      = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(60);
    _otpController.addListener(() { if (mounted) setState(() {}); });
    // Auto-focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
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

  String get _otp => _otpController.text;

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

      if (widget.type == 'signup' &&
          widget.fullName  != null &&
          widget.studentId != null) {
        await AuthService.signUpCompleteProfile(
          email:     widget.email,
          fullName:  widget.fullName!,
          studentId: widget.studentId!,
        );
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Account Verified!',
                      style: GoogleFonts.nunito(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(
                    'Your account has been created successfully. Sign in to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: AppColors.textLight, height: 1.5)),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); widget.onVerified(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
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

      if (widget.type == 'login') {
        await AuthService.updateLastSignIn();
        if (mounted) widget.onVerified();
      }

    } on AuthException catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = _friendlyError(e.message); });
        _otpController.clear();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _loading = false; _error = 'Verification failed. Please try again.'; });
      }
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() { _resending = true; _error = null; });
    try {
      if (widget.type == 'signup') {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup, email: widget.email);
      } else {
        await Supabase.instance.client.auth.signInWithOtp(
          email: widget.email, shouldCreateUser: false);
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
        setState(() { _resending = false; _error = 'Failed to resend code. Please try again.'; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Header ──────────────────────────────────────────────────────
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
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'signup' ? 'Verify your email' : 'Two-step verification',
              style: GoogleFonts.nunito(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('GADRC CvSU',
                style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.75), fontSize: 13)),
          ]),
        ),

        // ── Body ─────────────────────────────────────────────────────────
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
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to\n'),
                      TextSpan(
                        text: widget.email,
                        style: GoogleFonts.nunito(
                            color: AppColors.primary, fontWeight: FontWeight.w800)),
                    ]),
                ),
                const SizedBox(height: 32),

                // ── Error banner ──────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── OTP boxes — responsive to screen width ────────────────
                LayoutBuilder(builder: (context, constraints) {
                  // Calculate box size based on available width
                  // 6 boxes + 5 gaps(8px each) + padding
                  final totalGaps = 5 * 8.0;
                  final boxSize = ((constraints.maxWidth - totalGaps) / 6)
                      .clamp(40.0, 64.0);
                  final fontSize = (boxSize * 0.5).clamp(20.0, 32.0);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hidden real text field for input
                      SizedBox(
                        width: 1,
                        height: 1,
                        child: TextField(
                          controller:   _otpController,
                          focusNode:    _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength:    6,
                          autofocus:    true,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: ''),
                          onChanged: (v) {
                            setState(() {});
                            if (v.length == 6) {
                              Future.delayed(const Duration(milliseconds: 100), _verify);
                            }
                          },
                        ),
                      ),

                      // Visual boxes
                      GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (i) {
                            final digit = i < _otp.length ? _otp[i] : '';
                            final isActive = _focusNode.hasFocus && i == _otp.length;

                            return Container(
                              width:  boxSize,
                              height: boxSize * 1.2,
                              margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                              decoration: BoxDecoration(
                                color: digit.isNotEmpty
                                    ? AppColors.primaryDark.withOpacity(0.07)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: digit.isNotEmpty
                                      ? AppColors.primary
                                      : isActive
                                          ? AppColors.primary
                                          : AppColors.border,
                                  width: isActive || digit.isNotEmpty ? 2.0 : 1.5),
                                boxShadow: isActive ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2)),
                                ] : null,
                              ),
                              child: Center(
                                child: Text(
                                  digit,
                                  style: GoogleFonts.nunito(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                      height: 1.0),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 32),

                // ── Verify button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading || _otp.length < 6 ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
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
                                fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Resend ────────────────────────────────────────────────
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

                // ── Hint ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        widget.type == 'signup'
                            ? 'Check your inbox and spam folder. Once verified, tap "Go to Sign In" to continue.'
                            : 'Check your inbox and spam folder. The code expires in 10 minutes.',
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: AppColors.textMid, height: 1.5))),
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