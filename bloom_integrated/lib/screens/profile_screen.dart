// lib/screens/profile_screen.dart
// BLOOM GAD Mobile App — Profile Screen (Production Ready)

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import 'badges_screen.dart' show CertificateViewerScreen, CertificateCard;
import 'help_screen.dart';

final _supabase = Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
//  CVSU DEPARTMENT / COURSE DATA
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<String>> kCvsuDeptCourses = {
  'College of Agriculture, Food Technology and Forestry': [
    'BS Agriculture', 'BS Food Technology', 'BS Forestry',
    'BS Agricultural Engineering',
  ],
  'College of Arts and Sciences': [
    'AB Communication', 'AB English Language Studies', 'BS Biology',
    'BS Mathematics', 'BS Psychology', 'BS Statistics',
  ],
  'College of Business Administration': [
    'BS Accountancy', 'BS Business Administration',
    'BS Entrepreneurship', 'BS Office Administration',
  ],
  'College of Criminal Justice Education': ['BS Criminology'],
  'College of Education': [
    'Bachelor of Elementary Education', 'Bachelor of Secondary Education',
    'Bachelor of Physical Education', 'Bachelor of Early Childhood Education',
    'BS Industrial Technology Education',
  ],
  'College of Engineering and Information Technology': [
    'BS Civil Engineering', 'BS Computer Engineering',
    'BS Electrical Engineering', 'BS Electronics Engineering',
    'BS Mechanical Engineering', 'BS Information Technology',
    'BS Computer Science',
  ],
  'College of Fisheries and Ocean Sciences': ['BS Fisheries'],
  'College of Hospitality and Institutional Management': [
    'BS Hotel and Restaurant Management', 'BS Tourism Management',
  ],
  'College of Nursing': ['BS Nursing'],
  'College of Veterinary Medicine and Biomedical Sciences': [
    'Doctor of Veterinary Medicine', 'BS Veterinary Technology',
  ],
  'Graduate School': [
    'Master of Arts in Education', 'Master in Business Administration',
    'Master of Science in Agriculture', 'Doctor of Philosophy',
  ],
};

const List<String> kYearLevels = [
  '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year',
];

// ─────────────────────────────────────────────────────────────────────────────
//  VALIDATORS
// ─────────────────────────────────────────────────────────────────────────────
String? _validateName(String? v, String field) {
  if (v == null || v.trim().isEmpty) return '$field is required.';
  final t = v.trim();
  if (t.length < 2)  return '$field must be at least 2 characters.';
  if (t.length > 50) return '$field must be 50 characters or less.';
  if (!RegExp(r"^[a-zA-ZÀ-ÿ\s'\-]+$").hasMatch(t))
    return '$field may only contain letters, spaces, hyphens and apostrophes.';
  return null;
}

String? _validateStudentId(String? v) {
  if (v == null || v.trim().isEmpty) return 'Student ID is required.';
  final t = v.trim();
  if (t.length < 5)  return 'Student ID must be at least 5 characters.';
  if (t.length > 20) return 'Student ID must be 20 characters or less.';
  if (!RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(t))
    return 'Student ID may only contain letters, numbers and hyphens.';
  return null;
}

