import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart' hide LibraryScreen;
import 'library_screen.dart';
import 'events_screen.dart';
import 'badges_screen.dart';
import 'forum_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onSignOut;
  const MainShell({super.key, required this.onSignOut});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final announcements = await Supabase.instance.client
          .from('announcements')
          .select('id')
          .lte('published_at', DateTime.now().toIso8601String());
      final reads = await Supabase.instance.client
          .from('announcement_reads')
          .select('announcement_id')
          .eq('user_id', userId);
      final readIds =
          (reads as List).map((r) => r['announcement_id'].toString()).toSet();
      final unread = (announcements as List)
          .where((a) => !readIds.contains(a['id'].toString()))
          .length;
      if (mounted) setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  void _navigateTo(int index) => setState(() => _currentIndex = index);

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    ).then((_) => _loadUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _navigateTo, onBellTap: _openNotifications, unreadCount: _unreadCount),
      const LibraryScreen(),
      const EventsScreen(),
      const BadgesScreen(),
      const ForumScreen(),
      ProfileScreen(onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0, currentIndex: _currentIndex, onTap: _navigateTo),
                _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Library', index: 1, currentIndex: _currentIndex, onTap: _navigateTo),
                _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Events', index: 2, currentIndex: _currentIndex, onTap: _navigateTo),
                _NavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events_rounded, label: 'Badges', index: 3, currentIndex: _currentIndex, onTap: _navigateTo),
                _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Forum', index: 4, currentIndex: _currentIndex, onTap: _navigateTo),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 5, currentIndex: _currentIndex, onTap: _navigateTo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, currentIndex;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? AppColors.primary : AppColors.textLight,
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.textLight,
                  letterSpacing: 0.2,
                )),
            const SizedBox(height: 3),
            if (active)
              Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}