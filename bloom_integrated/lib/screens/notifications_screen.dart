import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'notification_provider.dart';

// ─────────────────────────────────────────────────────────────────
//  TYPE → ICON / COLOR / LABEL
// ─────────────────────────────────────────────────────────────────
IconData _notifIcon(String? type) {
  switch (type) {
    case 'announcement':         return Icons.campaign_outlined;
    case 'new_seminar':          return Icons.school_outlined;
    case 'new_module':           return Icons.menu_book_outlined;
    case 'new_assessment':       return Icons.quiz_outlined;
    case 'registration':         return Icons.how_to_reg_outlined;
    case 'new_certificate':      return Icons.workspace_premium_outlined;
    case 'new_achievement':      return Icons.emoji_events_outlined;
    case 'evaluation_available': return Icons.rate_review_outlined;
    case 'seminar_reminder':     return Icons.alarm_outlined;
    case 'event_reminder':       return Icons.event_outlined;
    case 'new_event':            return Icons.event_outlined;
    case 'account_deactivated':  return Icons.block_outlined;
    case 'account_reactivated':  return Icons.check_circle_outline;
    case 'role_changed':         return Icons.manage_accounts_outlined;
    case 'registration_removed': return Icons.person_remove_outlined;
    default:                     return Icons.notifications_outlined;
  }
}

Color _notifColor(String? type) {
  switch (type) {
    case 'announcement':         return AppColors.primary;
    case 'new_seminar':          return const Color(0xFF2563EB);
    case 'new_module':           return const Color(0xFFF59E0B);
    case 'new_assessment':       return const Color(0xFF0891B2);
    case 'registration':         return const Color(0xFF16A34A);
    case 'new_certificate':      return const Color(0xFF7C3AED);
    case 'new_achievement':      return const Color(0xFFD97706);
    case 'evaluation_available': return const Color(0xFFDC2626);
    case 'seminar_reminder':     return const Color(0xFFDC2626);
    case 'event_reminder':       return const Color(0xFFDC2626);
    case 'new_event':            return const Color(0xFF0891B2);
    case 'account_deactivated':  return const Color(0xFFDC2626);
    case 'account_reactivated':  return const Color(0xFF16A34A);
    case 'role_changed':         return const Color(0xFF7C3AED);
    case 'registration_removed': return const Color(0xFFF59E0B);
    default:                     return AppColors.textLight;
  }
}

String _notifLabel(String? type) {
  switch (type) {
    case 'announcement':         return 'Announcement';
    case 'new_seminar':          return 'New Seminar';
    case 'new_module':           return 'New Module';
    case 'new_assessment':       return 'Assessment';
    case 'registration':         return 'Registration';
    case 'new_certificate':      return 'Certificate';
    case 'new_achievement':      return 'Achievement';
    case 'evaluation_available': return 'Evaluation';
    case 'seminar_reminder':     return 'Reminder';
    case 'event_reminder':       return 'Reminder';
    case 'new_event':            return 'New Event';
    case 'account_deactivated':  return 'Account';
    case 'account_reactivated':  return 'Account';
    case 'role_changed':         return 'Role Update';
    case 'registration_removed': return 'Registration';
    default:                     return 'Notification';
  }
}

// ─────────────────────────────────────────────────────────────────
//  NAV RESULT — returned to MainShell via Navigator.pop()
//
//  Each value maps to a distinct destination in MainShell:
//    library      → tab index 1 (Library / Modules)
//    events       → tab index 2 (Events → Seminars sub-tab)
//    calendar     → tab index 2 (Events → Calendar sub-tab)  ← NEW
//    achievements → tab index 3 (Badges → Achievements sub-tab)
//    certificates → tab index 3 (Badges → Certificates sub-tab) ← NEW
// ─────────────────────────────────────────────────────────────────
enum NavResult { library, events, calendar, achievements, certificates }

