import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🏆 Achievements',
                    style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('1 of 6 badges earned',
                    style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Overall Progress',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            Text('16%',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const AppProgressBar(value: 16),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(value: '1', label: 'Badges'),
                            _StatItem(value: '2', label: 'Certs'),
                            _StatItem(value: '1', label: 'Modules'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Your Badges',
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: sampleBadges.length,
                    itemBuilder: (context, i) {
                      final b = sampleBadges[i];
                      final color = Color(b.colorValue);
                      return Opacity(
                        opacity: b.earned ? 1.0 : 0.55,
                        child: AppCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  color: b.earned ? color.withOpacity(0.15) : AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: b.earned ? color : AppColors.border,
                                    width: b.earned ? 2 : 1.5,
                                    style: b.earned ? BorderStyle.solid : BorderStyle.none,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    b.earned ? b.icon : '🔒',
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(b.name,
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text(b.description,
                                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight, height: 1.4),
                                  textAlign: TextAlign.center),
                              if (b.earned) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                                  child: Text('✓ EARNED',
                                      style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.primary)),
        Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }
}