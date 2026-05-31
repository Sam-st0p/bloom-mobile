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
  final String       type;      // 'signup' | 'login'
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

// FIX 1: Mix in WidgetsBindingObserver so we receive didChangeAppLifecycleState
// callbacks. Without this the screen is blind to the app being backgrounded
// and resumed, which is exactly what happens when the user switches to Gmail.
class _OtpScreenState extends State<OtpScreen> with WidgetsBindingObserver {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool    _loading        = false;
  bool    _resending      = false;
  String? _error;
  int     _resendCooldown = 0;
  bool    _canResend      = false;

  // signup OTP → OtpType.email
  // login  OTP → OtpType.magiclink
  OtpType get _otpType =>
      widget.type == 'signup' ? OtpType.email : OtpType.magiclink;

  @override
  void initState() {
    super.initState();

    // FIX 2: Register as a WidgetsBinding observer so didChangeAppLifecycleState
    // is called. This is the missing piece — the original code never registered.
    WidgetsBinding.instance.addObserver(this);

    _startResendCooldown(60);
    // Rebuild on text change so boxes update — no auto-submit.
    _otpController.addListener(_onOtpChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestKeyboard();
    });
  }

  // FIX 3: The core lifecycle handler. When the app returns to the foreground
  // (e.g. user comes back from Gmail), AppLifecycleState.resumed fires here.
  // We schedule a keyboard re-request with a short delay to let the Flutter
  // engine fully restore the render tree and IME connection before asking for
  // focus — without the delay, requestFocus() can silently no-op on Android.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_loading) {
      // Small delay lets the platform finish restoring the activity/scene
      // before we interact with the IME. 300 ms is enough on all tested
      // devices (Pixel, Samsung, iPhone) without feeling sluggish.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _requestKeyboard();
      });
    }
  }

  // FIX 4: Centralised keyboard-request helper that performs an unfocus/refocus
  // cycle. Calling requestFocus() alone is not always sufficient after the app
  // is backgrounded because the OS IME can become detached from the FocusNode.
  // The unfocus() call forces Flutter to fully tear down and re-establish the
  // text-input connection, guaranteeing the software keyboard appears.
  void _requestKeyboard() {
    // unfocus first — disposes the current (possibly stale) IME connection
    _focusNode.unfocus();
    // Re-focus on the next frame so the engine has processed the unfocus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onOtpChanged() {
    // Only rebuild the UI — never trigger _verify() automatically.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // FIX 5: Always remove the observer in dispose, otherwise the observer
    // reference leaks and can cause callbacks on a dead state object.
    WidgetsBinding.instance.removeObserver(this);
    _otpController.removeListener(_onOtpChanged);
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
        if (mounted) setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  String get _otp => _otpController.text;

  Future<void> _verify() async {
    // Guard: already loading — ignore duplicate taps.
    if (_loading) return;

    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // ── Step 1: Verify OTP ───────────────────────────────────────────
    // Isolated try/catch — any failure here means no session was created.
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otp,
        type:  _otpType,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('timeout'),
      );
    } on AuthException catch (e) {
      // Wrong/expired code — Supabase did not create a session.
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

    // ── OTP accepted. Session now exists. ────────────────────────────

    // ── Step 2 (signup): write profile row ──────────────────────────
    // Non-fatal. Even if this fails, AuthGate sees role=null
    // and routes to RoleSelectionScreen correctly.
    if (widget.type == 'signup' && widget.fullName != null) {
      try {
        await AuthService.signUpCompleteProfile(
          email:     widget.email,
          fullName:  widget.fullName!,
          studentId: widget.studentId ?? '',
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('signUpCompleteProfile non-fatal: $e');
      }
    }

    // ── Step 3: navigate ─────────────────────────────────────────────
    if (!mounted) return;
    setState(() => _loading = false);

    if (widget.type == 'signup') {
      // AuthGate's onAuthStateChange already fired when verifyOTP
      // completed. It will fetch role=null and route to
      // RoleSelectionScreen automatically. Nothing else needed.
      return;
    }

    // Login: call onVerified so LoginScreen updates its state.
    try { await AuthService.updateLastSignIn(); } catch (_) {}
    if (mounted) widget.onVerified();
  }

  Future<void> _resend() async {
    if (!_canResend || _resending) return;
    setState(() { _resending = true; _error = null; });
    try {
      if (widget.type == 'signup') {
        await Supabase.instance.client.auth.resend(
          type:  OtpType.signup,
          email: widget.email,
        );
      } else {
        await Supabase.instance.client.auth.signInWithOtp(
          email:            widget.email,
          shouldCreateUser: false,
          emailRedirectTo:  null,
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
                  child: Icon(Icons.lock_rounded,
                      color: Colors.white, size: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'signup'
                  ? 'Verify your email'
                  : 'Two-step verification',
              style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('GADRC CvSU',
                style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.75), fontSize: 13)),
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
                const SizedBox(height: 32),

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

                // ── OTP digit boxes ──────────────────────────────────
                LayoutBuilder(builder: (context, constraints) {
                  final boxSize =
                      ((constraints.maxWidth - 5 * 8.0) / 6)
                          .clamp(40.0, 64.0);
                  final fontSize = (boxSize * 0.5).clamp(20.0, 32.0);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hidden real input — no onChanged auto-submit.
                      // FIX 6: Remove autofocus:true from the TextField.
                      // autofocus only fires on the widget's first insertion
                      // into the tree; it does NOT re-fire on app resume.
                      // Focus is now managed entirely via _requestKeyboard().
                      SizedBox(
                        width: 1, height: 1,
                        child: TextField(
                          controller:   _otpController,
                          focusNode:    _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength:    6,
                          autofocus:    false, // managed by _requestKeyboard()
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                              border: InputBorder.none, counterText: ''),
                          // onChanged intentionally omitted —
                          // listener in initState handles UI rebuild only.
                        ),
                      ),
                      // Visual boxes — tap anywhere to restore keyboard
                      // FIX 7: Use _requestKeyboard() in the tap handler
                      // instead of bare requestFocus(), so the unfocus/refocus
                      // cycle runs even when the focus node already thinks it
                      // has focus (which happens after the app is resumed).
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
                                    ? AppColors.primaryDark.withOpacity(0.07)
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
                                    color: AppColors.primary.withOpacity(0.2),
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

                // ── Verify button — ONLY trigger point ──────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // Disabled while loading OR fewer than 6 digits typed.
                    onPressed: (_loading || _otp.length < 6) ? null : _verify,
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
                            ? 'Check your inbox and spam folder. Once verified you\'ll be taken to select your role.'
                            : 'Check your inbox and spam folder. The code expires in 10 minutes.',
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