// ─────────────────────────────────────────────────────────────────
//  NOTIFICATIONS SCREEN
// ─────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  bool _showUnread = false;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Tap: mark read + navigate ──────────────────────────────────
  void _handleTap(
      NotificationProvider provider, Map<String, dynamic> n) {
    final id   = n['id'].toString();
    final type = n['type'] as String?;

    // Mark read via provider — updates badge instantly everywhere
    if (n['is_read'] != true) provider.markRead(id);

    switch (type) {
      // ── Library tab ─────────────────────────────────────────────
      case 'new_module':
      case 'new_assessment':
        Navigator.pop(context, NavResult.library);
        break;

      // ── Events tab → Seminars sub-tab ───────────────────────────
      case 'new_seminar':
      case 'seminar_reminder':
      case 'evaluation_available':
        Navigator.pop(context, NavResult.events);
        break;

      // ── Events tab → Calendar sub-tab ───────────────────────────
      //    Kept separate so MainShell can switch to the calendar view
      case 'new_event':
      case 'event_reminder':
        Navigator.pop(context, NavResult.calendar);
        break;

      // ── Badges tab → Certificates sub-tab ───────────────────────
      case 'new_certificate':
        Navigator.pop(context, NavResult.certificates);
        break;

      // ── Badges tab → Achievements sub-tab ───────────────────────
      case 'new_achievement':
        Navigator.pop(context, NavResult.achievements);
        break;

      // ── Account / role changes → inline detail sheet ──────────
      case 'account_deactivated':
      case 'account_reactivated':
      case 'role_changed':
      case 'registration_removed':
      // ── Announcements + unknown → inline detail sheet ───────────
      case 'announcement':
      default:
        _showDetail(n);
        break;
    }
  }

  // ── Mark all read with confirmation ───────────────────────────
  Future<void> _markAllRead(NotificationProvider provider) async {
    final unread = provider.unreadCount;
    if (unread == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark all as read?',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w900, color: AppColors.textDark)),
        content: Text(
            'All $unread notification${unread > 1 ? "s" : ""} will be marked as read.',
            style: GoogleFonts.nunito(color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Mark all read',
                style: GoogleFonts.nunito(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) await provider.markAllRead();
  }

  // ── Detail bottom sheet ────────────────────────────────────────
  void _showDetail(Map<String, dynamic> n) {
    final type  = n['type'] as String?;
    final color = _notifColor(type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_notifIcon(type), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _notifLabel(type),
                  style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.4),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              n['title'] ?? '',
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark),
            ),
            if ((n['body'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                n['body'] as String,
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textMid,
                    height: 1.65),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _timeAgo(n['created_at'] as String?),
              style: GoogleFonts.nunito(
                  fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = NotificationProviderWidget.of(context);

    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final all      = provider.notifications;
        final unread   = provider.unreadCount;
        final loading  = provider.loading;
        final displayed =
            _showUnread ? all.where((n) => n['is_read'] != true).toList() : all;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(children: [
            // ── Header ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                top:    MediaQuery.of(context).padding.top + 8,
                left:   4,
                right:  16,
                bottom: 12,
              ),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.textMid, size: 28),
                ),
                Expanded(
                  child: Row(children: [
                    Text('Notifications',
                        style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark)),
                    if (unread > 0) ...[
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$unread',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ]),
                ),
                if (unread > 0)
                  TextButton(
                    onPressed: () => _markAllRead(provider),
                    style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10)),
                    child: Text('Mark all read',
                        style: GoogleFonts.nunito(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),

            // ── Filter: All / Unread ────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                _FilterChip(
                  label:    'All',
                  count:    all.length,
                  selected: !_showUnread,
                  onTap:    () => setState(() => _showUnread = false),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label:    'Unread',
                  count:    unread,
                  selected: _showUnread,
                  onTap:    () => setState(() => _showUnread = true),
                ),
              ]),
            ),

            const Divider(height: 1, color: AppColors.border),

            // ── List ───────────────────────────────────────────
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(
                            const Duration(milliseconds: 400));
                      },
                      color: AppColors.primary,
                      child: displayed.isEmpty
                          ? _EmptyState(showUnread: _showUnread)
                          : FadeTransition(
                              opacity: _fadeAnim,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: displayed.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final n      = displayed[i];
                                  final isRead = n['is_read'] == true;
                                  final type   = n['type'] as String?;
                                  final color  = _notifColor(type);

                                  return Dismissible(
                                    key: Key(n['id'].toString()),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) => provider.deleteNotification(n['id'].toString()),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                          SizedBox(height: 4),
                                          Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                    child: GestureDetector(
                                    onTap: () =>
                                        _handleTap(provider, n),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 250),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? Colors.white
                                            : color.withValues(alpha: 0.04),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isRead
                                              ? AppColors.border
                                              : color.withValues(alpha: 0.25),
                                          width: isRead ? 1 : 1.5,
                                        ),
                                        boxShadow: isRead
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: color
                                                      .withValues(alpha: 0.06),
                                                  blurRadius: 8,
                                                  offset:
                                                      const Offset(0, 2),
                                                )
                                              ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Icon bubble
                                          Container(
                                            width: 42, height: 42,
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                  alpha: isRead ? 0.08 : 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12),
                                            ),
                                            child: Icon(
                                                _notifIcon(type),
                                                color: color,
                                                size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          // Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Row(children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: color
                                                          .withValues(
                                                              alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  6),
                                                    ),
                                                    child: Text(
                                                      _notifLabel(type),
                                                      style: GoogleFonts
                                                          .nunito(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight
                                                                .w800,
                                                        color: color,
                                                        letterSpacing:
                                                            0.3,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          BoxDecoration(
                                                              color:
                                                                  color,
                                                              shape: BoxShape
                                                                  .circle),
                                                    ),
                                                ]),
                                                const SizedBox(height: 5),
                                                Text(
                                                  n['title'] ?? '',
                                                  style:
                                                      GoogleFonts.nunito(
                                                    fontWeight: isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.w800,
                                                    fontSize: 14,
                                                    color:
                                                        AppColors.textDark,
                                                  ),
                                                ),
                                                if ((n['body']
                                                            as String? ??
                                                        '')
                                                    .isNotEmpty) ...[
                                                  const SizedBox(
                                                      height: 3),
                                                  Text(
                                                    n['body'] as String,
                                                    maxLines: 2,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style:
                                                        GoogleFonts.nunito(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textLight,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 6),
                                                Text(
                                                  _timeAgo(n['created_at']
                                                      as String?),
                                                  style:
                                                      GoogleFonts.nunito(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .textLight),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.chevron_right,
                                              size: 18,
                                              color: AppColors.textLight),
                                        ],
                                      ),
                                    ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  FILTER CHIP
// ─────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int    count;
  final bool   selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textMid)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : AppColors.textLight)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool showUnread;
  const _EmptyState({required this.showUnread});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const SizedBox(height: 80),
      Center(
        child: Column(children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: AppColors.background, shape: BoxShape.circle),
            child: Icon(
              showUnread
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_outlined,
              size: 40,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            showUnread ? 'All caught up!' : 'No notifications yet',
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            showUnread
                ? 'You have no unread notifications.'
                : 'You\'ll be notified about new modules,\nseminars, and announcements.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.5),
          ),
        ]),
      ),
    ]);
  }
}