class AppValidators {
  // Email — supports subdomains like @cvsu.edu.ph
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final clean = v.trim().toLowerCase();
    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(clean)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  // Password strength (for sign up)
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8)           return 'Password must be at least 8 characters.';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Include at least one uppercase letter.';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Include at least one number.';
    return null;
  }

  // Password for login — only checks not empty
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    return null;
  }

  // Password strength score (0–4) for visual indicator
  static int passwordStrength(String v) {
    int score = 0;
    if (v.length >= 8)                        score++;
    if (v.contains(RegExp(r'[A-Z]')))         score++;
    if (v.contains(RegExp(r'[0-9]')))         score++;
    if (v.contains(RegExp(r'[!@#\$%^&*]')))  score++;
    return score;
  }

  // Sanitize: strip HTML-like content from text inputs
  static String sanitize(String v) =>
      v.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}