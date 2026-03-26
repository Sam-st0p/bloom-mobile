import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

final _db = Supabase.instance.client;

// Auto-detect effective status based on scheduled_end time
String _effectiveStatus(Map<String, dynamic> sem) {
  final dbStatus = sem['status'] as String? ?? 'upcoming';
  // If admin explicitly set cancelled or completed, respect that
  if (dbStatus == 'cancelled' || dbStatus == 'completed') return dbStatus;
  final end = sem['scheduled_end'] as String?;
  final start = sem['scheduled_start'] as String?;
  if (end != null) {
    try {
      final utcEnd = end.endsWith('Z') || end.contains('+') ? end : '${end}Z';
      final endTime = DateTime.parse(utcEnd);
      if (DateTime.now().isAfter(endTime)) return 'completed';
    } catch (_) {}
  }
  if (start != null) {
    try {
      final utcStart = start.endsWith('Z') || start.contains('+') ? start : '${start}Z';
      final startTime = DateTime.parse(utcStart);
      if (DateTime.now().isAfter(startTime)) return 'ongoing';
    } catch (_) {}
  }
  return dbStatus;
}

String _fmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    // Ensure treated as UTC — append Z if missing
    final utc = iso.endsWith('Z') || iso.contains('+') ? iso : '${iso}Z';
    final d = DateTime.parse(utc).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ap';
  } catch (_) { return iso; }
}

String _fmtDateShort(String? iso) {
  if (iso == null) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) { return iso; }
}

