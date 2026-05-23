// lib/utils/validators.dart
// BLOOM GAD — Input Validation & Sanitization

class AppValidators {

  // ── Name (first / last) ─────────────────────────────────────────────
  // Letters, spaces, apostrophes, hyphens only. 2–50 chars.
  static String? name(String? v, {String field = 'Name'}) {
    if (v == null || v.trim().isEmpty) return '$field is required.';
    final clean = v.trim();
    if (clean.length < 2)  return '$field must be at least 2 characters.';
    if (clean.length > 50) return '$field must be 50 characters or fewer.';
    if (!RegExp(r"^[a-zA-Z\s'\-]+$").hasMatch(clean)) {
      return '$field may only contain letters, spaces, hyphens, and apostrophes.';
    }
    return null;
  }

  // ── Email ────────────────────────────────────────────────────────────
  // Supports subdomains like @cvsu.edu.ph
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final clean = v.trim().toLowerCase();
    if (clean.length > 254) return 'Email address is too long.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(clean)) {
      return 'Please enter a valid email address.';
    }
    // Block obvious injection attempts
    if (_hasInjection(clean)) return 'Invalid email address.';
    return null;
  }

  // ── Password (signup) ────────────────────────────────────────────────
  // Min 8, max 128, uppercase + lowercase + number + special char
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8)   return 'Password must be at least 8 characters.';
    if (v.length > 128) return 'Password must be 128 characters or fewer.';
    if (!v.contains(RegExp(r'[A-Z]')))           return 'Include at least one uppercase letter.';
    if (!v.contains(RegExp(r'[a-z]')))           return 'Include at least one lowercase letter.';
    if (!v.contains(RegExp(r'[0-9]')))           return 'Include at least one number.';
    if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Include at least one special character (e.g. ! @ # \$).';
    }
    // Block common weak passwords
    const weak = ['password', 'qwerty', '12345678', 'letmein', 'welcome', 'abc123'];
    if (weak.any((w) => v.toLowerCase().contains(w))) {
      return 'Password is too common. Please choose a stronger password.';
    }
    return null;
  }

  // ── Password (login) ─────────────────────────────────────────────────
  // Only checks not empty — don't reveal password rules on login
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length > 128) return 'Invalid password.';
    return null;
  }

  // ── Confirm Password ─────────────────────────────────────────────────
  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password.';
    if (v != original) return 'Passwords do not match.';
    return null;
  }

  // ── Password strength score (0–5) ────────────────────────────────────
  static int passwordStrength(String v) {
    int score = 0;
    if (v.length >= 8)                                    score++;
    if (v.length >= 12)                                   score++;
    if (v.contains(RegExp(r'[A-Z]')))                     score++;
    if (v.contains(RegExp(r'[0-9]')))                     score++;
    if (v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))   score++;
    return score;
  }

  // ── Sanitize text input ──────────────────────────────────────────────
  // Strips HTML/script tags, trims whitespace
  static String sanitize(String v) {
    return v
        .replaceAll(RegExp(r'<[^>]*>'), '')   // strip HTML tags
        .replaceAll(RegExp(r'[<>"\x00]'), '') // strip dangerous chars
        .trim();
  }

  // ── Sanitize name specifically ───────────────────────────────────────
  static String sanitizeName(String v) {
    return v
        .replaceAll(RegExp(r"[^a-zA-Z\s\x27\-]"), "") // only safe name chars
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');            // collapse multiple spaces
  }

  // ── Normalize email ──────────────────────────────────────────────────
  static String normalizeEmail(String v) => sanitize(v).toLowerCase();

  // ── Injection check ──────────────────────────────────────────────────
  static bool _hasInjection(String v) {
    final lower = v.toLowerCase();
    const patterns = [
      '<script', 'javascript:', 'onerror=', 'onload=',
      'drop table', 'select *', 'insert into', '--',
    ];
    return patterns.any((p) => lower.contains(p));
  }

  // ── Generic field not empty ──────────────────────────────────────────
  static String? required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required.';
    return null;
  }
}