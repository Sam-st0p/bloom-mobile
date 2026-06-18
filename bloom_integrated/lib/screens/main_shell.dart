// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'events_screen.dart';
import 'badges_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'notification_provider.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onSignOut;
  const MainShell({super.key, required this.onSignOut});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Sub-tab hints passed to EventsScreen and BadgesScreen.
  // Stored as int to match the initialTab: int constructor parameter.
  // 0 = first tab (seminars / achievements), 1 = second tab (calendar / certificates)
  int _eventsInitialTab = 0;
  int _badgesInitialTab = 0;

  final _notifProvider = NotificationProvider();

  @override
  void initState() {
    super.initState();
    _notifProvider.init();
    _notifProvider.addListener(_onProviderChange);
  }

  @override
  void dispose() {
    _notifProvider.removeListener(_onProviderChange);
    _notifProvider.dispose();
    super.dispose();
  }

  void _onProviderChange() {
    if (mounted) setState(() {});
  }

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
      // Reset sub-tab hints to default when user taps nav bar directly
      if (index == 2) _eventsInitialTab = 0;
      if (index == 3) _badgesInitialTab = 0;
    });
  }

  void _openNotifications() {
    Navigator.push<NavResult>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationProviderWidget(
          provider: _notifProvider,
          child: const NotificationsScreen(),
        ),
      ),
    ).then((result) {
      if (result == null) return;
      switch (result) {
        // ── Library ────────────────────────────────────────────
        case NavResult.library:
          setState(() {
            _currentIndex = 1;
          });
          break;

        // ── Events tab → Seminars sub-tab (index 0) ───────────
        case NavResult.events:
          setState(() {
            _eventsInitialTab = 0;
            _currentIndex     = 2;
          });
          break;

        // ── Events tab → Calendar sub-tab (index 1) ───────────
        case NavResult.calendar:
          setState(() {
            _eventsInitialTab = 1;
            _currentIndex     = 2;
          });
          break;

        // ── Badges tab → Achievements sub-tab (index 0) ───────
        case NavResult.achievements:
          setState(() {
            _badgesInitialTab = 0;
            _currentIndex     = 3;
          });
          break;

        // ── Badges tab → Certificates sub-tab (index 1) ───────
        case NavResult.certificates:
          setState(() {
            _badgesInitialTab = 1;
            _currentIndex     = 3;
          });
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifProvider.unreadCount;

    final screens = [
      HomeScreen(
        onSwitchTab:         _navigateTo,
        onOpenNotifications: _openNotifications,
        unreadCount:         unreadCount,
        onJoinLive: (seminar) {
          // Land on the Seminars sub-tab of Events, same as the
          // notifications "events" result does.
          setState(() {
            _eventsInitialTab = 0;
            _currentIndex     = 2;
          });
        },
      ),
      const LibraryScreen(),
      EventsScreen(initialTab: _eventsInitialTab),
      BadgesScreen(initialTab: _badgesInitialTab),
      ProfileScreen(onSignOut: widget.onSignOut),
    ];

    return NotificationProviderWidget(
      provider: _notifProvider,
      child: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset:     const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _NavItem(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,           label: 'Home',         index: 0, currentIndex: _currentIndex, onTap: _navigateTo),
                  _NavItem(icon: Icons.menu_book_outlined,      activeIcon: Icons.menu_book_rounded,      label: 'Library',      index: 1, currentIndex: _currentIndex, onTap: _navigateTo),
                  _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Events',       index: 2, currentIndex: _currentIndex, onTap: _navigateTo),
                  _NavItem(icon: Icons.emoji_events_outlined,   activeIcon: Icons.emoji_events_rounded,   label: 'Achievement',  index: 3, currentIndex: _currentIndex, onTap: _navigateTo),
                  _NavItem(icon: Icons.person_outline_rounded,  activeIcon: Icons.person_rounded,         label: 'Profile',      index: 4, currentIndex: _currentIndex, onTap: _navigateTo),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData           icon, activeIcon;
  final String             label;
  final int                index, currentIndex;
  final void Function(int) onTap;

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
            Icon(
              active ? activeIcon : icon,
              color: active ? AppColors.primary : AppColors.textLight,
              size:  22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                color:         active ? AppColors.primary : AppColors.textLight,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            if (active)
              Container(
                width:  4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}