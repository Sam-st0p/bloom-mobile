// lib/utils/rate_limiter.dart
// BLOOM GAD Mobile App — Client-Side Rate Limiting

class RateLimiter {
  static final Map<String, _BucketState> _buckets = {};

  // ── Allow check (validation failures — does NOT count) ────
  /// Returns true if the action is ALLOWED.
  /// Use this for pre-checks only (e.g. already locked?).
  static bool allow(
    String key, {
    int maxAttempts  = 5,
    int windowSecs   = 60,
    int cooldownSecs = 30,
  }) {
    final now   = DateTime.now();
    final state = _buckets[key] ?? _BucketState();

    // Still in cooldown?
    if (state.lockedUntil != null && now.isBefore(state.lockedUntil!)) {
      return false;
    }

    // Cooldown expired — reset
    if (state.lockedUntil != null && now.isAfter(state.lockedUntil!)) {
      state.lockedUntil = null;
      state.attempts.clear();
    }

    _buckets[key] = state;
    return true;
  }

  // ── Record a real failure (auth failures only) ────────────
  /// Call this ONLY when a real authentication failure occurs.
  /// Returns true if this failure just triggered a lockout.
  static bool recordFailure(
    String key, {
    int maxAttempts  = 6,
    int windowSecs   = 60,
    int cooldownSecs = 30,
  }) {
    final now   = DateTime.now();
    final state = _buckets[key] ?? _BucketState();

    // Remove attempts outside the rolling window
    state.attempts.removeWhere(
      (t) => now.difference(t).inSeconds > windowSecs,
    );

    // Record this failure
    state.attempts.add(now);

    // Check if limit exceeded
    if (state.attempts.length >= maxAttempts) {
      state.lockedUntil = now.add(Duration(seconds: cooldownSecs));
      state.attempts.clear();
      _buckets[key] = state;
      return true; // just locked
    }

    _buckets[key] = state;
    return false; // not locked yet
  }

  // ── Is currently locked ───────────────────────────────────
  static bool isLocked(String key) {
    final now   = DateTime.now();
    final state = _buckets[key];
    if (state?.lockedUntil == null) return false;
    return now.isBefore(state!.lockedUntil!);
  }

  // ── Remaining cooldown ────────────────────────────────────
  static Duration? remainingCooldown(String key) {
    final now       = DateTime.now();
    final state     = _buckets[key];
    if (state?.lockedUntil == null) return null;
    final remaining = state!.lockedUntil!.difference(now);
    return remaining.isNegative ? null : remaining;
  }

  // ── Attempt count ─────────────────────────────────────────
  static int attemptCount(String key) {
    return _buckets[key]?.attempts.length ?? 0;
  }

  // ── Reset ─────────────────────────────────────────────────
  /// Call this on successful login to clear the counter.
  static void reset(String key) => _buckets.remove(key);
}

// ── Internal state ────────────────────────────────────────
class _BucketState {
  List<DateTime> attempts   = [];
  DateTime?      lockedUntil;
}