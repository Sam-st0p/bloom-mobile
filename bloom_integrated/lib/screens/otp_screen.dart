// lib/screens/otp_screen.dart
// BLOOM GAD Mobile App — OTP Verification Screen
//
// NOTE: OTP is used for SIGNUP ONLY. Login no longer requires OTP
// (removed to stay within Resend's free email quota at scale).
//
// Signup path (fullName.isNotEmpty):
//   verifyOTP() → applyMasterlistProfile() → onVerified()
//   Role badge is pre-fetched and shown while the user reads their email.
//
// Login path (fullName == ''):
//   verifyOTP() → onVerified()
//   No masterlist query, no role badge, existing profile untouched.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String       email;
  final String       fullName;
  final VoidCallback onVerified;
  final VoidCallback onBack;

  const OtpScreen({
    super.key,
    required this.email,
    required this.fullName,
    required this.onVerified,
    required this.onBack,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with WidgetsBindingObserver {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool    _loading        = false;
  bool    _resending      = false;
  String? _error;
  int     _resendCooldown = 0;
  bool    _canResend      = false;

  // Role badge pre-fetched from masterlist — signup only
  String? _assignedRole;

  // True when this screen is reached from signup, false from login
  bool get _isSignup => widget.fullName.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startResendCooldown(60);
    _otpController.addListener(_onOtpChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestKeyboard();
    });
    // Pre-fetch role badge only during signup — login skips this entirely
    if (_isSignup) _prefetchRole();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_loading) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _requestKeyboard();
      });
    }
  }

  void _requestKeyboard() {
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onOtpChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Pre-fetch role badge (signup only) ───────────────────────────
  // Cosmetic — actual profile write happens in _verify().
  Future<void> _prefetchRole() async {
    final entry = await AuthService.getMasterlistEntry(widget.email);
    if (!mounted) return;
    if (entry != null && entry['role'] != null) {
      final raw = entry['role'].toString();
      setState(() => _assignedRole = raw[0].toUpperCase() + raw.substring(1));
    }
  }

  void _startResendCooldown(int seconds) {
    setState(() { _resendCooldown = seconds; _canResend = false; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) {
        if (mounted) setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  String get _otp => _otpController.text;

  // ── Verify OTP ────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_loading) return;

    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // ── Step 1: verify the OTP with Supabase ──────────────────────────
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otp,
        type:  OtpType.email,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('timeout'),
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = _friendlyError(e.message);
        });
        _otpController.clear();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _requestKeyboard();
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = e.toString().contains('timeout')
              ? 'Request timed out. Check your connection and try again.'
              : 'Verification failed. Please try again.';
        });
      }
      return;
    }

    // ── Step 2: apply masterlist → profiles (signup only) ─────────────
    // Login skips this block entirely — the existing profile is already
    // correct and must not be overwritten.
    if (_isSignup) {
      try {
        final profileError = await AuthService.applyMasterlistProfile(
          email:    widget.email,
          fullName: widget.fullName,
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (profileError != null) {
          setState(() { _error = profileError; _loading = false; });
          return;
        }
      } catch (e) {
        // Non-fatal — AuthGate routes on role; null role → RoleSelectionScreen.
        debugPrint('applyMasterlistProfile non-fatal: $e');
      }
    }

    // ── Step 3: done — AuthGate fires from the auth state change ───────
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onVerified();
  }

  Future<void> _resend() async {
    if (!_canResend || _resending) return;
    setState(() { _resending = true; _error = null; });
    try {
      await Supabase.instance.client.auth.resend(
        type:  OtpType.signup,
        email: widget.email,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Header ──────────────────────────────────────────────────
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
                  child: Icon(Icons.mark_email_read_rounded,
                      color: Colors.white, size: 36)),
            ),
            const SizedBox(height: 16),
            Text('Verify your email',
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('GADRC CvSU',
                style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Enter verification code',
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
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
                const SizedBox(height: 20),

                // ── Role badge (signup only) ─────────────────────────
                if (_isSignup && _assignedRole != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_outlined,
                            color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Role assigned: $_assignedRole',
                          style: GoogleFonts.nunito(
                              color:      Colors.green.shade700,
                              fontSize:   13,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3))),
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

                // ── OTP digit boxes ──────────────────────────────────
                LayoutBuilder(builder: (context, constraints) {
                  final boxSize =
                      ((constraints.maxWidth - 5 * 8.0) / 6)
                          .clamp(40.0, 64.0);
                  final fontSize = (boxSize * 0.5).clamp(20.0, 32.0);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hidden real input
                      SizedBox(
                        width: 1, height: 1,
                        child: TextField(
                          controller:   _otpController,
                          focusNode:    _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength:    6,
                          autofocus:    false,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                              border: InputBorder.none, counterText: ''),
                        ),
                      ),
                      // Visual boxes
                      GestureDetector(
                        onTap: _requestKeyboard,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (i) {
                            final digit    = i < _otp.length ? _otp[i] : '';
                            final isActive =
                                _focusNode.hasFocus && i == _otp.length;
                            return Container(
                              width:  boxSize,
                              height: boxSize * 1.2,
                              margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                              decoration: BoxDecoration(
                                color: digit.isNotEmpty
                                    ? AppColors.primaryDark.withValues(alpha: 0.07)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: digit.isNotEmpty
                                      ? AppColors.primary
                                      : isActive
                                          ? AppColors.primary
                                          : AppColors.border,
                                  width: isActive || digit.isNotEmpty
                                      ? 2.0 : 1.5),
                                boxShadow: isActive ? [BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))] : null,
                              ),
                              child: Center(
                                child: Text(digit,
                                    style: GoogleFonts.nunito(
                                        fontSize:   fontSize,
                                        fontWeight: FontWeight.w900,
                                        color:      AppColors.primaryDark,
                                        height:     1.0)),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 32),

                // ── Verify button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading || _otp.length < 6) ? null : _verify,
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
                        : Text('Verify Code',
                            style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),

                if (_canResend)
                  TextButton(
                    onPressed: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(
                            height: 16, width: 16,
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2))
                        : Text('Resend code',
                            style: GoogleFonts.nunito(
                                color:      AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize:   14)))
                else
                  Text('Resend code in $_resendCooldown seconds',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textLight)),

                const SizedBox(height: 16),

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
                        'Check your inbox and spam folder. '
                        'Once verified you\'ll be taken directly to the Home screen.',
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
      ]),
    );
  }
}