String _sanitizeName(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

// ─────────────────────────────────────────────────────────────────────────────
//  DATE FORMATTER
// ─────────────────────────────────────────────────────────────────────────────
String _fmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) { return iso; }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CROSS-PLATFORM IMAGE PICKER
// ─────────────────────────────────────────────────────────────────────────────
Future<({Uint8List bytes, String mime, String ext})?> _pickImage() async {
  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();

  if (bytes.lengthInBytes > 2 * 1024 * 1024) {
    throw 'size';
  }

  final ext = picked.name.split('.').last.toLowerCase();
  final mime = ext == 'png'  ? 'image/png'
             : ext == 'webp' ? 'image/webp'
             : 'image/jpeg';

  return (bytes: bytes, mime: mime, ext: ext);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const ProfileScreen({super.key, required this.onSignOut});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>?      _profileData;
  List<BadgeModel>           _earnedBadges    = [];
  List<Map<String, dynamic>> _certificates    = [];
  List<Map<String, dynamic>> _rawBadges       = [];
  int  _completedModules = 0;
  bool _loading          = true;
  bool _editOpen         = false;
  bool _saving           = false;
  bool _uploadingAvatar  = false;
  String? _avatarUrl;
  int     _avatarCacheBust = 0;

  // ── Edit controllers ───────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _studentIdCtrl = TextEditingController();

  // ── Field errors ───────────────────────────────────────────────────────────
  String? _firstNameError;
  String? _lastNameError;
  String? _studentIdError;
  String? _deptError;
  String? _courseError;

  // ── Role / academic state ──────────────────────────────────────────────────
  String? _selectedRole;
  String? _selectedDept;
  String? _selectedCourse;
  String  _selectedYear = '1st Year';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  // ── Derived helpers ────────────────────────────────────────────────────────
  String get _displayName =>
      (_profileData?['full_name'] as String? ?? '').trim();

  String get _initials {
    if (_displayName.isEmpty) return '•';
    final parts = _displayName.split(' ')
        .where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _displayName[0].toUpperCase();
  }

  String get _roleLabel {
    final r = _profileData?['role'] as String? ?? '';
    return r.isEmpty ? '' : r[0].toUpperCase() + r.substring(1);
  }

  String get _joinedDate =>
      _fmtDate(_profileData?['created_at'] as String?);

  bool get _isStudent        => _selectedRole == 'student';
  bool get _isTeacherFaculty =>
      _selectedRole == 'teacher' || _selectedRole == 'faculty';
  bool get _requiresDept     => _isStudent || _isTeacherFaculty;

  bool get _isDirty {
    final fullName   = _profileData?['full_name'] as String? ?? '';
    final parts      = fullName.trim().split(' ')
        .where((p) => p.isNotEmpty).toList();
    final savedFirst = parts.isNotEmpty ? parts.first : '';
    final savedLast  = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return _firstNameCtrl.text.trim() != savedFirst ||
        _lastNameCtrl.text.trim()  != savedLast  ||
        _studentIdCtrl.text.trim() !=
            (_profileData?['student_id'] as String? ?? '') ||
        _selectedRole   != (_profileData?['role']       as String?) ||
        _selectedDept   != (_profileData?['department'] as String?) ||
        _selectedCourse != (_profileData?['course']     as String?);
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final results = await Future.wait([
        _supabase.from('profiles').select('*').eq('id', userId).maybeSingle(),
        _supabase.from('student_badges')
            .select('*, badges(id, name, description, icon_url, badge_type)')
            .eq('user_id', userId)
            .order('awarded_at', ascending: false),
        _supabase.from('certificates')
            .select('id, user_id, certificate_code, reference_type, '
                'issued_at, is_revoked, body_text, sig1_name, sig1_title, '
                'sig2_name, sig2_title, theme_color')
            .eq('user_id', userId)
            .eq('is_revoked', false)
            .order('issued_at', ascending: false),
        _supabase.from('module_progress')
            .select('status')
            .eq('user_id', userId)
            .eq('status', 'completed'),
      ]);

      final profile   = results[0] as Map<String, dynamic>?;
      final rawBadges = List<Map<String, dynamic>>.from(results[1] as List);
      final certs     = List<Map<String, dynamic>>.from(results[2] as List);
      final progress  = results[3] as List;

      final earnedBadges = rawBadges.map((b) {
        final badge = b['badges'] as Map<String, dynamic>? ?? {};
        return BadgeModel.fromMap(badge, earned: true);
      }).toList();

      final fullName  = profile?['full_name'] as String? ?? '';
      final parts     = fullName.trim().split(' ')
          .where((p) => p.isNotEmpty).toList();
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName  = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final savedDept   = profile?['department'] as String?;
      final savedCourse = profile?['course']     as String?;
      final rawYear     = profile?['year_level'];
      final savedYear   = rawYear is int
          ? kYearLevels[(rawYear).clamp(1, 5) - 1]
          : (rawYear as String? ?? '1st Year');

      if (mounted) {
        setState(() {
          _profileData      = profile;
          _earnedBadges     = earnedBadges;
          _rawBadges        = rawBadges;
          _certificates     = certs;
          _completedModules = progress.length;
          _avatarUrl        = profile?['avatar_url'] as String?;

          _firstNameCtrl.text = firstName;
          _lastNameCtrl.text  = lastName;
          _studentIdCtrl.text = profile?['student_id'] as String? ?? '';

          _selectedRole = profile?['role'] as String?;
          _selectedDept = (savedDept != null &&
              kCvsuDeptCourses.containsKey(savedDept)) ? savedDept : null;
          _selectedCourse = (_selectedDept != null &&
              savedCourse != null &&
              kCvsuDeptCourses[_selectedDept]!.contains(savedCourse))
              ? savedCourse : null;
          _selectedYear = kYearLevels.contains(savedYear)
              ? savedYear : '1st Year';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Avatar upload ──────────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;

    Uint8List? bytes;
    String mime = 'image/jpeg';
    String ext  = 'jpg';

    try {
      final result = await _pickImage();
      if (result == null) return;
      bytes = result.bytes;
      mime  = result.mime;
      ext   = result.ext;
    } catch (e) {
      if (e == 'size' && mounted)
        _showError('Image must be smaller than 2 MB.');
      return;
    }

    if (bytes == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final storagePath = 'avatars/$userId.$ext';
      await _supabase.storage.from('avatars').uploadBinary(
        storagePath, bytes,
        fileOptions: FileOptions(contentType: mime, upsert: true),
      );
      final publicUrl = _supabase.storage
          .from('avatars').getPublicUrl(storagePath);
      await _supabase.from('profiles').update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
      if (mounted) {
        setState(() {
          _avatarUrl       = publicUrl;
          _avatarCacheBust = DateTime.now().millisecondsSinceEpoch;
        });
        _showSuccess('Profile picture updated.');
      }
    } catch (_) {
      if (mounted) _showError('Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Role change ────────────────────────────────────────────────────────────
  Future<void> _onRoleTap(String newRole) async {
    if (newRole == _selectedRole) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Change Role?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(
          'Changing to "${newRole[0].toUpperCase()}${newRole.substring(1)}" '
          'will update your profile fields. Continue?',
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textMid, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textMid))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Change Role',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _selectedRole   = newRole;
        _deptError      = null;
        _courseError    = null;
        _studentIdError = null;
        if (newRole != 'student') {
          _selectedCourse = null;
          _selectedYear   = '1st Year';
          _studentIdCtrl.clear();
        }
        if (newRole != 'teacher' && newRole != 'faculty' &&
            newRole != 'student') {
          _selectedDept = null;
        }
      });
    }
  }

  // ── Validate all fields ────────────────────────────────────────────────────
  bool _validateAll() {
    final fnErr  = _validateName(_firstNameCtrl.text, 'First name');
    final lnErr  = _validateName(_lastNameCtrl.text,  'Last name');

    String? sidErr;
    String? deptErr;
    String? courseErr;

    if (_isStudent) {
      sidErr    = _validateStudentId(_studentIdCtrl.text);
      deptErr   = _selectedDept   == null ? 'Department is required.' : null;
      courseErr = _selectedCourse == null ? 'Course is required.'     : null;
    } else if (_isTeacherFaculty) {
      deptErr   = _selectedDept   == null ? 'Department is required.' : null;
    }

    setState(() {
      _firstNameError = fnErr;
      _lastNameError  = lnErr;
      _studentIdError = sidErr;
      _deptError      = deptErr;
      _courseError    = courseErr;
    });

    return fnErr     == null &&
           lnErr     == null &&
           sidErr    == null &&
           deptErr   == null &&
           courseErr == null;
  }

  // ── Handle back from edit screen ───────────────────────────────────────────
  Future<void> _handleEditBack() async {
    if (_isStudent) {
      final fnErr     = _validateName(_firstNameCtrl.text, 'First name');
      final lnErr     = _validateName(_lastNameCtrl.text,  'Last name');
      final sidErr    = _validateStudentId(_studentIdCtrl.text);
      final deptErr   = _selectedDept   == null ? 'Department is required.' : null;
      final courseErr = _selectedCourse == null ? 'Course is required.'     : null;
      final hasErrors = fnErr != null || lnErr != null || sidErr != null ||
                        deptErr != null || courseErr != null;
      if (hasErrors) {
        setState(() {
          _firstNameError = fnErr;
          _lastNameError  = lnErr;
          _studentIdError = sidErr;
          _deptError      = deptErr;
          _courseError    = courseErr;
        });
        _showError('Please complete all required fields before leaving.');
        return;
      }
    }

    if (_isTeacherFaculty) {
      final fnErr   = _validateName(_firstNameCtrl.text, 'First name');
      final lnErr   = _validateName(_lastNameCtrl.text,  'Last name');
      final deptErr = _selectedDept == null ? 'Department is required.' : null;
      final hasErrors = fnErr != null || lnErr != null || deptErr != null;
      if (hasErrors) {
        setState(() {
          _firstNameError = fnErr;
          _lastNameError  = lnErr;
          _deptError      = deptErr;
        });
        _showError('Please complete all required fields before leaving.');
        return;
      }
    }

    if (!_isDirty) {
      setState(() => _editOpen = false);
      return;
    }

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Unsaved Changes',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(
          'You have unsaved changes. What would you like to do?',
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textMid, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: Text('Keep Editing',
                style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Discard Changes',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (action == 'discard' && mounted) {
      await _load();
      setState(() => _editOpen = false);
    }
  }

  // ── Save profile ───────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_validateAll()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Save Changes?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(
          'Are you sure you want to save your profile changes?',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textMid))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Save',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final firstName = _sanitizeName(_firstNameCtrl.text);
      final lastName  = _sanitizeName(_lastNameCtrl.text);
      final fullName  = '$firstName $lastName';
      final rawIndex  = kYearLevels.indexOf(_selectedYear);
      final yearIndex = rawIndex >= 0 ? rawIndex + 1 : null;

      final Map<String, dynamic> payload = {
        'full_name':  fullName,
        'role':       _selectedRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (_isStudent) {
        payload['student_id'] = _studentIdCtrl.text.trim();
        payload['department'] = _selectedDept;
        payload['course']     = _selectedCourse;
        payload['year_level'] = yearIndex;
      } else if (_isTeacherFaculty) {
        payload['student_id'] = null;
        payload['department'] = _selectedDept;
        payload['course']     = null;
        payload['year_level'] = null;
      } else {
        payload['student_id'] = null;
        payload['department'] = null;
        payload['course']     = null;
        payload['year_level'] = null;
      }

      await _supabase.from('profiles').update(payload).eq('id', userId);

      await _load();
      if (mounted) {
        setState(() => _editOpen = false);
        _showSuccess('Profile updated successfully.');
      }
    } catch (_) {
      if (mounted) _showError('Failed to save changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(
          'Are you sure you want to sign out of BLOOM GADRC?',
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textMid))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } finally {
      widget.onSignOut();
    }
  }

  // ── Snackbars ──────────────────────────────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: AppColors.danger,
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: AppColors.primary,
    ));
  }

  // ── Badge detail sheet ─────────────────────────────────────────────────────
  void _openBadgeDetail(Map<String, dynamic> rawBadge) {
    final badge   = rawBadge['badges'] as Map<String, dynamic>? ?? {};
    final name    = badge['name']        as String? ?? 'Badge';
    final desc    = badge['description'] as String? ?? '';
    final icon    = badge['icon_url']    as String?;
    final awarded = _fmtDate(rawBadge['awarded_at'] as String?);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE047), width: 2),
            ),
            child: Center(child: icon != null
                ? ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: Image.network(icon, width: 50, height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.emoji_events_rounded,
                            size: 40, color: Color(0xFFF59E0B))))
                : const Icon(Icons.emoji_events_rounded,
                    size: 40, color: Color(0xFFF59E0B))),
          ),
          const SizedBox(height: 14),
          Text(name, style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2E1A))),
          const SizedBox(height: 6),
          if (desc.isNotEmpty)
            Text(desc,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10)),
            child: Text('Awarded on $awarded',
                style: GoogleFonts.poppins(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D6A2D))),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ── Avatar widgets ─────────────────────────────────────────────────────────
  Widget _buildAvatarView(double size) {
    final url = _avatarUrl;
    Widget inner = (url != null && url.isNotEmpty)
        ? Image.network('$url?v=$_avatarCacheBust',
            width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _initialsCircle(size, forHeader: true))
        : _initialsCircle(size, forHeader: true);
    return ClipOval(
        child: SizedBox(width: size, height: size, child: inner));
  }

  Widget _buildAvatarEdit() {
    final url = _avatarUrl;
    Widget inner = (url != null && url.isNotEmpty)
        ? Image.network('$url?v=$_avatarCacheBust',
            width: 100, height: 100, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _initialsCircle(100, forHeader: false))
        : _initialsCircle(100, forHeader: false);

    return Stack(children: [
      Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryDark, width: 3),
        ),
        child: ClipOval(child: inner),
      ),
      Positioned(
        bottom: 0, right: 0,
        child: GestureDetector(
          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: _uploadingAvatar
                ? const Padding(padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 16),
          ),
        ),
      ),
    ]);
  }

  Widget _initialsCircle(double size, {required bool forHeader}) =>
      Container(
        width: size, height: size,
        color: forHeader
            ? Colors.white.withOpacity(0.2)
            : AppColors.primaryDark.withOpacity(0.12),
        child: Center(child: Text(_initials,
            style: TextStyle(
                fontSize: size * 0.33,
                color: forHeader ? Colors.white : AppColors.primaryDark,
                fontWeight: FontWeight.w900))),
      );

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_editOpen) return _buildEditProfile();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [

          // ── Header ──────────────────────────────────────────────────
          ClipPath(
            clipper: _OvalBottomClipper(),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 48),
              child: Column(children: [
                Stack(children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 3),
                    ),
                    child: ClipOval(child: _buildAvatarView(96)),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _uploadingAvatar
                          ? null : _pickAndUploadAvatar,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primaryDark, width: 1.5),
                        ),
                        child: _uploadingAvatar
                            ? const Padding(padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                    color: AppColors.primaryDark,
                                    strokeWidth: 2))
                            : const Icon(Icons.camera_alt_outlined,
                                color: AppColors.primaryDark, size: 14),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(_displayName,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22)),
                if (_roleLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_roleLabel,
                      style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13)),
                ],
                const SizedBox(height: 10),

                // ✅ FIX 1: Constrain pills inside a width-limited container
                // to prevent the department pill from overflowing the screen.
                LayoutBuilder(
                  builder: (context, constraints) => ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8, runSpacing: 6,
                      children: [
                        if ((_profileData?['department'] as String? ?? '')
                            .isNotEmpty)
                          _InfoPill(
                              icon: Icons.school_outlined,
                              label: _profileData!['department'] as String,
                              // Allow pill text to truncate cleanly
                              maxWidth: constraints.maxWidth - 32),
                        _InfoPill(
                            icon: Icons.calendar_today_outlined,
                            label: 'Joined $_joinedDate'),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        color: AppColors.primary)))
                : Column(children: [

                    // Stats
                    AppCard(child: Row(children: [
                      _StatItem(
                          value: '${_earnedBadges.length}',
                          label: 'Badges',
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFFF59E0B)),
                      _vDivider(),
                      _StatItem(
                          value: '${_certificates.length}',
                          label: 'Certificates',
                          icon: Icons.workspace_premium_outlined,
                          color: AppColors.primary),
                      _vDivider(),
                      _StatItem(
                          value: '$_completedModules',
                          label: 'Modules',
                          icon: Icons.check_circle_outline,
                          color: AppColors.info),
                    ])),
                    const SizedBox(height: 12),

                    // Certificates
                    _HorizontalSection(
                      title: 'My Certificates',
                      titleIcon: Icons.workspace_premium_outlined,
                      count: _certificates.length,
                      emptyIcon: Icons.workspace_premium_outlined,
                      emptyText:
                          'Complete modules & seminars to earn certificates',
                      itemCount: _certificates.length,
                      itemBuilder: (i) => _CertPreviewCard(
                          cert: _certificates[i],
                          fullName: _displayName,
                          onTap: () {}),
                    ),
                    const SizedBox(height: 12),

                    // Badges
                    _HorizontalSection(
                      title: 'My Badges',
                      titleIcon: Icons.emoji_events_rounded,
                      count: _rawBadges.length,
                      emptyIcon: Icons.emoji_events_outlined,
                      emptyText: 'Complete assessments to earn badges',
                      itemCount: _rawBadges.length,
                      itemBuilder: (i) => _BadgePreviewCard(
                          rawBadge: _rawBadges[i],
                          onTap: () => _openBadgeDetail(_rawBadges[i])),
                    ),
                    const SizedBox(height: 12),

                    // Menu
                    AppCard(child: Column(children: [
                      _MenuRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Edit Profile',
                        onTap: () => setState(() => _editOpen = true),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _MenuRow(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const HelpScreen())),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleSignOut,
                          icon: const Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.danger),
                          label: Text('Sign Out',
                              style: GoogleFonts.poppins(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.danger, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ])),
                    const SizedBox(height: 24),
                  ]),
          ),
        ]),
      ),
    );
  }

  // ── EDIT PROFILE ───────────────────────────────────────────────────────────
  Widget _buildEditProfile() {
    final deptCourseList = _selectedDept != null
        ? kCvsuDeptCourses[_selectedDept] ?? <String>[]
        : <String>[];

    final bool showDept       = _requiresDept;
    final bool showCourseYear = _isStudent;
    final bool showStudentId  = _isStudent;

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleEditBack(),
      child: Column(children: [

        // ── Top bar ────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
              8, MediaQuery.of(context).padding.top + 8, 16, 12),
          child: Row(children: [
            IconButton(
              onPressed: _handleEditBack,
              icon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.textMid, size: 28)),
            Text('Edit Profile',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ── Avatar ──────────────────────────────────────────────
              Center(child: Column(children: [
                _buildAvatarEdit(),
                const SizedBox(height: 8),
                Text('Tap camera to change photo',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textLight)),
              ])),
              const SizedBox(height: 20),

              // ── Personal information ────────────────────────────────
              AppCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Personal Information'),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Expanded(child: _ValidatedField(
                      label: 'First Name *',
                      controller: _firstNameCtrl,
                      icon: Icons.person_outline_rounded,
                      error: _firstNameError,
                      onChanged: (_) => setState(() =>
                          _firstNameError = _validateName(
                              _firstNameCtrl.text, 'First name')),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ValidatedField(
                      label: 'Last Name *',
                      controller: _lastNameCtrl,
                      icon: Icons.person_outline_rounded,
                      error: _lastNameError,
                      onChanged: (_) => setState(() =>
                          _lastNameError = _validateName(
                              _lastNameCtrl.text, 'Last name')),
                    )),
                  ]),

                  if (showStudentId) ...[
                    const SizedBox(height: 12),
                    _ValidatedField(
                      label: 'Student ID *',
                      controller: _studentIdCtrl,
                      icon: Icons.badge_outlined,
                      error: _studentIdError,
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() =>
                          _studentIdError =
                              _validateStudentId(_studentIdCtrl.text)),
                    ),
                  ],
                ],
              )),
              const SizedBox(height: 12),

              // ── Role ────────────────────────────────────────────────
              AppCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Role'),
                  const SizedBox(height: 4),
                  Text('Tap to change — affects required fields.',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textLight)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      'student','teacher','faculty','speaker','guest',
                    ].map((r) {
                      final sel = _selectedRole == r;
                      return GestureDetector(
                        onTap: () => _onRoleTap(r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primaryDark
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primaryDark
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            r[0].toUpperCase() + r.substring(1),
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textMid),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_isStudent) ...[
                    const SizedBox(height: 10),
                    _RequiredFieldsHint(
                        text: 'Student role requires: Student ID, '
                            'Department, Course & Year Level'),
                  ] else if (_isTeacherFaculty) ...[
                    const SizedBox(height: 10),
                    _RequiredFieldsHint(
                        text: 'Teacher/Faculty role requires: Department'),
                  ],
                ],
              )),
              const SizedBox(height: 12),

              // ── Academic details ────────────────────────────────────
              if (showDept) ...[
                AppCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Academic Details'),
                    const SizedBox(height: 14),

                    _DropdownField<String>(
                      label: 'Department / College *',
                      icon: Icons.account_balance_outlined,
                      value: _selectedDept,
                      items: kCvsuDeptCourses.keys.toList(),
                      itemLabel: (d) => d,
                      error: _deptError,
                      onChanged: (d) => setState(() {
                        _selectedDept   = d;
                        _selectedCourse = null;
                        _deptError      = null;
                      }),
                    ),

                    if (showCourseYear) ...[
                      const SizedBox(height: 12),
                      _DropdownField<String>(
                        label: 'Course / Program *',
                        icon: Icons.school_outlined,
                        value: _selectedCourse,
                        items: deptCourseList,
                        itemLabel: (c) => c,
                        error: _courseError,
                        onChanged: _selectedDept == null
                            ? null
                            : (c) => setState(() {
                                  _selectedCourse = c;
                                  _courseError    = null;
                                }),
                        hint: _selectedDept == null
                            ? 'Select department first'
                            : 'Select course',
                      ),
                      const SizedBox(height: 12),
                      _DropdownField<String>(
                        label: 'Year Level *',
                        icon: Icons.calendar_today_outlined,
                        value: _selectedYear,
                        items: kYearLevels,
                        itemLabel: (y) => y,
                        onChanged: (y) => setState(
                            () => _selectedYear = y ?? '1st Year'),
                      ),
                    ],
                  ],
                )),
                const SizedBox(height: 12),
              ],

              // ── Save button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    disabledBackgroundColor:
                        AppColors.primaryDark.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Save Changes',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textMid, letterSpacing: 0.5));

  Widget _vDivider() =>
      Container(width: 1, height: 40, color: AppColors.border);
}

