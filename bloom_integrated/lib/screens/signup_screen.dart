import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onGoLogin;
  final VoidCallback onSignup;

  const SignupScreen({super.key, required this.onGoLogin, required this.onSignup});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 1;
  bool _loading = false;
  String? _error;

  final _nameCtrl       = TextEditingController();
  final _idCtrl         = TextEditingController();
  final _deptCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passCtrl       = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  int _yearLevel        = 1;

  final List<String> _yearLabels = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _idCtrl.dispose(); _deptCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email    = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final error = await AuthService.signUp(
      email:      email,
      password:   password,
      fullName:   _nameCtrl.text.trim(),
      studentId:  _idCtrl.text.trim(),
      department: _deptCtrl.text.trim(),
      yearLevel:  _yearLevel,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        setState(() => _error = error);
      } else {
        widget.onSignup();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Account',
                            style: GoogleFonts.nunito(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('Step $_step of 2',
                            style: GoogleFonts.nunito(
                                color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Container(
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
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32), topRight: Radius.circular(32)),
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
          Expanded(
              child: Text(_error!,
                  style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 13))),
        ]),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Personal Information',
          style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      const SizedBox(height: 4),
      Text('Tell us about yourself',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 24),
      _errorBanner(),
      _buildField('FULL NAME', _nameCtrl, 'Juan Dela Cruz', Icons.person_outline),
      const SizedBox(height: 16),
      _buildField('STUDENT ID', _idCtrl, '2024-00001', Icons.badge_outlined),
      const SizedBox(height: 16),
      _buildField('DEPARTMENT / COURSE', _deptCtrl, 'e.g. BSED, BSCS', Icons.school_outlined),
      const SizedBox(height: 16),
      // Year level picker
      Text('YEAR LEVEL',
          style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textMid, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Row(
        children: List.generate(5, (i) {
          final yr = i + 1;
          final selected = _yearLevel == yr;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _yearLevel = yr),
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 1.5),
                ),
                child: Center(
                  child: Text('$yr',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.textMid,
                          fontSize: 14)),
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.isEmpty ||
                _idCtrl.text.isEmpty ||
                _deptCtrl.text.isEmpty) {
              setState(() => _error = 'Please fill in all fields.');
              return;
            }
            setState(() { _step = 2; _error = null; });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('Continue →',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
      _buildLoginLink(),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Account Security',
          style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      const SizedBox(height: 4),
      Text('Set up your login credentials',
          style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 24),
      _errorBanner(),
      _buildField('STUDENT EMAIL', _emailCtrl, 'you@cvsu.edu.ph', Icons.mail_outline,
          inputType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _buildField('PASSWORD', _passCtrl, 'Min. 8 characters', Icons.lock_outline,
          obscure: true),
      const SizedBox(height: 16),
      _buildField('CONFIRM PASSWORD', _confirmCtrl, 'Re-enter password', Icons.lock_outline,
          obscure: true),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ℹ️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text('Create Account 🎉',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('← Back',
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMid)),
        ),
      ),
      _buildLoginLink(),
    ]);
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, TextInputType? inputType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMid,
              letterSpacing: 0.5)),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: inputType,
        style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
          filled: true,
          fillColor: Colors.white,
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
    ]);
  }

  Widget _buildLoginLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: GestureDetector(
          onTap: widget.onGoLogin,
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 13),
              children: [
                const TextSpan(text: 'Already have an account? '),
                TextSpan(
                    text: 'Sign In',
                    style: GoogleFonts.nunito(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}