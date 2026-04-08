// lib/utils/validators.dart
// BLOOM GAD Mobile App — Input Validators & Password Strength

class AppValidators {
  // ── Email ─────────────────────────────────────────────────
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final clean = v.trim().toLowerCase();
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$').hasMatch(clean)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  // ── Password (for signup) ─────────────────────────────────
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!v.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one uppercase letter.';
    }
    if (!v.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number.';
    }
    return null;
  }

  // ── Password strength score (0–4) ─────────────────────────
  // Used to drive the visual strength bar in signup_screen.dart
  // 0 = empty, 1 = weak, 2 = fair, 3 = good, 4 = strong
  static int passwordStrength(String v) {
    if (v.isEmpty) return 0;
    int score = 0;
    if (v.length >= 8)                           score++;
    if (v.contains(RegExp(r'[A-Z]')))            score++;
    if (v.contains(RegExp(r'[0-9]')))            score++;
    if (v.contains(RegExp(r'[!@#\$%^&*()_+]'))) score++;
    return score;
  }

  // ── Password strength label ───────────────────────────────
  static String passwordStrengthLabel(int score) {
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    if (score < 0 || score > 4) return '';
    return labels[score];
  }

  // ── Login password (less strict — just non-empty) ─────────
  // Don't validate strength on login — only on signup
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    return null;
  }

  // ── Required field (generic) ──────────────────────────────
  static String? required(String? v, String fieldName) {
    if (v == null || v.trim().isEmpty) return '$fieldName is required.';
    return null;
  }

  // ── Sanitize: strips HTML-like tags from any text input ───
  // Prevents basic injection through text fields
  static String sanitize(String v) =>
      v.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}