import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import '../services/activity_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback onBellTap;
  final int unreadCount;
  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onBellTap,
    required this.unreadCount,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;

  String _firstName = 'Student';
  int _completedModules = 0;
  int _totalModules = 0;
  int _badgeCount = 0;
  int _seminarCount = 0;
  List<ModuleModel> _inProgressModules = [];
  List<EventModel> _upcomingEvents = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
    ActivityService.log(activityType: 'screen_view', referenceType: 'home');
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final modulesData = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published');

      final progressData = await _supabase
          .from('module_progress')
          .select('module_id, progress_percent, status')
          .eq('user_id', userId);

      final progressMap = <String, Map<String, dynamic>>{};
      for (final p in progressData as List) {
        progressMap[p['module_id']] = p;
      }

      final allModules = (modulesData as List).map((m) {
        final prog = progressMap[m['id']];
        final pct = (prog?['progress_percent'] as num?)?.toInt() ?? 0;
        return ModuleModel.fromMap(m, progress: pct);
      }).toList();

      final badgesData = await _supabase
          .from('student_badges')
          .select('id')
          .eq('user_id', userId);

      final seminarData = await _supabase
          .from('seminar_registrations')
          .select('id')
          .eq('user_id', userId);

      final eventsData = await _supabase
          .from('events')
          .select('*')
          .gte('start_date', DateTime.now().toIso8601String().substring(0, 10))
          .order('start_date')
          .limit(5);

      final announcementsData = await _supabase
          .from('announcements')
          .select('id, title, body, is_pinned, published_at')
          .lte('published_at', DateTime.now().toIso8601String())
          .order('is_pinned', ascending: false)
          .order('published_at', ascending: false)
          .limit(3);

      if (mounted) {
        setState(() {
          final fullName = profile?['full_name'] as String? ?? 'Student';
          _firstName = fullName.split(' ').first;
          _totalModules = allModules.length;
          _completedModules = allModules.where((m) => m.progress == 100).length;
          _inProgressModules =
              allModules.where((m) => m.progress > 0 && m.progress < 100).toList();
          _badgeCount = (badgesData as List).length;
          _seminarCount = (seminarData as List).length;
          _upcomingEvents = (eventsData as List)
              .map((e) => EventModel.fromMap(e as Map<String, dynamic>))
              .toList();
          _announcements = List<Map<String, dynamic>>.from(announcementsData);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
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
                      Text(_greeting(),
                          style: GoogleFonts.nunito(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13)),
                      Text('$_firstName 👋',
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                  // Bell button — plain ElevatedButton, most reliable
                  ElevatedButton(
                    onPressed: widget.onBellTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.all(10),
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 22),
                        if (widget.unreadCount > 0)
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text('${widget.unreadCount}',
                                    style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -44),
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
                          // Progress overview card
                          AppCard(
                            child: Column(
                              children: [
                                SectionHeader(
                                    title: 'Your Progress',
                                    action: 'See all →',
                                    onAction: () => widget.onNavigate(1)),
                                const SizedBox(height: 16),
                                Row(children: [
                                  _StatBox(
                                      label: 'Modules',
                                      value: '$_completedModules/$_totalModules',
                                      icon: '📚',
                                      color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  _StatBox(
                                      label: 'Badges',
                                      value: '$_badgeCount',
                                      icon: '🏆',
                                      color: AppColors.accent),
                                  const SizedBox(width: 10),
                                  _StatBox(
                                      label: 'Seminars',
                                      value: '$_seminarCount',
                                      icon: '🎓',
                                      color: AppColors.info),
                                ]),
                                const SizedBox(height: 14),
                                AppProgressBar(
                                    value: _totalModules > 0
                                        ? ((_completedModules / _totalModules) * 100).round()
                                        : 0),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                      '$_completedModules/$_totalModules modules completed',
                                      style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          color: AppColors.textLight)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Announcements
                          if (_announcements.isNotEmpty) ...[
                            SectionHeader(
                                title: 'Announcements',
                                action: 'See all',
                                onAction: widget.onBellTap),
                            const SizedBox(height: 10),
                            ..._announcements.map((a) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: a['is_pinned'] == true
                                        ? AppColors.primary.withOpacity(0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: a['is_pinned'] == true
                                            ? AppColors.primary.withOpacity(0.3)
                                            : AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (a['is_pinned'] == true)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8, top: 2),
                                          child: Icon(Icons.push_pin,
                                              size: 14, color: AppColors.primary),
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(a['title'] ?? '',
                                                style: GoogleFonts.nunito(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                    color: AppColors.textDark)),
                                            const SizedBox(height: 4),
                                            Text(a['body'] ?? a['content'] ?? a['content'] ?? a['content'] ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.nunito(
                                                    fontSize: 12,
                                                    color: AppColors.textLight)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 8),
                          ],

                          // Continue learning
                          if (_inProgressModules.isNotEmpty) ...[
                            SectionHeader(
                                title: 'Continue Learning',
                                action: 'View all',
                                onAction: () => widget.onNavigate(1)),
                            const SizedBox(height: 12),
                            ..._inProgressModules.map((m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      ActivityService.log(
                                        activityType: 'module_opened',
                                        referenceId: m.id,
                                        referenceType: 'module',
                                        metadata: {'title': m.title},
                                      );
                                      widget.onNavigate(1);
                                    },
                                    child: AppCard(
                                      child: Row(children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.menu_book_outlined,
                                              color: AppColors.primary, size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(m.title,
                                                  style: GoogleFonts.nunito(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13,
                                                      color: AppColors.textDark),
                                                  overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 6),
                                              AppProgressBar(
                                                  value: m.progress,
                                                  color: AppColors.primary),
                                              const SizedBox(height: 4),
                                              Text('${m.progress}% complete',
                                                  style: GoogleFonts.nunito(
                                                      fontSize: 11,
                                                      color: AppColors.textLight)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right,
                                            color: AppColors.textLight, size: 18),
                                      ]),
                                    ),
                                  ),
                                )),
                            const SizedBox(height: 16),
                          ],

                          // Upcoming events
                          if (_upcomingEvents.isNotEmpty) ...[
                            SectionHeader(
                                title: 'Upcoming Events',
                                action: 'See all',
                                onAction: () => widget.onNavigate(2)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 130,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _upcomingEvents.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, i) {
                                  final ev = _upcomingEvents[i];
                                  final color = Color(ev.colorValue);
                                  return Container(
                                    width: 150,
                                    decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(18)),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          child: Text(ev.date,
                                              style: GoogleFonts.nunito(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12)),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(ev.title,
                                            style: GoogleFonts.nunito(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                height: 1.3),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          child: Text(ev.category,
                                              style: GoogleFonts.nunito(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Empty state
                          if (_upcomingEvents.isEmpty &&
                              _inProgressModules.isEmpty &&
                              _announcements.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Column(children: [
                                const Icon(Icons.explore_outlined,
                                    size: 48, color: AppColors.textLight),
                                const SizedBox(height: 12),
                                Text('Start exploring modules!',
                                    style: GoogleFonts.nunito(
                                        color: AppColors.textLight, fontSize: 14)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => widget.onNavigate(1),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary),
                                  child: Text('Go to Library',
                                      style: GoogleFonts.nunito(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ]),
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

class _StatBox extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _StatBox(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900, color: color, fontSize: 18)),
          Text(label,
              style: GoogleFonts.nunito(
                  color: AppColors.textLight, fontSize: 11)),
        ]),
      ),
    );
  }
}