// ─────────────────────────────────────────────────────────────────
//  EVENTS SCREEN — 3 tabs: Seminars, Calendar, Certificates
// ─────────────────────────────────────────────────────────────────
class EventsScreen extends StatefulWidget {
  final int initialTab;
  const EventsScreen({super.key, this.initialTab = 0});
  @override State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab); }
  @override void dispose()   { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F0),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 120, pinned: true, backgroundColor: const Color(0xFF2D4A18),
            automaticallyImplyLeading: false,
            leading: Navigator.canPop(context)
                ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2D4A18), Color(0xFF3A5A20)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                padding: const EdgeInsets.fromLTRB(20, 54, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('Events & Seminars', style: GoogleFonts.nunito(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text('Seminars, calendar & your certificates', style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ),
            bottom: TabBar(
              controller: _tabs, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [Tab(text: '🎓 Seminars'), Tab(text: '📅 Calendar'), Tab(text: '🏆 Certificates')],
            ),
          ),
        ],
        body: TabBarView(controller: _tabs, children: const [
          _SeminarsTab(), _CalendarTab(), _CertificatesTab(),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  SEMINARS TAB
// ─────────────────────────────────────────────────────────────────
class _SeminarsTab extends StatefulWidget {
  const _SeminarsTab();
  @override State<_SeminarsTab> createState() => _SeminarsTabState();
}

class _SeminarsTabState extends State<_SeminarsTab> {
  List<Map<String, dynamic>> _seminars = [];
  Set<String> _registered = {};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _db.auth.currentUser?.id;
    final sems = await _db.from('seminars')
        .select('*, seminar_registrations(count)')
        .eq('is_public', true)
        .order('scheduled_start');
    if (uid != null) {
      final regs = await _db.from('seminar_registrations').select('seminar_id').eq('user_id', uid).eq('status', 'registered');
      _registered = Set<String>.from((regs as List).map((r) => r['seminar_id'] as String));
    }
    setState(() { _seminars = List<Map<String, dynamic>>.from(sems); _loading = false; });
  }

  Future<void> _register(Map<String, dynamic> sem) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final semId = sem['id'] as String;
    final isReg = _registered.contains(semId);

    // Optimistic update — change UI immediately before DB call
    setState(() {
      if (isReg) {
        _registered.remove(semId);
        // Decrease count on the seminar object
        final idx = _seminars.indexWhere((s) => s['id'] == semId);
        if (idx != -1) {
          final current = (_seminars[idx]['seminar_registrations'] as List?)?.firstOrNull?['count'] ?? 0;
          final newCount = (current as int) > 0 ? current - 1 : 0;
          _seminars[idx] = {
            ..._seminars[idx],
            'seminar_registrations': [{'count': newCount}],
          };
        }
      } else {
        _registered.add(semId);
        // Increase count on the seminar object
        final idx = _seminars.indexWhere((s) => s['id'] == semId);
        if (idx != -1) {
          final current = (_seminars[idx]['seminar_registrations'] as List?)?.firstOrNull?['count'] ?? 0;
          _seminars[idx] = {
            ..._seminars[idx],
            'seminar_registrations': [{'count': (current as int) + 1}],
          };
        }
      }
    });

    try {
      if (isReg) {
        // Unregister — update status to cancelled
        await _db.from('seminar_registrations')
            .update({'status': 'cancelled'})
            .eq('seminar_id', semId)
            .eq('user_id', uid);
      } else {
        // Check if seminar is full → auto-waitlist
        final maxP = sem['max_participants'] as int?;
        String regStatus = 'registered';
        if (maxP != null) {
          final currentCount = await _db
              .from('seminar_registrations')
              .select('id')
              .eq('seminar_id', semId)
              .eq('status', 'registered');
          if ((currentCount as List).length >= maxP) {
            regStatus = 'waitlisted';
          }
        }

        // Try update first (row may exist as cancelled)
        final updateRes = await _db.from('seminar_registrations')
            .update({
              'status': regStatus,
              'registered_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('seminar_id', semId)
            .eq('user_id', uid)
            .select();

        // No existing row — insert fresh
        if ((updateRes as List).isEmpty) {
          await _db.from('seminar_registrations').insert({
            'seminar_id': semId,
            'user_id': uid,
            'status': regStatus,
            'registered_at': DateTime.now().toUtc().toIso8601String(),
          });
        }

        // Show waitlist notice if needed
        if (regStatus == 'waitlisted' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Seminar is full — you have been added to the waitlist.'),
            backgroundColor: Color(0xFFF59E0B),
          ));
        }
      }
    } catch (e) {
      // Revert optimistic update on failure
      setState(() {
        if (isReg) {
          _registered.add(semId);
        } else {
          _registered.remove(semId);
        }
      });
      debugPrint('Registration error: $e');
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ongoing':   return const Color(0xFF16A34A);
      case 'completed': return const Color(0xFF2563EB);
      case 'cancelled': return const Color(0xFFDC2626);
      default:          return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_seminars.isEmpty) return const _EmptyState(icon: '🎓', title: 'No seminars yet', sub: 'Check back later for upcoming seminars');

    // Split into active and past
    final active = _seminars.where((s) => _effectiveStatus(s) != 'completed' && _effectiveStatus(s) != 'cancelled').toList();
    final past   = _seminars.where((s) => _effectiveStatus(s) == 'completed' || _effectiveStatus(s) == 'cancelled').toList();

    // Build combined list with section headers
    final items = <dynamic>[
      if (active.isNotEmpty) ...active,
      if (past.isNotEmpty) ...['__PAST_HEADER__', ...past],
    ];

    return RefreshIndicator(
      color: AppColors.primary, onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          // Section header
          if (items[i] == '__PAST_HEADER__') {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(children: [
                Container(height: 1, width: 20, color: Colors.grey[300]),
                const SizedBox(width: 8),
                Text('Past Seminars', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: Colors.grey[300])),
              ]),
            );
          }
          final sem  = items[i] as Map<String, dynamic>;
          final isReg = _registered.contains(sem['id'] as String);
          final regCount = (sem['seminar_registrations'] as List?)?.firstOrNull?['count'] ?? 0;
          final type = sem['seminar_type'] as String? ?? 'online';
          return GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => SeminarDetailScreen(seminar: sem, isRegistered: isReg, onRegister: () => _register(sem)),
            )).then((_) async { await _load(); }),
            child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Cover image
              if (sem['cover_image_url'] != null)
                ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(sem['cover_image_url'], height: 140, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()))
              else
                Container(height: 6, decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(sem['title'] ?? '', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF2D4A18)))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusColor(_effectiveStatus(sem)).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(_effectiveStatus(sem).toUpperCase(), style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor(_effectiveStatus(sem))))),
                  ]),
                  const SizedBox(height: 8),
                  if (sem['description'] != null) ...[
                    Text(sem['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                  ],
                  _InfoRow(icon: '📅', text: _fmtDate(sem['scheduled_start'] as String?)),
                  if (sem['scheduled_end'] != null) _InfoRow(icon: '🏁', text: 'Ends ${_fmtDate(sem['scheduled_end'] as String?)}'),
                  if (sem['venue'] != null) _InfoRow(icon: '📍', text: sem['venue']),
                  if (sem['webinar_link'] != null) _InfoRow(icon: '🔗', text: '${sem['webinar_platform'] ?? 'Online'} Meeting'),
                  _InfoRow(icon: '👥', text: '$regCount registered${sem['max_participants'] != null ? ' / ${sem['max_participants']} max' : ''}'),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (sem['webinar_link'] != null)
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(sem['webinar_link'] as String);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text('Join', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      )),
                    if (sem['webinar_link'] != null) const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: _effectiveStatus(sem) == 'completed'
                          ? () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SeminarDetailScreen(seminar: sem, isRegistered: isReg, onRegister: () => _register(sem)))).then((_) async { await _load(); })
                          : _effectiveStatus(sem) == 'cancelled' ? null
                          : () => _register(sem),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _effectiveStatus(sem) == 'completed'
                            ? const Color(0xFFF59E0B)
                            : isReg ? Colors.grey[200] : AppColors.primary,
                        foregroundColor: _effectiveStatus(sem) == 'completed'
                            ? Colors.white
                            : isReg ? Colors.grey[700] : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        _effectiveStatus(sem) == 'completed' ? '⭐ Rate Seminar'
                            : _effectiveStatus(sem) == 'cancelled' ? 'Cancelled'
                            : isReg ? '✓ Registered' : 'Register',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13)),
                    )),
                  ]),
                ]),
              ),
            ]),
          ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────
