import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final completed = sampleModules.where((m) => m.progress == 100).length;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning,',
                        style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    Text('Ana Maria 👋',
                        style: GoogleFonts.nunito(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    ),
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: Center(child: Text('3', style: GoogleFonts.nunito(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Progress Overview
                  AppCard(
                    child: Column(
                      children: [
                        SectionHeader(title: 'Your Progress', action: 'See all →', onAction: () => onNavigate(1)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatBox(label: 'Modules', value: '$completed/${sampleModules.length}', icon: '📚', color: AppColors.primary),
                            const SizedBox(width: 10),
                            _StatBox(label: 'Badges', value: '1/6', icon: '🏆', color: AppColors.accent),
                            const SizedBox(width: 10),
                            _StatBox(label: 'Seminars', value: '2', icon: '🎓', color: AppColors.info),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppProgressBar(value: ((completed / sampleModules.length) * 100).round()),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('$completed/${sampleModules.length} modules completed',
                              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Seminar Banner
                  GestureDetector(
                    onTap: () => onNavigate(2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE63946), Color(0xFFC1121F)]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(Icons.videocam_outlined, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text('LIVE NOW',
                                        style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('GAD Summit 2025',
                                    style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                Text('142 participants • Tap to join',
                                    style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white60, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Continue Learning
                  SectionHeader(title: 'Continue Learning', action: 'View all', onAction: () => onNavigate(1)),
                  const SizedBox(height: 12),
                  ...sampleModules
                      .where((m) => m.progress > 0 && m.progress < 100)
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: Color(m.colorValue).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(Icons.menu_book_outlined, color: Color(m.colorValue), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.title,
                                            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark),
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        AppProgressBar(value: m.progress, color: Color(m.colorValue)),
                                        const SizedBox(height: 4),
                                        Text('${m.progress}% complete',
                                            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
                                ],
                              ),
                            ),
                          )),
                  const SizedBox(height: 16),

                  // Upcoming Events
                  SectionHeader(title: 'Upcoming Events', action: 'See all', onAction: () => onNavigate(2)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sampleEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final ev = sampleEvents[i];
                        return Container(
                          width: 150,
                          decoration: BoxDecoration(
                            color: Color(ev.colorValue),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                child: Text(ev.date, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                              const SizedBox(height: 10),
                              Text(ev.title,
                                  style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, height: 1.3),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                child: Text(ev.category, style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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

class _StatBox extends StatelessWidget {
  final String label, value, icon;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: color, fontSize: 18)),
            Text(label, style: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}