// ─────────────────────────────────────────────────────────────────────────────
//  REQUIRED FIELDS HINT
// ─────────────────────────────────────────────────────────────────────────────
class _RequiredFieldsHint extends StatelessWidget {
  final String text;
  const _RequiredFieldsHint({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded,
          color: AppColors.primary, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.primary, height: 1.4))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  INFO PILL  ✅ FIX 1 APPLIED HERE
//  Added `maxWidth` parameter so long department names truncate with ellipsis
//  instead of overflowing off-screen.
// ─────────────────────────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  // Optional max width so text truncates rather than overflows.
  final double? maxWidth;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) => Container(
    // ✅ Constrain the pill's total width when a maxWidth is supplied.
    constraints: maxWidth != null
        ? BoxConstraints(maxWidth: maxWidth!)
        : null,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 12),
      const SizedBox(width: 5),
      // ✅ Flexible so the text shrinks/truncates inside the row.
      Flexible(
        child: Text(
          label,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  VALIDATED TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _ValidatedField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? error;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  const _ValidatedField({
    required this.label,
    required this.controller,
    required this.icon,
    this.error,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: AppColors.textDark)),
      const SizedBox(height: 6),
      TextField(
        controller:   controller,
        onChanged:    onChanged,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
            fontSize: 14, color: AppColors.textDark),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 18),
          filled:     true,
          fillColor:  AppColors.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          errorText:     error,
          errorStyle:    GoogleFonts.poppins(fontSize: 11),
          errorMaxLines: 2,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null
                      ? AppColors.danger
                      : AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primaryDark, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.danger, width: 1.5)),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DROPDOWN FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? error;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
    this.error,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: AppColors.textDark)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        hint: Text(hint ?? 'Select',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textLight)),
        style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textDark),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 18),
          filled:    true,
          fillColor: onChanged == null
              ? AppColors.border.withOpacity(0.3)
              : AppColors.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          errorText:    error,
          errorStyle:   GoogleFonts.poppins(fontSize: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: error != null
                      ? AppColors.danger
                      : AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primaryDark, width: 1.5)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.danger, width: 1.5)),
        ),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel(item),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13)),
        )).toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  OVAL BOTTOM CLIPPER