//  SEMINAR DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────
class SeminarDetailScreen extends StatefulWidget {
  final Map<String, dynamic> seminar;
  final bool isRegistered;
  final Future<void> Function() onRegister;
  const SeminarDetailScreen({super.key, required this.seminar, required this.isRegistered, required this.onRegister});
  @override State<SeminarDetailScreen> createState() => _SeminarDetailScreenState();
}

class _SeminarDetailScreenState extends State<SeminarDetailScreen> {
  late bool _isReg;
  bool _loading       = false;
  bool _hasEvaluated  = false;
  bool _evalLoading   = false;
  bool _evalSubmitted = false;
  final TextEditingController _commentCtrl = TextEditingController();

  // Structured evaluation scores — 1–5 for each criterion
  final Map<String, int> _scores = {
    'q_content':      0,
    'q_speaker':      0,
    'q_organization': 0,
    'q_relevance':    0,
    'q_materials':    0,
    'q_overall':      0,
  };
  static const Map<String, String> _evalLabels = {
    'q_content':      'Content Quality',
    'q_speaker':      'Speaker Effectiveness',
    'q_organization': 'Event Organization',
    'q_relevance':    'Relevance to GAD',
    'q_materials':    'Materials & Resources',
    'q_overall':      'Overall Satisfaction',
  };
  static const Map<String, String> _evalDescs = {
    'q_content':      'Relevance and accuracy of the seminar content',
    'q_speaker':      'Clarity, knowledge, and delivery of the speaker(s)',
    'q_organization': 'Logistics, time management, and flow of the event',
    'q_relevance':    'How relevant was this activity to gender and development?',
    'q_materials':    'Quality of presentation materials and handouts',
    'q_overall':      'Your overall experience with this seminar',
  };

  @override void initState() { super.initState(); _isReg = widget.isRegistered; _checkEvaluation(); }

