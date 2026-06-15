// lib/screens/help_screen.dart
// BLOOM GAD Mobile App — Help & Support Screen

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _expandedIndex;

  static const _faqs = [
    {
      'q': 'How do I reset my password?',
      'a': 'On the login screen, tap "Forgot password?" and enter your registered email address. You will receive a password reset link in your inbox. Click the link and follow the instructions to set a new password.',
    },
    {
      'q': 'Why do I need OTP verification?',
      'a': 'OTP (One-Time Password) adds a second layer of security to your account. After entering your email and password, a 6-digit code is sent to your email. This ensures only you can access your account, even if your password is compromised.',
    },
    {
      'q': 'How do seminar evaluations work?',
      'a': 'After attending a seminar or event, you will receive a prompt to complete an evaluation form. Your feedback helps GADRC improve future programs. Completing evaluations may also unlock badges and certificates.',
    },
    {
      'q': 'How do I change my role?',
      'a': 'Go to Profile → Edit Profile, then scroll to the Role section. Select your new role and tap Save Changes. You will be asked to confirm because role changes affect your seminar registrations and admin records.',
    },
    {
      'q': 'How do I upload a profile picture?',
      'a': 'Go to Profile → Edit Profile. Tap the camera icon on your avatar. Choose an image from your device (JPG, PNG, or WebP, max 2 MB). The photo will upload automatically and appear across the app immediately.',
    },
    {
      'q': 'How do I earn badges and certificates?',
      'a': 'Badges are awarded for completing assessments, modules, and attending seminars. Certificates are issued by GADRC after completing specific programs or events. Check your Profile page to view all earned badges and certificates.',
    },
    {
      'q': 'What is the difference between roles?',
      'a': 'Roles help GADRC categorize participants. Student: currently enrolled at CvSU. Teacher: CvSU teaching staff. Faculty: CvSU faculty members. Speaker: guest speakers or presenters. Guest: visitors or external users. Your role appears in seminar registration records.',
    },
    {
      'q': 'Can I use BLOOM on both mobile and web?',
      'a': 'Yes. BLOOM works on Android, iOS, and web browsers. Your account, progress, and profile sync automatically across all platforms.',
    },
  ];

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'gadrc.admin1@gmail.com',
      query: 'subject=BLOOM App Support',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Header ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft:  Radius.elliptical(200, 60),
              bottomRight: Radius.elliptical(200, 60),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 16, 20, 32),
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.chevron_left_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.help_outline_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            Text('Help & Support',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('BLOOM GADRC · CvSU Indang',
                style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ]),
        ),

        // ── Body ───────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // FAQ section header
                _SectionHeader(
                  icon: Icons.quiz_outlined,
                  label: 'Frequently Asked Questions',
                ),
                const SizedBox(height: 12),

                // FAQ accordion
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: List.generate(_faqs.length, (i) {
                      final faq      = _faqs[i];
                      final expanded = _expandedIndex == i;
                      final isLast   = i == _faqs.length - 1;

                      return Column(children: [
                        InkWell(
                          onTap: () => setState(() =>
                              _expandedIndex = expanded ? null : i),
                          borderRadius: BorderRadius.only(
                            topLeft:  Radius.circular(i == 0 ? 16 : 0),
                            topRight: Radius.circular(i == 0 ? 16 : 0),
                            bottomLeft:  Radius.circular(isLast && !expanded ? 16 : 0),
                            bottomRight: Radius.circular(isLast && !expanded ? 16 : 0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  faq['q']!,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: expanded
                                          ? AppColors.primaryDark
                                          : AppColors.textDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedRotation(
                                turns: expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: expanded
                                      ? AppColors.primaryDark
                                      : AppColors.textLight,
                                  size: 20,
                                ),
                              ),
                            ]),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              faq['a']!,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textMid,
                                  height: 1.6),
                            ),
                          ),
                          crossFadeState: expanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                        if (!isLast)
                          const Divider(height: 1, color: AppColors.border),
                      ]);
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                // Contact section
                _SectionHeader(
                  icon: Icons.mail_outline_rounded,
                  label: 'Contact Support',
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(children: [
                    _ContactRow(
                      icon: Icons.email_outlined,
                      title: 'Email Support',
                      subtitle: 'gadrc.admin1@gmail.com',
                      onTap: _launchEmail,
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _ContactRow(
                      icon: Icons.location_on_outlined,
                      title: 'Office',
                      subtitle: 'GADRC Office, CvSU Indang, Cavite',
                      onTap: null,
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // App info
                Center(
                  child: Column(children: [
                    Text('BLOOM GADRC',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMid)),
                    const SizedBox(height: 2),
                    Text('Cavite State University — Indang',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 2),
                    Text('Version 1.0.0',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textLight)),
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

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppColors.primaryDark),
    const SizedBox(width: 8),
    Text(label,
        style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONTACT ROW
// ─────────────────────────────────────────────────────────────────────────────
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _ContactRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textMid)),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textLight),
      ]),
    ),
  );
}