import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _notifications = [];
  bool _loading  = true;
  bool _disposed = false;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription<AuthState>?                  _authSub;

  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((n) => n['is_read'] != true).length;

  bool get loading => _loading;

  void init() {
    _subscribeRealtime();

    // ── Re-subscribe whenever auth state changes (login / token refresh) ──
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        reinit();
      } else if (event == AuthChangeEvent.signedOut) {
        _sub?.cancel();
        _sub = null;
        _notifications = [];
        _loading = false;
        if (!_disposed) notifyListeners();
      }
    });
  }

  void _subscribeRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _sub?.cancel();
    _loading = true;
    if (!_disposed) notifyListeners();

    _sub = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .listen(
          (rows) {
            if (_disposed) return;
            _notifications = List<Map<String, dynamic>>.from(rows);
            _loading       = false;
            notifyListeners();
          },
          onError: (_) {
            if (_disposed) return;
            _loading = false;
            notifyListeners();
          },
        );
  }

  Future<void> markRead(String id) async {
    final idx = _notifications.indexWhere((n) => n['id'].toString() == id);
    if (idx == -1) return;
    if (_notifications[idx]['is_read'] == true) return;

    // ── Optimistic update ─────────────────────────────────────────────────
    _notifications = List.from(_notifications)
      ..[idx] = {..._notifications[idx], 'is_read': true};
    if (!_disposed) notifyListeners();

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (_) {
      // ── Rollback on failure ───────────────────────────────────────────
      _notifications = List.from(_notifications)
        ..[idx] = {..._notifications[idx], 'is_read': false};
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (!_notifications.any((n) => n['is_read'] != true)) return;

    // ── Optimistic update ─────────────────────────────────────────────────
    _notifications =
        _notifications.map((n) => {...n, 'is_read': true}).toList();
    if (!_disposed) notifyListeners();

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {
      // ── Rollback: re-fetch from DB ────────────────────────────────────
      _subscribeRealtime();
    }
  }

  Future<void> deleteNotification(String id) async {
    // Optimistic remove
    final prev = List<Map<String, dynamic>>.from(_notifications);
    _notifications = _notifications.where((n) => n['id'].toString() != id).toList();
    if (!_disposed) notifyListeners();
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } catch (_) {
      // Rollback on failure
      _notifications = prev;
      if (!_disposed) notifyListeners();
    }
  }

  void reinit() {
    _notifications = [];
    _loading       = true;
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class NotificationProviderWidget extends InheritedWidget {
  final NotificationProvider provider;

  const NotificationProviderWidget({
    super.key,
    required this.provider,
    required super.child,
  });

  static NotificationProvider of(BuildContext context) {
    final w = context
        .dependOnInheritedWidgetOfExactType<NotificationProviderWidget>();
    assert(w != null, 'NotificationProviderWidget not found in widget tree.');
    return w!.provider;
  }

  @override
  bool updateShouldNotify(NotificationProviderWidget old) => true;
}