// lib/screens/role_selection_screen.dart
// BLOOM GAD Mobile App — Role Selection Screen

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
      'desc': 'CvSU faculty member',
    },
    {
      'value': 'speaker',
      'label': 'Speaker',
      'icon': Icons.mic_none_rounded,
      'desc': 'Guest speaker or presenter',
    },
    {
      'value': 'guest',
      'label': 'Guest',
      'icon': Icons.person_outline_rounded,
      'desc': 'Visitor or external user',
    },
  ];

Future<void> _confirmRole() async {
  if (_selectedRole == null) return;
  setState(() => _loading = true);

  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('No user session');

    // UPDATE not upsert — the profile row already exists from signUpCompleteProfile.
    // Upsert was trying to insert a new row with only id+role+updated_at,
    // which violates the NOT NULL constraint on full_name.
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
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.diversity_3_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Who are you?',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your role to personalize your\nBLOOM experience.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textLight,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Role cards
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
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryDark.withOpacity(0.08)
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
                                    color: AppColors.primaryDark
                                        .withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primaryDark.withOpacity(0.12)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                role['icon'] as IconData,
                                size: 22,
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
                                  Text(
                                    role['label'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? AppColors.primaryDark
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    role['desc'] as String,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryDark,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 14),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _selectedRole == null || _loading ? null : _confirmRole,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    disabledBackgroundColor:
                        AppColors.primaryDark.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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