  @override void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _checkEvaluation() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final existing = await _db.from('seminar_evaluations')
        .select('id')
        .eq('seminar_id', widget.seminar['id'])
        .eq('user_id', uid)
        .maybeSingle();
    if (mounted) setState(() => _hasEvaluated = existing != null);
  }

  Future<void> _submitEvaluation() async {
    if (_scores.values.any((v) => v == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate all criteria before submitting.'), backgroundColor: Color(0xFFDC2626)));
      return;
    }
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _evalLoading = true);
    try {
      await _db.from('seminar_evaluations').insert({
        'seminar_id': widget.seminar['id'],
        'user_id':    uid,
        'q_content':      _scores['q_content'],
        'q_speaker':      _scores['q_speaker'],
        'q_organization': _scores['q_organization'],
        'q_relevance':    _scores['q_relevance'],
        'q_materials':    _scores['q_materials'],
        'q_overall':      _scores['q_overall'],
        'rating':         _scores['q_overall'], // backward compat
        'comments':       _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        'submitted_at':   DateTime.now().toUtc().toIso8601String(),
      });
      setState(() { _hasEvaluated = true; _evalSubmitted = true; _evalLoading = false; });
    } catch (e) {
      setState(() => _evalLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _scoreLabel(int score) {
    switch (score) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return '';
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _loading = true);
    await widget.onRegister();
    setState(() { _isReg = !_isReg; _loading = false; });
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'ongoing':   return const Color(0xFF16A34A);
      case 'completed': return const Color(0xFF2563EB);
      case 'cancelled': return const Color(0xFFDC2626);
      default:          return const Color(0xFFF59E0B);
    }
  }

  String _platformLabel(String? p) {
    switch (p) {
      case 'zoom':  return 'Zoom';
      case 'gmeet': return 'Google Meet';
      case 'teams': return 'MS Teams';
      default:      return 'Online';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem    = widget.seminar;
    // Use effective status — auto-detects completed based on scheduled_end
    final status = _effectiveStatus(sem);
    final type   = sem['seminar_type'] as String? ?? 'webinar';
    final canRegister = status != 'completed' && status != 'cancelled';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F0),
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──
          SliverAppBar(
            expandedHeight: sem['cover_image_url'] != null ? 260 : 160,
            pinned: true,
            backgroundColor: const Color(0xFF2D4A18),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: sem['cover_image_url'] != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.network(sem['cover_image_url'], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2D4A18))),
                      Container(decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)]))),
                      Positioned(bottom: 20, left: 20, right: 20, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                            child: Text(status.toUpperCase(), style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                          const SizedBox(height: 8),
                          Text(sem['title'] ?? '', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      )),
                    ])
                  : Container(
                      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2D4A18), Color(0xFF5A7A3A)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(), style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                        const SizedBox(height: 8),
                        Text(sem['title'] ?? '', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Type badge
                Row(children: [
                  _TypeBadge(type == 'in_person' ? '📍 In Person' : type == 'hybrid' ? '🔀 Hybrid' : '💻 Webinar'),
                  const SizedBox(width: 8),
                  if (_isReg) const _TypeBadge('✅ Registered', color: Color(0xFF16A34A)),
                ]),
                const SizedBox(height: 20),

                // Info card
                _DetailCard(children: [
                  _DetailRow('📅', 'Start', _fmtDate(sem['scheduled_start'] as String?)),
                  if (sem['scheduled_end'] != null) _DetailRow('🏁', 'End', _fmtDate(sem['scheduled_end'] as String?)),
                  if (sem['venue'] != null) _DetailRow('📍', 'Venue', sem['venue']),
                  if (sem['webinar_link'] != null) _DetailRow('💻', 'Platform', _platformLabel(sem['webinar_platform'] as String?)),
                  _DetailRow('👥', 'Participants', sem['max_participants'] != null ? 'Max ${sem['max_participants']} participants' : 'Unlimited'),
                ]),
                const SizedBox(height: 20),

                // Description
                if (sem['description'] != null && (sem['description'] as String).isNotEmpty) ...[
                  Text('About this Seminar', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF2D4A18))),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                    child: Text(sem['description'], style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF444444), height: 1.6)),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action buttons
                if (sem['webinar_link'] != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(sem['webinar_link'] as String);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('Join ${_platformLabel(sem['webinar_platform'] as String?)}',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !canRegister || _loading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReg ? Colors.grey[200] : AppColors.primary,
                      foregroundColor: _isReg ? Colors.grey[700] : Colors.white,
                      disabledBackgroundColor: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : Text(
                            !canRegister ? (status == 'completed' ? 'Seminar Completed' : 'Cancelled')
                                : _isReg ? '✓ Registered - Tap to Cancel'
                                : 'Register for this Seminar',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Evaluation Section ──
                if (status == 'completed' && _isReg) ...[
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                      border: Border.all(color: const Color(0xFFE8F2D8)),
                    ),
                    child: _hasEvaluated || _evalSubmitted
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(children: [
                              Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.check_circle_outline, color: Color(0xFF2D6A2D), size: 36)),
                              const SizedBox(height: 14),
                              Text('Evaluation Submitted!', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF2D4A18))),
                              const SizedBox(height: 6),
                              Text('Thank you for taking the time to evaluate this seminar. Your feedback helps us improve.', textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600], height: 1.5)),
                            ]))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [Color(0xFF1A2E1A), Color(0xFF2D6A2D)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.assignment_outlined, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Seminar Evaluation Form', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                                  Text('Please rate each criterion from 1 (Poor) to 5 (Excellent)', style: GoogleFonts.nunito(fontSize: 11, color: Colors.white70)),
                                ])),
                              ]),
                            ),
                            // Criteria rows
                            ...(_evalLabels.entries.map((entry) {
                              final key   = entry.key;
                              final label = entry.value;
                              final desc  = _evalDescs[key] ?? '';
                              final score = _scores[key] ?? 0;
                              return Container(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A2E1A))),
                                      Text(desc, style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[500])),
                                    ])),
                                    if (score > 0)
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                                        child: Text(_scoreLabel(score), style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2D6A2D)))),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: List.generate(5, (i) {
                                    final star = i + 1;
                                    return Expanded(child: GestureDetector(
                                      onTap: () => setState(() => _scores[key] = star),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: score >= star ? const Color(0xFF2D6A2D) : const Color(0xFFF5F7F5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: score >= star ? const Color(0xFF2D6A2D) : const Color(0xFFDDE8DD)),
                                        ),
                                        child: Center(child: Text('$star',
                                          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800,
                                            color: score >= star ? Colors.white : Colors.grey[500]))),
                                      ),
                                    ));
                                  })),
                                  const SizedBox(height: 12),
                                  Divider(color: Colors.grey[100], height: 1),
                                ]),
                              );
                            })),
                            // Comments
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Additional Comments', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A2E1A))),
                                const SizedBox(height: 4),
                                Text('Optional — share any other feedback', style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _commentCtrl,
                                  maxLines: 3,
                                  style: GoogleFonts.nunito(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Your comments here…',
                                    hintStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8F2D8))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8F2D8))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2D6A2D))),
                                    filled: true, fillColor: const Color(0xFFF6F9F0),
                                    contentPadding: const EdgeInsets.all(14),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Progress indicator
                                Row(children: [
                                  Expanded(child: Text('${_scores.values.where((v) => v > 0).length} of ${_scores.length} criteria rated',
                                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey))),
                                ]),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _evalLoading ? null : _submitEvaluation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A2E1A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _evalLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text('Submit Evaluation', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 15)),
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                  ),
                  const SizedBox(height: 32),
                ] else
                  const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const _TypeBadge(this.text, {this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: (color ?? AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? AppColors.primary)),
  );
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  final String icon, label, value;
  const _DetailRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2D4A18))),
      ])),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String icon, text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  CALENDAR TAB
