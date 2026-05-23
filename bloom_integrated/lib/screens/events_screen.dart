// lib/screens/events_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

final _db = Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED REGISTRATION STATE
//  Single source of truth for registration IDs, shared across both tabs
//  and the detail screen. Both tabs hold a reference to the same instance.
// ─────────────────────────────────────────────────────────────────────────────
class SeminarRegistrationState extends ChangeNotifier {
  Set<String> _registeredIds = {};
  bool _loaded = false;

  Set<String> get registeredIds => _registeredIds;
  bool get loaded => _loaded;

  bool isRegistered(String seminarId) => _registeredIds.contains(seminarId);

  Future<void> load() async {
    _registeredIds = await DatabaseService.fetchMyRegisteredSeminarIds();
    _loaded = true;
    notifyListeners();
  }

  void add(String seminarId) {
    _registeredIds = {..._registeredIds, seminarId};
    notifyListeners();
  }

  void remove(String seminarId) {
    _registeredIds = _registeredIds.where((id) => id != seminarId).toSet();
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _effectiveStatus(Map<String, dynamic> sem) {
  final dbStatus = sem['status'] as String? ?? 'upcoming';
  if (dbStatus == 'cancelled' || dbStatus == 'completed') return dbStatus;
  final end   = sem['scheduled_end']   as String?;
  final start = sem['scheduled_start'] as String?;
  if (end != null) {
    try {
      final utcEnd = end.endsWith('Z') || end.contains('+') ? end : '${end}Z';
      if (DateTime.now().isAfter(DateTime.parse(utcEnd))) return 'completed';
    } catch (_) {}
  }
  if (start != null) {
    try {
      final utcStart =
          start.endsWith('Z') || start.contains('+') ? start : '${start}Z';
      if (DateTime.now().isAfter(DateTime.parse(utcStart))) return 'ongoing';
    } catch (_) {}
  }
  return dbStatus;
}

/// Returns true if the seminar start time is still in the future
/// (registration is still open).
bool _registrationOpen(Map<String, dynamic> sem) {
  final status = sem['status'] as String? ?? 'upcoming';
  if (status == 'cancelled' || status == 'completed') return false;
  final start = sem['scheduled_start'] as String?;
  if (start == null) return true;
  try {
    final utcStart =
        start.endsWith('Z') || start.contains('+') ? start : '${start}Z';
    return DateTime.now().isBefore(DateTime.parse(utcStart));
  } catch (_) {
    return true;
  }
}

String _fmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    final utc = iso.endsWith('Z') || iso.contains('+') ? iso : '${iso}Z';
    final d   = DateTime.parse(utc).toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h  = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m  = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ap';
  } catch (_) {
    return iso;
  }
}

String _fmtDateShort(String? iso) {
  if (iso == null) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso;
  }
}

