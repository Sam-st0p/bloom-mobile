/// Formats a full name to proper case: "john dela cruz" → "John Dela Cruz"
String formatFullName(String raw) {
  return raw.trim().split(RegExp(r'\s+')).map((w) {
    if (w.isEmpty) return '';
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

/// Normalizes student ID: strips spaces, forces uppercase
String formatStudentId(String raw) => raw.trim().toUpperCase().replaceAll(' ', '');

/// Validates student ID — customize pattern to match your institution's format
/// Example: "2023-12345" or "BSIT-2023-001"
bool isValidStudentId(String id) {
  return RegExp(r'^\d{4}-\d{4,6}$').hasMatch(id)
      || RegExp(r'^[A-Z]+-\d{4}-\d{3,6}$').hasMatch(id);
}

/// Validates that a name has at least first + last name
bool isValidFullName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.length >= 2 && parts.every((p) => p.length >= 2);
}

const List<String> kDepartments = [
  'BS Information Technology',
  'BS Computer Science',
  'BS Accountancy',
  'BS Business Administration',
  'BS Education',
  'BS Nursing',
  'BS Engineering',
  'BS Psychology',
  'BS Tourism Management',
  'Other',
];

const List<int> kYearLevels = [1, 2, 3, 4, 5];

String yearLevelLabel(int yr) {
  const s = ['', '1st', '2nd', '3rd', '4th', '5th'];
  return yr <= 5 ? '${s[yr]} Year' : '${yr}th Year';
}