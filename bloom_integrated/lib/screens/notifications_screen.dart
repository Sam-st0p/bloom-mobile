import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

final _db = Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────
//  NOTIFICATION MODEL
// ─────────────────────────────────────────────────────────────────
class _NotifItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime time;
  final bool isPinned;
  final Map<String, dynamic> raw;

  _NotifItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isPinned = false,
    required this.raw,
  });

  IconData get icon {
    switch (type) {
      case 'announcement':  return isPinned ? Icons.push_pin : Icons.campaign_outlined;
      case 'seminar':       return Icons.school_outlined;
      case 'event':         return Icons.event_outlined;
      case 'badge':         return Icons.emoji_events_outlined;
      case 'certificate':   return Icons.workspace_premium_outlined;
      case 'assessment':    return Icons.quiz_outlined;
      case 'new_assessment':return Icons.assignment_outlined;
      default:              return Icons.notifications_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'announcement':  return AppColors.primary;
      case 'seminar':       return const Color(0xFF7C3AED);
      case 'event':         return const Color(0xFF2563EB);
      case 'badge':         return const Color(0xFFF59E0B);
      case 'certificate':   return const Color(0xFF16A34A);
      case 'assessment':    return const Color(0xFFDC2626);
      case 'new_assessment':return const Color(0xFFDC2626);
      default:              return AppColors.primary;
    }
  }

  String get label {
    switch (type) {
      case 'announcement':  return 'Announcement';
      case 'seminar':       return 'Seminar';
      case 'event':         return 'Event';
      case 'badge':         return 'Badge Earned';
      case 'certificate':   return 'Certificate';
      case 'assessment':    return 'Assessment Result';
      case 'new_assessment':return 'New Assessment';
      default:              return 'Notification';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  NOTIFICATIONS SCREEN
// ─────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  final void Function(String type, Map<String, dynamic> data)? onNavigate;
  const NotificationsScreen({super.key, this.onNavigate});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<_NotifItem> _items  = [];
  Set<String>      _readIds = {}; // stores item IDs that have been read (all types)
  bool             _loading = true;
  String           _filter  = 'all';

  @override void initState() { super.initState(); _loadReadIds().then((_) => _load()); }

  // ── Read state via SharedPreferences (works for ALL types, not just announcements) ──

  String _prefsKey() {
    final uid = _db.auth.currentUser?.id ?? 'guest';
    return 'notif_read_ids_$uid';
  }

  Future<void> _loadReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey()) ?? [];
      setState(() => _readIds = stored.toSet());
    } catch (_) {}
  }

  Future<void> _saveReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey(), _readIds.toList());
    } catch (_) {}
  }

  Future<void> _markRead(String itemId) async {
    if (_readIds.contains(itemId)) return;
    setState(() => _readIds.add(itemId));
    await _saveReadIds();

    // Also write to announcement_reads table for announcements (server-side tracking)
    if (itemId.startsWith('ann_')) {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;
      final announcementId = itemId.replaceFirst('ann_', '');
      try {
        await _db.from('announcement_reads').upsert({
          'user_id': uid,
          'announcement_id': announcementId,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,announcement_id', ignoreDuplicates: true);
      } catch (_) {}
    }
  }

  Future<void> _markAllRead() async {
    final unreadIds = _items
        .where((i) => !_readIds.contains(i.id))
        .map((i) => i.id)
        .toList();

    if (unreadIds.isEmpty) return;

    setState(() => _readIds.addAll(unreadIds));
    await _saveReadIds();

    // Write announcement reads to DB
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final annIds = unreadIds.where((id) => id.startsWith('ann_')).toList();
    for (final id in annIds) {
      final announcementId = id.replaceFirst('ann_', '');
      try {
        await _db.from('announcement_reads').upsert({
          'user_id': uid,
          'announcement_id': announcementId,
          'read_at': now,
        }, onConflict: 'user_id,announcement_id', ignoreDuplicates: true);
      } catch (_) {}
    }
  }

  bool _isRead(_NotifItem item) => _readIds.contains(item.id);
  int get _unreadCount => _items.where((i) => !_isRead(i)).length;

  // ── Load all notification sources ────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _db.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final results = await Future.wait([
        // 1. Announcements
        _db.from('announcements').select('*')
            .eq('is_published', true)
            .not('published_at', 'is', null)
            .lte('published_at', now)
            .or('expires_at.is.null,expires_at.gte.$now')
            .inFilter('target_audience', ['all', 'students'])
            .order('is_pinned', ascending: false)
            .order('published_at', ascending: false),

        // 2. Seminars (public, upcoming/ongoing)
        _db.from('seminars')
            .select('id, title, description, scheduled_start, seminar_type, created_at')
            .eq('is_public', true)
            .inFilter('status', ['upcoming', 'ongoing'])
            .order('created_at', ascending: false)
            .limit(10),

        // 3. Upcoming calendar events
        _db.from('events').select('*')
            .gte('start_date', today)
            .order('start_date')
            .limit(10),

        // 4. Student's earned badges
        _db.from('student_badges').select('*, badges(name, description)')
            .eq('user_id', uid)
            .order('awarded_at', ascending: false)
            .limit(10),

        // 5. Student's certificates
        _db.from('certificates').select('*')
            .eq('user_id', uid)
            .eq('is_revoked', false)
            .order('issued_at', ascending: false)
            .limit(10),

        // 6. Student's assessment attempts (results)
        _db.from('assessment_attempts').select('*, assessments(title, module_id)')
            .eq('user_id', uid)
            .order('submitted_at', ascending: false)
            .limit(10),

        // 7. Published assessments (new, available to take)
        _db.from('assessments')
            .select('id, title, created_at, passing_score, time_limit_minutes, module_id')
            .eq('is_published', true)
            .order('created_at', ascending: false)
            .limit(20),
      ]);

      final announcements  = results[0] as List;
      final seminars       = results[1] as List;
      final events         = results[2] as List;
      final badges         = results[3] as List;
      final certs          = results[4] as List;
      final attempts       = results[5] as List;
      final newAssessments = results[6] as List;

      // IDs of assessments student already attempted
      final attemptedAsmIds = attempts
          .map((a) => a['assessment_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final items = <_NotifItem>[];

      // Announcements
      for (final a in announcements) {
        final t = _parseTime(a['published_at'] as String?);
        if (t == null) continue;
        items.add(_NotifItem(
          id:       'ann_${a['id']}',
          type:     'announcement',
          title:    a['title'] ?? 'Announcement',
          body:     a['body'] ?? a['content'] ?? '',
          time:     t,
          isPinned: a['is_pinned'] == true,
          raw:      Map<String, dynamic>.from(a),
        ));
      }

      // Seminars
      for (final s in seminars) {
        final t = _parseTime(s['created_at'] as String?);
        if (t == null) continue;
        final st = s['seminar_type'] as String? ?? 'webinar';
        final stLabel = st == 'in_person' ? 'In Person' : st == 'hybrid' ? 'Hybrid' : 'Webinar';
        items.add(_NotifItem(
          id:   'sem_${s['id']}',
          type: 'seminar',
          title:'New Seminar: ${s['title'] ?? ''}',
          body: '$stLabel · ${_formatDate(s['scheduled_start'] as String?)}',
          time: t,
          raw:  Map<String, dynamic>.from(s),
        ));
      }

      // Events
      for (final e in events) {
        final t = _parseTime(e['created_at'] as String? ?? e['start_date'] as String?);
        if (t == null) continue;
        items.add(_NotifItem(
          id:   'evt_${e['id']}',
          type: 'event',
          title: e['title'] ?? 'Event',
          body: '${(e['event_type'] as String? ?? 'event').toUpperCase()} · ${_formatDateShort(e['start_date'] as String?)}',
          time: t,
          raw:  Map<String, dynamic>.from(e),
        ));
      }

      // Badges
      for (final b in badges) {
        final t = _parseTime(b['awarded_at'] as String?);
        if (t == null) continue;
        final name = (b['badges'] as Map?)?['name'] ?? 'Badge';
        items.add(_NotifItem(
          id:   'bdg_${b['id']}',
          type: 'badge',
          title:'You earned a badge!',
          body: name,
          time: t,
          raw:  Map<String, dynamic>.from(b),
        ));
      }

      // Certificates
      for (final c in certs) {
        final t = _parseTime(c['issued_at'] as String?);
        if (t == null) continue;
        final refType = c['reference_type'] as String? ?? 'manual';
        items.add(_NotifItem(
          id:   'crt_${c['id']}',
          type: 'certificate',
          title:'Certificate Issued!',
          body: 'Certificate of ${refType[0].toUpperCase()}${refType.substring(1)} · ${c['certificate_code'] ?? ''}',
          time: t,
          raw:  Map<String, dynamic>.from(c),
        ));
      }

      // Assessment results
      for (final a in attempts) {
        final t = _parseTime(a['submitted_at'] as String?);
        if (t == null) continue;
        final title  = (a['assessments'] as Map?)?['title'] ?? 'Assessment';
        final passed = a['passed'] == true;
        items.add(_NotifItem(
          id:   'asmnt_${a['id']}',
          type: 'assessment',
          title: passed ? 'You passed "$title"!' : 'Assessment Result: "$title"',
          body: 'Score: ${a['score'] ?? 0}% · ${passed ? 'Passed' : 'Failed'}',
          time: t,
          raw:  Map<String, dynamic>.from(a),
        ));
      }

      // New assessments available
      for (final a in newAssessments) {
        final aId = a['id']?.toString() ?? '';
        if (attemptedAsmIds.contains(aId)) continue;
        final t = _parseTime(a['created_at'] as String?);
        if (t == null) continue;
        items.add(_NotifItem(
          id:   'newasm_$aId',
          type: 'new_assessment',
          title:'New Assessment: ${a['title'] ?? 'Assessment'}',
          body: 'Passing score: ${a['passing_score'] ?? 75}% · Time limit: ${a['time_limit_minutes'] ?? 30} min',
          time: t,
          raw:  Map<String, dynamic>.from(a),
        ));
      }

      // Sort: pinned first, then newest
      items.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.time.compareTo(a.time);
      });

      setState(() { _items = items; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  DateTime? _parseTime(String? iso) {
    if (iso == null) return null;
    try {
      final s = iso.endsWith('Z') || iso.contains('+') ? iso : '${iso}Z';
      return DateTime.parse(s).toLocal();
    } catch (_) { return null; }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final t = _parseTime(iso);
    if (t == null) return '—';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final min = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '${m[t.month-1]} ${t.day}, ${t.year} · $h:$min $ap';
  }

  String _formatDateShort(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month-1]} ${d.day}, ${d.year}';
    } catch (_) { return iso; }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[t.month-1]} ${t.day}';
  }

  List<_NotifItem> get _filtered {
    if (_filter == 'all')        return _items;
    if (_filter == 'unread')     return _items.where((i) => !_isRead(i)).toList();
    if (_filter == 'assessment') return _items.where((i) => i.type == 'assessment' || i.type == 'new_assessment').toList();
    return _items.where((i) => i.type == _filter).toList();
  }

  void _showDetail(_NotifItem item) {
    _markRead(item.id);

    // Navigable types — close and deep link
    const navigable = ['new_assessment', 'seminar', 'event', 'badge', 'certificate', 'assessment'];
    if (navigable.contains(item.type) && widget.onNavigate != null) {
      Navigator.pop(context);
      widget.onNavigate!(item.type, item.raw);
      return;
    }

    // Announcement — show bottom sheet detail
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: item.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(item.icon, color: item.color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(item.label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: item.color))),
              const SizedBox(height: 2),
              Text(_timeAgo(item.time), style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
            ])),
          ]),
          const SizedBox(height: 16),
          Text(item.title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2D4A18))),
          const SizedBox(height: 8),
          Text(item.body, style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey[600], height: 1.6)),
          if ((item.raw['body'] ?? item.raw['content'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF6F9F0), borderRadius: BorderRadius.circular(12)),
              child: Text(item.raw['body'] ?? item.raw['content'] ?? '',
                style: GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF444444), height: 1.6))),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final unread   = _unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F0),
      body: Column(children: [
        // Header
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 12),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.chevron_left, color: Color(0xFF2D4A18)),
            ),
            Expanded(child: Row(children: [
              Text('Notifications',
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2D4A18))),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20)),
                  child: Text('$unread',
                    style: GoogleFonts.nunito(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ])),
            if (unread > 0)
              TextButton(
                onPressed: _markAllRead,
                child: Text('Mark all read',
                  style: GoogleFonts.nunito(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),

        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [
                ('all',          'All'),
                ('unread',       'Unread'),
                ('announcement', 'Announcements'),
                ('seminar',      'Seminars'),
                ('event',        'Events'),
                ('badge',        'Badges'),
                ('certificate',  'Certificates'),
                ('assessment',   'Assessments'),
              ]) _FilterChip(
                label: f.$2,
                selected: _filter == f.$1,
                onTap: () => setState(() => _filter = f.$1),
              ),
            ]),
          ),
        ),

        const Divider(height: 1),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? _EmptyState(filter: _filter)
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final read = _isRead(item);
                          return GestureDetector(
                            onTap: () => _showDetail(item),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: read ? Colors.white : item.color.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: item.isPinned
                                      ? item.color.withOpacity(0.4)
                                      : read ? const Color(0xFFE8F2D8) : item.color.withOpacity(0.2),
                                ),
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: item.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(item.icon, color: item.color, size: 20)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: item.color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(item.label,
                                        style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: item.color)),
                                    ),
                                    const Spacer(),
                                    Text(_timeAgo(item.time),
                                      style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
                                    if (!read) ...[
                                      const SizedBox(width: 6),
                                      Container(width: 8, height: 8,
                                        decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                                    ],
                                  ]),
                                  const SizedBox(height: 5),
                                  Text(item.title,
                                    style: GoogleFonts.nunito(
                                      fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                                      fontSize: 13,
                                      color: const Color(0xFF2D4A18),
                                    )),
                                  const SizedBox(height: 3),
                                  Text(item.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600])),
                                ])),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Colors.grey[600])),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.notifications_none_outlined, size: 52, color: Colors.grey),
      const SizedBox(height: 12),
      Text(filter == 'unread' ? 'All caught up!' : 'No notifications yet',
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[600])),
      const SizedBox(height: 6),
      Text(
        filter == 'unread' ? 'You have no unread notifications.' : 'Notifications will appear here.',
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
      ),
    ]),
  ));
}