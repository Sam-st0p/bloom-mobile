import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onGoSignup;

  const LoginScreen({super.key, required this.onLogin, required this.onGoSignup});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // Call Supabase auth via AuthService
    final error = await AuthService.signIn(email, password);

    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        setState(() => _error = error);
      }
      // On success, AuthGate in main.dart detects the session
      // change automatically — no manual navigation needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Center(child: Text('⚧', style: TextStyle(fontSize: 36))),
                ),
                const SizedBox(height: 16),
                Text('GADRC CvSU',
                    style: GoogleFonts.nunito(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Gender & Development Resource Center',
                    style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          ),

          // Form area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back! 👋',
                        style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    Text('Sign in to continue your GAD journey',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textLight)),
                    const SizedBox(height: 28),

                    // Error banner
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: GoogleFonts.nunito(color: AppColors.danger, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildLabel('STUDENT EMAIL'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'you@cvsu.edu.ph',
                        hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                        prefixIcon: const Icon(Icons.mail_outline, color: AppColors.textLight, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('PASSWORD'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passController,
                      obscureText: _obscurePass,
                      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textLight, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textLight, size: 20),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Forgot password?',
                            style: GoogleFonts.nunito(color: AppColors.primaryLight, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                        child: _loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text('Sign In', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: widget.onGoSignup,
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 13),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: 'Sign Up',
                                style: GoogleFonts.nunito(color: AppColors.primary, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMid, letterSpacing: 0.5));
  }
}