// ─────────────────────────────────────────────────────────────────
class _CalendarTab extends StatefulWidget {
  const _CalendarTab();
  @override State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  DateTime _viewDate = DateTime.now();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.from('events').select('*').order('start_date');
    setState(() { _events = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  List<Map<String, dynamic>> _eventsForDate(String dateStr) {
    return _events.where((e) {
      final start = (e['start_date'] as String? ?? '').substring(0, 10 < (e['start_date'] as String? ?? '').length ? 10 : (e['start_date'] as String? ?? '').length);
      final end   = ((e['end_date'] as String?) ?? start).substring(0, 10 < ((e['end_date'] as String?) ?? start).length ? 10 : ((e['end_date'] as String?) ?? start).length);
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    }).toList();
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.primary;
    try { return Color(int.parse(hex.replaceAll('#', '0xFF'))); } catch (_) { return AppColors.primary; }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    final year  = _viewDate.year;
    final month = _viewDate.month;
    final firstDay    = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();
    const monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];

    // Upcoming events
    final todayStr = today.toIso8601String().substring(0, 10);
    final upcoming = _events.where((e) { final s = (e['start_date'] as String? ?? ''); final start = s.length >= 10 ? s.substring(0, 10) : s; return start.compareTo(todayStr) >= 0; }).take(5).toList();

    return RefreshIndicator(
      color: AppColors.primary, onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Calendar header
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Column(children: [
            // Nav
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: Color(0xFF2D4A18), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => setState(() => _viewDate = DateTime(year, month - 1, 1))),
                Text('${monthNames[month - 1]} $year', style: GoogleFonts.nunito(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => setState(() => _viewDate = DateTime(year, month + 1, 1))),
              ]),
            ),
            // Day headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: ['S','M','T','W','T','F','S'].map((d) =>
                Expanded(child: Center(child: Text(d, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey))))
              ).toList()),
            ),
            // Grid
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9),
              itemCount: firstDay + daysInMonth,
              itemBuilder: (ctx, i) {
                if (i < firstDay) return const SizedBox();
                final day     = i - firstDay + 1;
                final dateStr = '${year.toString().padLeft(4,'0')}-${month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
                final isToday = day == today.day && month == today.month && year == today.year;
                final dayEvs  = _eventsForDate(dateStr);
                return Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$day', style: GoogleFonts.nunito(fontSize: 12, fontWeight: isToday ? FontWeight.w900 : FontWeight.w500, color: isToday ? AppColors.primary : const Color(0xFF2D4A18))),
                    if (dayEvs.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Wrap(alignment: WrapAlignment.center, spacing: 2, children: dayEvs.take(2).map((e) =>
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: _parseColor(e['color_hex'] as String?), shape: BoxShape.circle))
                      ).toList()),
                    ],
                  ]),
                );
              },
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Upcoming
        Text('Upcoming Events', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF2D4A18))),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          const _EmptyState(icon: '📅', title: 'No upcoming events', sub: 'Check back later')
        else
          ...upcoming.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: _parseColor(e['color_hex'] as String?), width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['title'] ?? '', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF2D4A18))),
              const SizedBox(height: 4),
              Text(_fmtDateShort(e['start_date'] as String?) + (e['end_date'] != null && e['end_date'] != e['start_date'] ? ' – ${_fmtDateShort(e['end_date'] as String?)}' : ''),
                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
              if (e['description'] != null) ...[
                const SizedBox(height: 4),
                Text(e['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600])),
              ],
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _parseColor(e['color_hex'] as String?).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text((e['event_type'] ?? 'event').toString().toUpperCase(), style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: _parseColor(e['color_hex'] as String?)))),
            ]),
          )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  CERTIFICATES TAB