// ─────────────────────────────────────────────────────────────────────────────
class _OvalBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const arcHeight = 50.0;
    return Path()
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..cubicTo(
        size.width * 0.75, size.height + arcHeight,
        size.width * 0.25, size.height + arcHeight,
        0, size.height,
      )
      ..close();
  }
  @override bool shouldReclip(_OvalBottomClipper old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  HORIZONTAL SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _HorizontalSection extends StatelessWidget {
  final String title;
  final IconData titleIcon;
  final int count;
  final IconData emptyIcon;
  final String emptyText;
  final int itemCount;
  final Widget Function(int) itemBuilder;

  const _HorizontalSection({
    required this.title,     required this.titleIcon,
    required this.count,     required this.emptyIcon,
    required this.emptyText, required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(titleIcon, size: 16, color: AppColors.textDark),
        const SizedBox(width: 6),
        Expanded(child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.textDark))),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
      ]),
      const SizedBox(height: 12),
      if (itemCount == 0)
        Center(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            Icon(emptyIcon, size: 32, color: AppColors.textLight),
            const SizedBox(height: 8),
            Text(emptyText,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textLight),
                textAlign: TextAlign.center),
          ]),
        ))
      else
        // ✅ FIX 2: Increased height from 140 → 150 to eliminate the
        // bottom 5 px overflow in _CertPreviewCard / _BadgePreviewCard.
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => itemBuilder(i),
          ),
        ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CERTIFICATE PREVIEW CARD  ✅ FIX 2 APPLIED HERE
