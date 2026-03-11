import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _supabase = Supabase.instance.client;

  List<BadgeModel> _badges = [];
  int _earnedCount = 0;
  int _certCount = 0;
  int _completedModules = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;

      // All badges
      final allBadges = await _supabase.from('badges').select('*');

      // Earned badge ids
      Set<String> earnedIds = {};
      int certCount = 0;
      int completedModules = 0;

      if (userId != null) {
        final earned = await _supabase
            .from('student_badges')
            .select('badge_id')
            .eq('user_id', userId);
        earnedIds =
            (earned as List).map((e) => e['badge_id'].toString()).toSet();

        final certs = await _supabase
            .from('certificates')
            .select('id')
            .eq('user_id', userId)
            .eq('is_revoked', false);
        certCount = (certs as List).length;

        final progress = await _supabase
            .from('module_progress')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'completed');
        completedModules = (progress as List).length;
      }

      if (mounted) {
        setState(() {
          _badges = (allBadges as List).map((b) {
            final map = b as Map<String, dynamic>;
            return BadgeModel.fromMap(map,
                earned: earnedIds.contains(map['id']?.toString()));
          }).toList();
          _earnedCount = earnedIds.length;
          _certCount = certCount;
          _completedModules = completedModules;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _badges.isEmpty ? 0 : ((_earnedCount / _badges.length) * 100).round();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────
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
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                      _loading
                          ? 'Loading...'
                          : '$_earnedCount of ${_badges.length} badges earned',
                      style: GoogleFonts.nunito(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13)),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _loading
                    ? const Center(
                        child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ))
                    : Column(
                        children: [
                          // ── Stats card ──────────────────────────
                          AppCard(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Overall Progress',
                                        style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textDark)),
                                    Text('$progress%',
                                        style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                AppProgressBar(value: progress),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _StatItem(
                                        value: '$_earnedCount',
                                        label: 'Badges'),
                                    _StatItem(
                                        value: '$_certCount',
                                        label: 'Certs'),
                                    _StatItem(
                                        value: '$_completedModules',
                                        label: 'Modules'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Badge grid ──────────────────────────
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Your Badges',
                                style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark)),
                          ),
                          const SizedBox(height: 12),

                          if (_badges.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('No badges configured yet',
                                    style: GoogleFonts.nunito(
                                        color: AppColors.textLight,
                                        fontSize: 14)),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.9,
                              ),
                              itemCount: _badges.length,
                              itemBuilder: (context, i) {
                                final b = _badges[i];
                                final color = Color(b.colorValue);
                                return Opacity(
                                  opacity: b.earned ? 1.0 : 0.55,
                                  child: AppCard(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: b.earned
                                                ? color.withOpacity(0.15)
                                                : AppColors.background,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: b.earned
                                                ? Border.all(
                                                    color: color, width: 2)
                                                : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              b.earned ? b.icon : '🔒',
                                              style: const TextStyle(
                                                  fontSize: 32),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(b.name,
                                            style: GoogleFonts.nunito(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: AppColors.textDark),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 4),
                                        Text(b.description,
                                            style: GoogleFonts.nunito(
                                                fontSize: 11,
                                                color: AppColors.textLight,
                                                height: 1.4),
                                            textAlign: TextAlign.center),
                                        if (b.earned) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            child: Text('✓ EARNED',
                                                style: GoogleFonts.nunito(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w800)),
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
        Text(value,
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: AppColors.primary)),
        Text(label,
            style:
                GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }
}