Map<String, dynamic> _seminarToCalendarEvent(Map<String, dynamic> sem) {
  String? dateOnly(String? iso) {
    if (iso == null) return null;
    try {
      final utc = iso.endsWith('Z') || iso.contains('+') ? iso : '${iso}Z';
      return DateTime.parse(utc).toLocal().toIso8601String().substring(0, 10);
    } catch (_) {
      return null;
    }
  }

  return {
    'id':          'seminar_${sem['id']}',
    'title':       sem['title'],
    'description': sem['description'],
    'start_date':  dateOnly(sem['scheduled_start'] as String?),
    'end_date':    dateOnly(sem['scheduled_end'] as String?) ??
                   dateOnly(sem['scheduled_start'] as String?),
    'color_hex':   '#2563EB',
    'event_type':  'seminar',
    '_source':     'seminar',
    '_raw':        sem,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  EVENTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EventsScreen extends StatefulWidget {
  final int initialTab;
  const EventsScreen({super.key, this.initialTab = 0});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  /// Shared registration state — passed down to both tabs so they
  /// always read from and write to the same set of IDs.
  final _regState = SeminarRegistrationState();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
    _regState.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _regState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F0),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: topPadding + 160,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            automaticallyImplyLeading: false,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context))
                : null,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Events & Seminars',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                    icon: Icon(Icons.school_rounded, size: 16),
                    text: 'Seminars'),
                Tab(
                    icon: Icon(Icons.calendar_month_rounded, size: 16),
                    text: 'Calendar'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _SeminarsTab(regState: _regState),
            _CalendarTab(regState: _regState),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEMINARS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _SeminarsTab extends StatefulWidget {
  final SeminarRegistrationState regState;
  const _SeminarsTab({required this.regState});
  @override
  State<_SeminarsTab> createState() => _SeminarsTabState();
}

class _SeminarsTabState extends State<_SeminarsTab> {
  List<Map<String, dynamic>> _seminars   = [];
  bool _loading     = true;
  bool _loadingMore = false;
  bool _hasMore     = true;
  int  _page        = 0;
  final Set<String> _registering = {};
  static const int  _pageSize    = 10;
  final _scrollController = ScrollController();

  /// Periodic timer that forces a rebuild every 30 s so statuses
  /// (Upcoming → Ongoing → Ended) update without a manual reload.
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    // Rebuild every 30 seconds to recalculate time-based statuses
    _statusTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); },
    );
    widget.regState.addListener(_onRegStateChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _statusTimer?.cancel();
    widget.regState.removeListener(_onRegStateChanged);
    super.dispose();
  }

  void _onRegStateChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page    = 0;
      _hasMore = true;
    });
    try {
      final sems = await _db
          .from('seminars')
          .select('*, seminar_registrations(count)')
          .eq('is_public', true)
          .order('scheduled_start')
          .range(0, _pageSize - 1);

      // Also refresh registration state
      await widget.regState.load();

      final list = List<Map<String, dynamic>>.from(sems);
      if (mounted) {
        setState(() {
          _seminars = list;
          _hasMore  = list.length == _pageSize;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final from     = nextPage * _pageSize;
      final to       = from + _pageSize - 1;
      final sems = await _db
          .from('seminars')
          .select('*, seminar_registrations(count)')
          .eq('is_public', true)
          .order('scheduled_start')
          .range(from, to);
      final list = List<Map<String, dynamic>>.from(sems);
      if (mounted) {
        setState(() {
          _seminars.addAll(list);
          _page        = nextPage;
          _hasMore     = list.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _register(Map<String, dynamic> sem) async {
    final semId = sem['id'] as String;
    if (_registering.contains(semId)) return;

    final isReg   = widget.regState.isRegistered(semId);
    final isOpen  = _registrationOpen(sem);
    final status  = _effectiveStatus(sem);

    // Cannot register for cancelled/completed seminars
    if (!isReg && (status == 'completed' || status == 'cancelled')) return;

    // Cannot register after seminar has started
    if (!isReg && !isOpen) {
      _showSnack('Registration is closed — this seminar has already started.',
          isError: true);
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isReg ? 'Cancel Registration?' : 'Register for Seminar?',
          style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800, color: AppColors.primaryDark),
        ),
        content: Text(
          isReg
              ? 'Are you sure you want to cancel your registration for "${sem['title']}"?'
              : 'Register for "${sem['title']}"?\n\nYour current profile information (name, role, department) will be saved with your registration.',
          style: GoogleFonts.nunito(
              fontSize: 13, color: Colors.grey[700], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isReg ? AppColors.danger : AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              isReg ? 'Cancel Registration' : 'Register',
              style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _registering.add(semId));
    try {
      if (isReg) {
        final err = await DatabaseService.cancelRegistration(semId);
        if (err != null && mounted) {
          _showSnack('Failed to cancel registration. Please try again.',
              isError: true);
          return;
        }
        widget.regState.remove(semId);
        _showSnack('Registration cancelled.');
      } else {
        final err = await DatabaseService.registerForSeminar(semId);
        if (err == 'already_registered') {
          widget.regState.add(semId);
          _showSnack('You are already registered for this seminar.');
          return;
        }
        if (err == 'registration_closed') {
          _showSnack(
              'Registration is closed — this seminar has already started.',
              isError: true);
          return;
        }
        if (err != null && mounted) {
          _showSnack('Registration failed. Please try again.', isError: true);
          return;
        }
        widget.regState.add(semId);
        _showSnack('Successfully registered!');
      }
      // Refresh participant counts from server
      _load();
    } finally {
      if (mounted) setState(() => _registering.remove(semId));
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: isError ? AppColors.danger : AppColors.primary,
    ));
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
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_seminars.isEmpty) {
      return const _EmptyState(
          icon: Icons.school_outlined,
          title: 'No seminars yet',
          sub: 'Check back later for upcoming seminars');
    }

    final active = _seminars
        .where((s) =>
            _effectiveStatus(s) != 'completed' &&
            _effectiveStatus(s) != 'cancelled')
        .toList();
    final past = _seminars
        .where((s) =>
            _effectiveStatus(s) == 'completed' ||
            _effectiveStatus(s) == 'cancelled')
        .toList();

    final items = <dynamic>[
      if (active.isNotEmpty) ...active,
      if (past.isNotEmpty) ...['__PAST_HEADER__', ...past],
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: items.length +
            (_loadingMore ? 1 : 0) +
            (!_hasMore && _seminars.isNotEmpty ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == items.length && _loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            );
          }
          if (i == items.length && !_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text(
                'All ${_seminars.length} seminars loaded',
                style: GoogleFonts.nunito(
                    fontSize: 12, color: AppColors.textLight),
              )),
            );
          }

          if (items[i] == '__PAST_HEADER__') {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(children: [
                Container(height: 1, width: 20, color: Colors.grey[300]),
                const SizedBox(width: 8),
                Text('Past Seminars',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(height: 1, color: Colors.grey[300])),
              ]),
            );
          }

          final sem      = items[i] as Map<String, dynamic>;
          final semId    = sem['id'] as String;
          final isReg    = widget.regState.isRegistered(semId);
          final isBusy   = _registering.contains(semId);
          final isOpen   = _registrationOpen(sem);
          final regCount = (sem['seminar_registrations'] as List?)
                  ?.firstOrNull?['count'] ?? 0;
          final status   = _effectiveStatus(sem);

          // Button label logic
          String btnLabel;
          if (isBusy) {
            btnLabel = isReg ? 'Cancelling…' : 'Registering…';
          } else if (status == 'completed') {
            btnLabel = 'Evaluate';
          } else if (status == 'cancelled') {
            btnLabel = 'Cancelled';
          } else if (!isOpen && !isReg) {
            btnLabel = 'Registration Closed';
          } else if (isReg) {
            btnLabel = 'Registered';
          } else {
            btnLabel = 'Register';
          }

          // Button tap action
          VoidCallback? btnAction;
          if (!isBusy) {
            if (status == 'completed') {
              btnAction = () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => SeminarDetailScreen(
                        seminar:   sem,
                        regState:  widget.regState,
                        onRegister: () => _register(sem),
                      ),
                    ),
                  ).then((_) => _load());
            } else if (status != 'cancelled' && (isReg || isOpen)) {
              btnAction = () => _register(sem);
            }
          }

          return GestureDetector(
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => SeminarDetailScreen(
                  seminar:    sem,
                  regState:   widget.regState,
                  onRegister: () => _register(sem),
                ),
              ),
            ).then((_) => _load()),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sem['cover_image_url'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: Image.network(
                        sem['cover_image_url'],
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    )
                  else
                    Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primary
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(sem['title'] ?? '',
                                    style: GoogleFonts.nunito(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryDark))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _statusColor(status)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (sem['description'] != null) ...[
                          Text(
                            sem['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            text: _fmtDate(
                                sem['scheduled_start'] as String?)),
                        if (sem['scheduled_end'] != null)
                          _InfoRow(
                              icon: Icons.flag_outlined,
                              text:
                                  'Ends ${_fmtDate(sem['scheduled_end'] as String?)}'),
                        if (sem['venue'] != null)
                          _InfoRow(
                              icon: Icons.location_on_outlined,
                              text: sem['venue']),
                        if (sem['webinar_link'] != null)
                          _InfoRow(
                              icon: Icons.videocam_outlined,
                              text:
                                  '${sem['webinar_platform'] ?? 'Online'} Meeting'),
                        _InfoRow(
                            icon: Icons.group_outlined,
                            text: '$regCount registered'
                                '${sem['max_participants'] != null ? ' / ${sem['max_participants']} max' : ''}'),
                        const SizedBox(height: 12),
                        Row(children: [
                          if (sem['webinar_link'] != null) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(
                                      sem['webinar_link'] as String);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode
                                            .externalApplication);
                                  }
                                },
                                icon: const Icon(Icons.open_in_new,
                                    size: 16),
                                label: Text('Join',
                                    style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                      color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: btnAction,
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : Icon(
                                      status == 'completed'
                                          ? Icons.star_outline_rounded
                                          : isReg
                                              ? Icons.check_circle_outline
                                              : Icons.how_to_reg_outlined,
                                      size: 16),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: status == 'completed'
                                    ? const Color(0xFFF59E0B)
                                    : isReg
                                        ? Colors.grey[200]
                                        : (!isOpen && !isReg)
                                            ? Colors.grey[300]
                                            : AppColors.primary,
                                foregroundColor: status == 'completed'
                                    ? Colors.white
                                    : isReg
                                        ? Colors.grey[700]
                                        : (!isOpen && !isReg)
                                            ? Colors.grey[600]
                                            : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                              ),
                              label: Text(
                                btnLabel,
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13),
                              ),
                            ),
                          ),
                        ]),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEMINAR DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SeminarDetailScreen extends StatefulWidget {
  final Map<String, dynamic> seminar;
  final SeminarRegistrationState regState;
  final Future<void> Function() onRegister;

  const SeminarDetailScreen({
    super.key,
    required this.seminar,
    required this.regState,
    required this.onRegister,
  });

  @override
  State<SeminarDetailScreen> createState() => _SeminarDetailScreenState();
}

