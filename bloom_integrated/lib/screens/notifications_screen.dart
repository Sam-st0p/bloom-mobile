import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

final _supabase = Supabase.instance.client;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  Set<String> _readIds = {};
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

      final data = await _supabase
          .from('announcements')
          .select('*')
          .lte('published_at', DateTime.now().toIso8601String())
          .order('is_pinned', ascending: false)
          .order('published_at', ascending: false);

      Set<String> readIds = {};
      if (userId != null) {
        final reads = await _supabase
            .from('announcement_reads')
            .select('announcement_id')
            .eq('user_id', userId);
        readIds = (reads as List)
            .map((r) => r['announcement_id'].toString())
            .toSet();
      }

      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(data as List);
          _readIds = readIds;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String announcementId) async {
    if (_readIds.contains(announcementId)) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('announcement_reads').insert({
        'user_id': userId,
        'announcement_id': announcementId,
        'read_at': DateTime.now().toIso8601String(),
      });
      setState(() => _readIds.add(announcementId));
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final unread = _announcements
        .where((a) => !_readIds.contains(a['id'].toString()))
        .toList();
    for (final a in unread) {
      await _markRead(a['id'].toString());
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dt.toString().substring(0, 10);
  }

  int get _unreadCount =>
      _announcements.where((a) => !_readIds.contains(a['id'].toString())).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left, color: AppColors.textMid),
              ),
              Expanded(
                child: Row(children: [
                  Text('Notifications',
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.danger, borderRadius: BorderRadius.circular(20)),
                      child: Text('$_unreadCount',
                          style: GoogleFonts.nunito(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ]),
              ),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllRead,
                  child: Text('Mark all read',
                      style: GoogleFonts.nunito(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _announcements.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Column(children: [
                              const Icon(Icons.notifications_none_outlined,
                                  size: 48, color: AppColors.textLight),
                              const SizedBox(height: 12),
                              Text('No notifications yet',
                                  style: GoogleFonts.nunito(
                                      color: AppColors.textLight, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _announcements.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final a = _announcements[i];
                            final id = a['id'].toString();
                            final isRead = _readIds.contains(id);
                            final isPinned = a['is_pinned'] == true;

                            return GestureDetector(
                              onTap: () {
                                _markRead(id);
                                _showAnnouncementDetail(a);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white : AppColors.primary.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isPinned
                                        ? AppColors.primary.withOpacity(0.3)
                                        : isRead
                                            ? AppColors.border
                                            : AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: isPinned
                                            ? AppColors.primary.withOpacity(0.15)
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          isPinned ? Icons.push_pin : Icons.notifications_outlined,
                                          color: isPinned ? AppColors.primary : AppColors.textLight,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(a['title'] ?? '',
                                                    style: GoogleFonts.nunito(
                                                        fontWeight: isRead
                                                            ? FontWeight.w600
                                                            : FontWeight.w800,
                                                        fontSize: 14,
                                                        color: AppColors.textDark)),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8, height: 8,
                                                  decoration: const BoxDecoration(
                                                      color: AppColors.primary,
                                                      shape: BoxShape.circle),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(a['body'] ?? a['content'] ?? a['content'] ?? a['content'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.nunito(
                                                  fontSize: 12, color: AppColors.textLight)),
                                          const SizedBox(height: 6),
                                          Text(_timeAgo(a['published_at']),
                                              style: GoogleFonts.nunito(
                                                  fontSize: 11, color: AppColors.textLight)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  void _showAnnouncementDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            if (a['is_pinned'] == true)
              Row(children: [
                const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Pinned Announcement',
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ]),
            if (a['is_pinned'] == true) const SizedBox(height: 8),
            Text(a['title'] ?? '',
                style: GoogleFonts.nunito(
                    fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(a['body'] ?? a['content'] ?? a['content'] ?? a['content'] ?? '',
                style: GoogleFonts.nunito(
                    fontSize: 14, color: AppColors.textMid, height: 1.6)),
            const SizedBox(height: 16),
            Text(
              'Published ${_timeAgo(a['published_at'])}',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