//  Reduced internal spacing and font sizes so the card content fits cleanly
//  without overflowing its 150 px tall container.
// ─────────────────────────────────────────────────────────────────────────────
class _CertPreviewCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  final String fullName;
  final VoidCallback onTap;
  const _CertPreviewCard(
      {required this.cert, required this.fullName, required this.onTap});

  String get _title {
    final r = cert['reference_type'] as String? ?? 'manual';
    if (r == 'manual') return 'Certificate of\nAchievement';
    return 'Certificate of\n${r[0].toUpperCase()}${r.substring(1)}';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 110,
      // ✅ Let the card fill its parent height in the ListView instead of
      // having its own fixed height that may overflow.
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,          // ✅ slightly smaller icon box
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(
                Icons.workspace_premium_rounded,
                size: 28, color: Color(0xFF2D6A2D))),
          ),
          const SizedBox(height: 5),
          Text(_title,
              style: GoogleFonts.poppins(
                  fontSize: 10,              // ✅ 11 → 10 to free up space
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2E1A)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(_fmtDate(cert['issued_at'] as String?),
              style: GoogleFonts.poppins(
                  fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  BADGE PREVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BadgePreviewCard extends StatelessWidget {
  final Map<String, dynamic> rawBadge;
  final VoidCallback onTap;
  const _BadgePreviewCard({required this.rawBadge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge   = rawBadge['badges'] as Map<String, dynamic>? ?? {};
    final name    = badge['name']     as String? ?? 'Badge';
    final iconUrl = badge['icon_url'] as String?;
    final awarded = _fmtDate(rawBadge['awarded_at'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE047), width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: iconUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.network(iconUrl, width: 30, height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.emoji_events_rounded,
                            size: 26, color: Color(0xFFF59E0B))))
                : const Icon(Icons.emoji_events_rounded,
                    size: 26, color: Color(0xFFF59E0B))),
          ),
          const SizedBox(height: 5),
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2E1A)),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(awarded,
              style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAT ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem({required this.value, required this.label,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 22, color: color),
      const SizedBox(height: 4),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppColors.textDark)),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textLight)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU ROW
// ─────────────────────────────────────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.textMid),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: AppColors.textDark))),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textLight),
      ]),
    ),
  );
}