// ─────────────────────────────────────────────────────────────────
class _CertificatesTab extends StatefulWidget {
  const _CertificatesTab();
  @override State<_CertificatesTab> createState() => _CertificatesTabState();
}

class _CertificatesTabState extends State<_CertificatesTab> {
  List<Map<String, dynamic>> _certs = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _db.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    final data = await _db.from('certificates').select('*').eq('user_id', uid).eq('is_revoked', false).order('issued_at', ascending: false);
    setState(() { _certs = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return RefreshIndicator(
      color: AppColors.primary, onRefresh: _load,
      child: _certs.isEmpty
          ? const _EmptyState(icon: '🏆', title: 'No certificates yet', sub: 'Complete modules and seminars to earn certificates')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _certs.length,
              itemBuilder: (ctx, i) {
                final cert = _certs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
                    border: Border.all(color: const Color(0xFFFDE047), width: 1.5),
                  ),
                  child: Row(children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('🏆', style: TextStyle(fontSize: 28)))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cert['reference_type'] == 'manual' ? 'Certificate of Achievement' : 'Certificate of ${(cert['reference_type'] ?? 'completion').toString().capitalize()}',
                        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF2D4A18))),
                      const SizedBox(height: 3),
                      Text('Issued ${_fmtDateShort(cert['issued_at'] as String?)}', style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE8F2D8), borderRadius: BorderRadius.circular(5)),
                        child: Text(cert['certificate_code'] ?? '—', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary))),
                    ])),
                    if (cert['certificate_url'] != null)
                      IconButton(
                        icon: const Icon(Icons.download, color: AppColors.primary),
                        onPressed: () async {
                          final uri = Uri.parse(cert['certificate_url'] as String);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                  ]),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String icon, title, sub;
  const _EmptyState({required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(icon, style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[600])),
      const SizedBox(height: 6),
      Text(sub, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey)),
    ])));
}

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}