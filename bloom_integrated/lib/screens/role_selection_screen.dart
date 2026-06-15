// lib/screens/role_selection_screen.dart
// Shown only after a successful @cvsu.edu.ph email login.
// Google users are auto-assigned 'guest' and never see this screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  final VoidCallback onRoleSelected;
  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _loading = false;

  // Guest and Speaker removed — those come in via Google or invite only.
  // Only institutional CvSU roles are listed here.
  static const _roles = [
    {
      'value': 'student',
      'label': 'Student',
      'icon': Icons.school_outlined,
      'desc': 'Currently enrolled at CvSU',
    },
    {
      'value': 'teacher',
      'label': 'Teacher',
      'icon': Icons.menu_book_outlined,
      'desc': 'CvSU teaching staff',
    },
    {
      'value': 'faculty',
      'label': 'Faculty',
      'icon': Icons.account_balance_outlined,
      'desc': 'CvSU faculty / administrative staff',
    },
  ];

  Future<void> _confirmRole() async {
    if (_selectedRole == null) return;
    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No user session');

      await Supabase.instance.client
          .from('profiles')
          .update({
            'role':       _selectedRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      widget.onRoleSelected();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save role: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.diversity_3_outlined,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text('Who are you?',
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Text(
                      'Select your CvSU role to personalize\nyour BLOOM experience.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textLight,
                          height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    // Remind them why they're here
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_outlined,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text('Signed in with CvSU email',
                              style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Role cards ───────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final role = _roles[i];
                    final selected = _selectedRole == role['value'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedRole = role['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryDark.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryDark
                                : AppColors.border,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primaryDark.withValues(alpha: 0.12)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                role['icon'] as IconData,
                                size: 24,
                                color: selected
                                    ? AppColors.primaryDark
                                    : AppColors.textLight,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(role['label'] as String,
                                      style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? AppColors.primaryDark
                                              : AppColors.textDark)),
                                  Text(role['desc'] as String,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            if (selected)
                              Container(
                                width: 24, height: 24,
                                decoration: const BoxDecoration(
                                    color: AppColors.primaryDark,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 15),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── Confirm button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _selectedRole == null || _loading ? null : _confirmRole,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    disabledBackgroundColor:
                        AppColors.primaryDark.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Continue',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'You can change this later in your profile.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}