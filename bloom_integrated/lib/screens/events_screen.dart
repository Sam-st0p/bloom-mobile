import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // Seminars
  List<Map<String, dynamic>> _seminars = [];
  Set<String> _registeredIds = {};
  bool _seminarsLoading = true;

  // Events
  List<EventModel> _events = [];
  bool _eventsLoading = true;

  // Certificates
  List<CertificateModel> _certificates = [];
  bool _certsLoading = true;

  // Evaluation state
  String? _evalSeminarId;
  String? _evalSeminarTitle;
  bool _evalSubmitted = false;
  int _rating = 0;
  final _evalCommentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSeminars();
    _loadEvents();
    _loadCertificates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _evalCommentCtrl.dispose();
    super.dispose();
  }

  // ── Data loaders ───────────────────────────────────────────────────

  Future<void> _loadSeminars() async {
    setState(() => _seminarsLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;

      final data = await _supabase
          .from('seminars')
          .select('*')
          .eq('is_public', true)
          .order('start_date');

      Set<String> registered = {};
      if (userId != null) {
        final regs = await _supabase
            .from('seminar_registrations')
            .select('seminar_id')
            .eq('user_id', userId)
            .eq('status', 'registered');
        registered =
            (regs as List).map((r) => r['seminar_id'].toString()).toSet();
      }

      if (mounted) {
        setState(() {
          _seminars = List<Map<String, dynamic>>.from(data as List);
          _registeredIds = registered;
          _seminarsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _seminarsLoading = false);
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _eventsLoading = true);
    try {
      final data = await _supabase
          .from('events')
          .select('*')
          .order('start_date');

      if (mounted) {
        setState(() {
          _events = (data as List)
              .map((e) => EventModel.fromMap(e as Map<String, dynamic>))
              .toList();
          _eventsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _loadCertificates() async {
    setState(() => _certsLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _certsLoading = false);
        return;
      }

      final data = await _supabase
          .from('certificates')
          .select('*, certificate_templates(name)')
          .eq('user_id', userId)
          .eq('is_revoked', false)
          .order('issued_at', ascending: false);

      if (mounted) {
        setState(() {
          _certificates = (data as List)
              .map((c) => CertificateModel.fromMap(c as Map<String, dynamic>))
              .toList();
          _certsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _certsLoading = false);
    }
  }

  Future<void> _registerSeminar(String seminarId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('seminar_registrations').insert({
        'user_id': userId,
        'seminar_id': seminarId,
        'status': 'registered',
        'registered_at': DateTime.now().toIso8601String(),
      });
      setState(() => _registeredIds.add(seminarId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registered successfully! 🎉'),
              backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Already registered or error: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _submitEvaluation() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _evalSeminarId == null) return;
    try {
      await _supabase.from('seminar_evaluations').insert({
        'user_id': userId,
        'seminar_id': _evalSeminarId,
        'overall_rating': _rating,
        'comments': _evalCommentCtrl.text.trim(),
        'submitted_at': DateTime.now().toIso8601String(),
      });
      setState(() => _evalSubmitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting: $e')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_evalSeminarId != null) return _buildEvaluation();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📅 Events & Seminars',
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textLight,
                  labelStyle: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w800),
                  unselectedLabelStyle: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w800),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '🎓 Seminars'),
                    Tab(text: '📆 Events'),
                    Tab(text: '📜 Certs')
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSeminars(),
              _buildEvents(),
              _buildCertificates()
            ],
          ),
        ),
      ],
    );
  }

  // ── Seminars Tab ───────────────────────────────────────────────────

  Widget _buildSeminars() {
    if (_seminarsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_seminars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('No seminars available yet',
                style: GoogleFonts.nunito(
                    color: AppColors.textLight, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadSeminars,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _seminars.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = _seminars[i];
          final id = s['id'].toString();
          final isRegistered = _registeredIds.contains(id);
          final status = s['status']?.toString() ?? '';
          final isLive = status == 'ongoing';
          final isCompleted = status == 'completed';

          // Format date
          final rawDate = s['start_date'] ?? s['scheduled_at'] ?? '';
          final dateStr = rawDate.toString().length >= 10
              ? rawDate.toString().substring(0, 10)
              : 'TBA';

          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BadgeChip(
                      label: isLive
                          ? '🔴 LIVE'
                          : isCompleted
                              ? '✅ Completed'
                              : '📅 Upcoming',
                      color: isLive
                          ? AppColors.danger
                          : isCompleted
                              ? AppColors.primary
                              : AppColors.info,
                    ),
                    Text(dateStr,
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(s['title'] ?? 'Untitled Seminar',
                    style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                if (s['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(s['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.textMid)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!isCompleted)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isRegistered
                              ? null
                              : () => _registerSeminar(id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLive
                                ? AppColors.danger
                                : AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                              isRegistered
                                  ? '✓ Registered'
                                  : isLive
                                      ? 'Join Now 🔴'
                                      : 'Register',
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    if (isRegistered || isCompleted) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          _evalSeminarId = id;
                          _evalSeminarTitle =
                              s['title'] ?? 'Seminar';
                          _evalSubmitted = false;
                          _rating = 0;
                          _evalCommentCtrl.clear();
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.accent.withOpacity(0.15),
                          foregroundColor: AppColors.accent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 14),
                        ),
                        child: Text('Evaluate',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Events Tab ─────────────────────────────────────────────────────

  Widget _buildEvents() {
    if (_eventsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('No events yet',
                style: GoogleFonts.nunito(
                    color: AppColors.textLight, fontSize: 14)),
          ],
        ),
      );
    }

    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.info,
      const Color(0xFF7B2D8B),
      const Color(0xFFE63946),
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final ev = _events[i];
          final color = colors[i % colors.length];
          return AppCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text(ev.date,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev.title,
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      BadgeChip(label: ev.category, color: color),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textLight, size: 18),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Certificates Tab ───────────────────────────────────────────────

  Widget _buildCertificates() {
    if (_certsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_certificates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium_outlined,
                size: 48, color: AppColors.textLight),
            const SizedBox(height: 12),
            Text('No certificates yet',
                style: GoogleFonts.nunito(
                    color: AppColors.textLight, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Complete modules and seminars to earn certificates',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    color: AppColors.textLight, fontSize: 12)),
          ],
        ),
      );
    }

    final colors = [
      AppColors.primary,
      AppColors.info,
      const Color(0xFF7B2D8B),
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadCertificates,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _certificates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = _certificates[i];
          final color = colors[i % colors.length];
          return AppCard(
            child: Container(
              decoration: BoxDecoration(
                  border:
                      Border(left: BorderSide(color: color, width: 4))),
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.workspace_premium_outlined,
                        color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title,
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textDark)),
                        Text('${c.issuer} • ${c.date}',
                            style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: AppColors.textLight)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: color),
                                  foregroundColor: color,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                ),
                                child: Text('👁 View',
                                    style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: color,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                ),
                                child: Text('⬇️ Save',
                                    style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Evaluation View ────────────────────────────────────────────────

  Widget _buildEvaluation() {
    if (_evalSubmitted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text('Thank You!',
                style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text('Your feedback has been submitted to GADRC.',
                style: GoogleFonts.nunito(color: AppColors.textLight)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                _evalSeminarId = null;
                _evalSeminarTitle = null;
                _evalSubmitted = false;
                _rating = 0;
              }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: Text('Done',
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    setState(() => _evalSeminarId = null),
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textMid),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seminar Evaluation',
                        style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark)),
                    Text('${_evalSeminarTitle ?? ''} • Help us improve',
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Text('Overall Rating',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => GestureDetector(
                          onTap: () => setState(() => _rating = i + 1),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.star_rounded,
                                size: 40,
                                color: i < _rating
                                    ? const Color(0xFFFFBA08)
                                    : AppColors.border),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comments & Suggestions',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _evalCommentCtrl,
                      maxLines: 4,
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts...',
                        hintStyle:
                            GoogleFonts.nunito(color: AppColors.textLight),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _rating == 0 ? null : _submitEvaluation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Submit Evaluation',
                      style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}