class _SeminarDetailScreenState extends State<SeminarDetailScreen> {
  bool _registering   = false;
  bool _hasEvaluated  = false;
  bool _evalLoading   = false;
  bool _evalSubmitted = false;
  bool _checkingEval  = true;

  /// Auto-refresh timer: rebuilds every 30 s so status badge and
  /// evaluation section appear without manual reload.
  Timer? _statusTimer;

  final TextEditingController _commentCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _checkEvaluation();
    widget.regState.addListener(_onRegStateChanged);
    _statusTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _statusTimer?.cancel();
    widget.regState.removeListener(_onRegStateChanged);
    super.dispose();
  }

  void _onRegStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkEvaluation() async {
    setState(() => _checkingEval = true);
    final result =
        await DatabaseService.hasEvaluated(widget.seminar['id'] as String);
    if (mounted) {
      setState(() {
        _hasEvaluated = result;
        _checkingEval = false;
      });
    }
  }

  Future<void> _submitEvaluation() async {
    if (_scores.values.any((v) => v == 0)) {
      _showSnack('Please rate all criteria before submitting.',
          isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Submit Evaluation?',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark)),
        content: Text(
          'Once submitted, your evaluation cannot be changed. Are you sure?',
          style: GoogleFonts.nunito(
              fontSize: 13, color: Colors.grey[700], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: AppColors.textMid)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Submit',
                style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _evalLoading = true);
    final err = await DatabaseService.submitEvaluation(
      seminarId: widget.seminar['id'] as String,
      scores:    _scores,
      comments:  _commentCtrl.text,
    );

    if (!mounted) return;

    if (err == null) {
      setState(() {
        _hasEvaluated  = true;
        _evalSubmitted = true;
        _evalLoading   = false;
      });
    } else if (err == 'already_evaluated') {
      setState(() {
        _hasEvaluated = true;
        _evalLoading  = false;
      });
      _showSnack('You have already evaluated this seminar.');
    } else if (err == 'not_eligible') {
      setState(() => _evalLoading = false);
      _showSnack(
        'You are not eligible to evaluate this seminar. '
        'Only participants who registered before it started may evaluate.',
        isError: true,
      );
    } else {
      setState(() => _evalLoading = false);
      _showSnack('Submission failed. Please try again.', isError: true);
    }
  }

  Future<void> _handleRegister() async {
    if (_registering) return;
    setState(() => _registering = true);
    await widget.onRegister();
    if (mounted) setState(() => _registering = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: isError ? AppColors.danger : AppColors.primary,
    ));
  }

  String _scoreLabel(int score) {
    switch (score) {
      case 1:  return 'Poor';
      case 2:  return 'Fair';
      case 3:  return 'Good';
      case 4:  return 'Very Good';
      case 5:  return 'Excellent';
      default: return '';
    }
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
    final sem         = widget.seminar;
    final semId       = sem['id'] as String;
    final status      = _effectiveStatus(sem);
    final isReg       = widget.regState.isRegistered(semId);
    final isOpen      = _registrationOpen(sem);
    final type        = sem['seminar_type'] as String? ?? 'webinar';
    final title       = sem['title'] as String? ?? '';

    // Registration button visibility:
    // Show if: seminar not yet completed/cancelled AND (open OR already registered)
    final showRegBtn =
        status != 'completed' && status != 'cancelled';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F0),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: sem['cover_image_url'] != null ? 260 : 200,
          pinned: true,
          backgroundColor: AppColors.primaryDark,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          flexibleSpace: FlexibleSpaceBar(
            background: sem['cover_image_url'] != null
                ? Stack(fit: StackFit.expand, children: [
                    Image.network(
                      sem['cover_image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.primaryDark),
                    ),
                    Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ],
                    ))),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  _statusColor(status).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ])
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primary
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding:
                        const EdgeInsets.fromLTRB(20, 80, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                _statusColor(status).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type + registration badges
                Row(children: [
                  _TypeBadge(
                    icon: type == 'in_person'
                        ? Icons.location_on_outlined
                        : type == 'hybrid'
                            ? Icons.device_hub_outlined
                            : Icons.videocam_outlined,
                    text: type == 'in_person'
                        ? 'In Person'
                        : type == 'hybrid'
                            ? 'Hybrid'
                            : 'Webinar',
                  ),
                  const SizedBox(width: 8),
                  if (isReg)
                    const _TypeBadge(
                      icon: Icons.check_circle_outline,
                      text: 'Registered',
                      color: Color(0xFF16A34A),
                    ),
                  if (!isReg && !isOpen && status == 'upcoming')
                    const _TypeBadge(
                      icon: Icons.lock_outline,
                      text: 'Registration Closed',
                      color: Color(0xFFDC2626),
                    ),
                ]),
                const SizedBox(height: 20),

                // Details card
                _DetailCard(children: [
                  _DetailRow(
                    Icons.calendar_today_outlined,
                    'Start',
                    _fmtDate(sem['scheduled_start'] as String?),
                  ),
                  if (sem['scheduled_end'] != null)
                    _DetailRow(
                      Icons.flag_outlined,
                      'End',
                      _fmtDate(sem['scheduled_end'] as String?),
                    ),
                  if (sem['venue'] != null)
                    _DetailRow(
                        Icons.location_on_outlined, 'Venue', sem['venue']),
                  if (sem['webinar_link'] != null)
                    _DetailRow(
                      Icons.videocam_outlined,
                      'Platform',
                      _platformLabel(sem['webinar_platform'] as String?),
                    ),
                  _DetailRow(
                    Icons.group_outlined,
                    'Participants',
                    sem['max_participants'] != null
                        ? 'Max ${sem['max_participants']} participants'
                        : 'Unlimited',
                  ),
                ]),
                const SizedBox(height: 20),

                // Description
                if (sem['description'] != null &&
                    (sem['description'] as String).isNotEmpty) ...[
                  Text('About this Seminar',
                      style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6)
                      ],
                    ),
                    child: Text(
                      sem['description'],
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: const Color(0xFF444444),
                          height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Webinar link
                if (sem['webinar_link'] != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri =
                            Uri.parse(sem['webinar_link'] as String);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        'Join ${_platformLabel(sem['webinar_platform'] as String?)}',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 2),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Register / Cancel / Closed button ───────────────
                if (showRegBtn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: isOpen || isReg
                        ? ElevatedButton(
                            onPressed:
                                _registering ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReg
                                  ? Colors.grey[200]
                                  : AppColors.primary,
                              foregroundColor: isReg
                                  ? Colors.grey[700]
                                  : Colors.white,
                              disabledBackgroundColor: Colors.grey[200],
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: _registering
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary))
                                : Text(
                                    isReg
                                        ? 'Registered — Tap to Cancel'
                                        : 'Register for this Seminar',
                                    style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15),
                                  ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 15),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Registration Closed',
                                    style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        status == 'completed'
                            ? 'Seminar Completed'
                            : 'Seminar Cancelled',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Evaluation section ───────────────────────────────
                // Shows only when: completed + was registered
                if (status == 'completed' && isReg) ...[
                  if (_checkingEval)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8)
                        ],
                        border:
                            Border.all(color: const Color(0xFFE8F2D8)),
                      ),
                      child: (_hasEvaluated || _evalSubmitted)
                          ? _buildEvalDone()
                          : _buildEvalForm(),
                    ),
                  const SizedBox(height: 32),
                ] else
                  const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEvalDone() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Color(0xFF2D6A2D), size: 36),
          ),
          const SizedBox(height: 14),
          Text('Evaluation Submitted!',
              style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 6),
          Text(
            'Thank you for taking the time to evaluate this seminar. '
            'Your feedback helps us improve.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize: 13, color: Colors.grey[600], height: 1.5),
          ),
        ]),
      );

  Widget _buildEvalForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              const Icon(Icons.assignment_outlined,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seminar Evaluation Form',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    Text(
                      'Rate each criterion from 1 (Poor) to 5 (Excellent)',
                      style:
                          GoogleFonts.nunito(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          ..._evalLabels.entries.map((entry) {
            final key   = entry.key;
            final label = entry.value;
            final desc  = _evalDescs[key] ?? '';
            final score = _scores[key] ?? 0;
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark)),
                          Text(desc,
                              style: GoogleFonts.nunito(
                                  fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    if (score > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _scoreLabel(score),
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _scores[key] = star),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: score >= star
                                  ? AppColors.primary
                                  : const Color(0xFFF5F7F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: score >= star
                                    ? AppColors.primary
                                    : const Color(0xFFDDE8DD),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$star',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: score >= star
                                      ? Colors.white
                                      : Colors.grey[500],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[100], height: 1),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Additional Comments',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 4),
                Text('Optional — share any other feedback',
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  style: GoogleFonts.nunito(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Your comments here…',
                    hintStyle:
                        GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8F2D8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8F2D8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF6F9F0),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Text(
                      '${_scores.values.where((v) => v > 0).length} of ${_scores.length} criteria rated',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _evalLoading ? null : _submitEvaluation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _evalLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Submit Evaluation',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CALENDAR TAB
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarTab extends StatefulWidget {
  final SeminarRegistrationState regState;
  const _CalendarTab({required this.regState});
  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  List<Map<String, dynamic>> _allItems    = [];
  List<Map<String, dynamic>> _rawSeminars = [];
  bool     _loading  = true;
  DateTime _viewDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    widget.regState.addListener(_onRegStateChanged);
  }

  @override
  void dispose() {
    widget.regState.removeListener(_onRegStateChanged);
    super.dispose();
  }

  void _onRegStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.from('events').select('*').order('start_date'),
        _db
            .from('seminars')
            .select('*')
            .eq('is_public', true)
            .order('scheduled_start'),
      ]);
      final events        = List<Map<String, dynamic>>.from(results[0]);
      final seminars      = List<Map<String, dynamic>>.from(results[1]);
      final seminarEvents = seminars
          .map(_seminarToCalendarEvent)
          .where((e) => e['start_date'] != null)
          .toList();
      final merged = [...events, ...seminarEvents];
      merged.sort((a, b) {
        final aDate = (a['start_date'] as String? ?? '');
        final bDate = (b['start_date'] as String? ?? '');
        return aDate.compareTo(bDate);
      });
      if (mounted) {
        setState(() {
          _allItems    = merged;
          _rawSeminars = seminars;
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _itemsForDate(String dateStr) {
    return _allItems.where((e) {
      final s     = e['start_date'] as String? ?? '';
      final start = s.length >= 10 ? s.substring(0, 10) : s;
      final en    = (e['end_date'] as String?) ?? start;
      final end   = en.length >= 10 ? en.substring(0, 10) : en;
      return dateStr.compareTo(start) >= 0 &&
          dateStr.compareTo(end) <= 0;
    }).toList();
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.primary;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Color _itemColor(Map<String, dynamic> item) {
    if (item['_source'] == 'seminar') return const Color(0xFF2563EB);
    return _parseColor(item['color_hex'] as String?);
  }

  void _onUpcomingItemTap(
      BuildContext ctx, Map<String, dynamic> item) {
    if (item['_source'] == 'seminar') {
      final raw = item['_raw'] as Map<String, dynamic>;
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => SeminarDetailScreen(
            seminar:    raw,
            regState:   widget.regState,   // ← shared state, correct reg shown
            onRegister: () async {
              // Registration triggered from calendar detail:
              // delegate to the same logic used in _SeminarsTab
              final semId = raw['id'] as String;
              final isReg = widget.regState.isRegistered(semId);
              final isOpen = _registrationOpen(raw);
              final status = _effectiveStatus(raw);

              if (!isReg && (status == 'completed' || status == 'cancelled')) {
                return;
              }
              if (!isReg && !isOpen) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(
                      'Registration is closed — this seminar has already started.',
                      style: GoogleFonts.nunito(),
                    ),
                    backgroundColor: AppColors.danger,
                  ));
                }
                return;
              }

              final confirmed = await showDialog<bool>(
                context: ctx,
                builder: (dCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    isReg
                        ? 'Cancel Registration?'
                        : 'Register for Seminar?',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark),
                  ),
                  content: Text(
                    isReg
                        ? 'Cancel registration for "${raw['title']}"?'
                        : 'Register for "${raw['title']}"?\n\nYour profile snapshot will be saved.',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: Text('Cancel',
                          style: GoogleFonts.nunito(
                              color: AppColors.textMid)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReg
                            ? AppColors.danger
                            : AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        isReg ? 'Cancel Registration' : 'Register',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              if (isReg) {
                final err =
                    await DatabaseService.cancelRegistration(semId);
                if (err == null) widget.regState.remove(semId);
              } else {
                final err =
                    await DatabaseService.registerForSeminar(semId);
                if (err == null || err == 'already_registered') {
                  widget.regState.add(semId);
                }
              }
            },
          ),
        ),
      ).then((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    final year        = _viewDate.year;
    final month       = _viewDate.month;
    final firstDay    = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today       = DateTime.now();
    const monthNames  = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    final todayStr = today.toIso8601String().substring(0, 10);
    final upcoming = _allItems.where((e) {
      final s     = (e['start_date'] as String? ?? '');
      final start = s.length >= 10 ? s.substring(0, 10) : s;
      return start.compareTo(todayStr) >= 0;
    }).take(5).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _LegendDot(color: AppColors.primary, label: 'Events'),
          const SizedBox(width: 16),
          const _LegendDot(
              color: Color(0xFF2563EB), label: 'Seminars'),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8)
            ],
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: Colors.white),
                    onPressed: () => setState(() =>
                        _viewDate = DateTime(year, month - 1, 1)),
                  ),
                  Text(
                    '${monthNames[month - 1]} $year',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: Colors.white),
                    onPressed: () => setState(() =>
                        _viewDate = DateTime(year, month + 1, 1)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: ['S','M','T','W','T','F','S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d,
                                style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7, childAspectRatio: 0.9),
              itemCount: firstDay + daysInMonth,
              itemBuilder: (ctx, i) {
                if (i < firstDay) return const SizedBox();
                final day     = i - firstDay + 1;
                final dateStr =
                    '${year.toString().padLeft(4, '0')}-'
                    '${month.toString().padLeft(2, '0')}-'
                    '${day.toString().padLeft(2, '0')}';
                final isToday = day == today.day &&
                    month == today.month &&
                    year == today.year;
                final dayItems = _itemsForDate(dateStr);
                return Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary.withOpacity(0.1)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                            color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w500,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.primaryDark,
                        ),
                      ),
                      if (dayItems.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 2,
                          children: dayItems.take(3).map((e) =>
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _itemColor(e),
                                shape: BoxShape.circle,
                              ),
                            )).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Upcoming Events & Seminars',
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark)),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          const _EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No upcoming events',
              sub: 'Check back later')
        else
          ...upcoming.map((e) {
            final isSeminar   = e['_source'] == 'seminar';
            final accentColor = _itemColor(e);
            // Show registered chip for seminar items
            final semId = isSeminar
                ? (e['_raw'] as Map<String, dynamic>)['id'] as String?
                : null;
            final isReg =
                semId != null && widget.regState.isRegistered(semId);

            return GestureDetector(
              onTap: () => _onUpcomingItemTap(context, e),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                      left: BorderSide(
                          color: accentColor, width: 4)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 5)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(e['title'] ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark)),
                      ),
                      if (isReg)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Registered',
                              style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      const Color(0xFF16A34A))),
                        )
                      else if (isSeminar)
                        const Icon(Icons.chevron_right,
                            size: 16, color: Colors.grey),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      _fmtDateShort(e['start_date'] as String?) +
                          (e['end_date'] != null &&
                                  e['end_date'] != e['start_date']
                              ? ' — ${_fmtDateShort(e['end_date'] as String?)}'
                              : ''),
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: Colors.grey),
                    ),
                    if (e['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        e['description'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (e['event_type'] ?? 'event')
                            .toString()
                            .toUpperCase(),
                        style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _TypeBadge(
      {required this.icon, required this.text, this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? AppColors.primary),
          const SizedBox(width: 5),
          Text(text,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.primary)),
        ]),
      );
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Column(children: children),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: GoogleFonts.nunito(
                    fontSize: 12, color: Colors.grey[600])),
          ),
        ]),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12, color: Colors.grey[600])),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _EmptyState(
      {required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(title,
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}