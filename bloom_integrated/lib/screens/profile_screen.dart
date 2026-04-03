import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import 'badges_screen.dart' show CertificateViewerScreen, CertificateCard;

final _supabase = Supabase.instance.client;

String _fmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) { return iso; }
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const ProfileScreen({super.key, required this.onSignOut});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  List<BadgeModel>              _earnedBadges    = [];
  List<Map<String, dynamic>>    _certificates    = [];
  List<Map<String, dynamic>>    _rawBadges       = [];  // raw DB rows for display
  int  _completedModules = 0;
  bool _loading  = true;
  bool _editOpen = false;
  bool _saving   = false;

  final _nameCtrl      = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _deptCtrl      = TextEditingController();
  int   _yearLevel     = 1;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

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
            .select('id, user_id, certificate_code, reference_type, issued_at, is_revoked, body_text, sig1_name, sig1_title, sig2_name, sig2_title, theme_color')
            .eq('user_id', userId)
            .eq('is_revoked', false)
            .order('issued_at', ascending: false),
        _supabase.from('module_progress')
            .select('status')
            .eq('user_id', userId)
            .eq('status', 'completed'),
      ]);

      final profile  = results[0] as Map<String, dynamic>?;
      final rawBadges = List<Map<String, dynamic>>.from(results[1] as List);
      final certs    = List<Map<String, dynamic>>.from(results[2] as List);
      final progress = results[3] as List;

      // Build BadgeModel list for backwards compat (stats + pill display)
      final earnedBadges = rawBadges.map((b) {
        final badge = b['badges'] as Map<String, dynamic>? ?? {};
        return BadgeModel.fromMap(badge, earned: true);
      }).toList();

      if (mounted) {
        setState(() {
          _profileData     = profile;
          _earnedBadges    = earnedBadges;
          _rawBadges       = rawBadges;
          _certificates    = certs;
          _completedModules = progress.length;
          _nameCtrl.text      = profile?['full_name'] ?? '';
          _studentIdCtrl.text = profile?['student_id'] ?? '';
          _deptCtrl.text      = profile?['department'] ?? '';
          _yearLevel          = profile?['year_level'] ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('profiles').update({
        'full_name':  _nameCtrl.text.trim(),
        'student_id': _studentIdCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'year_level': _yearLevel,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      await _load();
      if (mounted) setState(() => _editOpen = false);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _supabase.auth.signOut();
    widget.onSignOut();
  }

  String get _displayName  => _profileData?['full_name'] ?? 'Student';
  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }
  String get _department  => _profileData?['department'] ?? '';
  String get _studentId   => _profileData?['student_id'] ?? '';
  String get _yearLabel {
    final yr = _profileData?['year_level'] as int? ?? 0;
    if (yr == 0) return '';
    const s = ['','1st','2nd','3rd','4th','5th'];
    return yr <= 5 ? '${s[yr]} Year' : '${yr}th Year';
  }

  // ── Open full-screen certificate viewer ──────────────────────────
  void _openCertViewer(Map<String, dynamic> cert) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CertificateViewerScreen(cert: cert, fullName: _displayName),
    ));
  }

  // ── Open badge detail bottom sheet ──────────────────────────────
  void _openBadgeDetail(Map<String, dynamic> rawBadge) {
    final badge  = rawBadge['badges'] as Map<String, dynamic>? ?? {};
    final name   = badge['name'] as String? ?? 'Badge';
    final desc   = badge['description'] as String? ?? '';
    final icon   = badge['icon_url'] as String?;
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
          // Handle
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          // Badge icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE047), width: 2),
            ),
            child: Center(
              child: icon != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: Image.network(icon, width: 50, height: 50, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('🏅', style: TextStyle(fontSize: 40))))
                  : const Text('🏅', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: GoogleFonts.nunito(
              fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1A2E1A))),
          const SizedBox(height: 6),
          if (desc.isNotEmpty)
            Text(desc, style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10)),
            child: Text('Awarded on $awarded',
                style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2D6A2D))),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editOpen) return _buildEditProfile();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(children: [
          // ── Header gradient ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary]),
            ),
            padding: const EdgeInsets.fromLTRB(20, 54, 20, 60),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 3)),
                child: Center(child: Text(_initials,
                    style: const TextStyle(
                        fontSize: 28, color: Colors.white, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(height: 12),
              Text(_displayName, style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 4),
              if (_department.isNotEmpty || _studentId.isNotEmpty)
                Text(
                  [
                    if (_department.isNotEmpty) _department,
                    if (_yearLabel.isNotEmpty) _yearLabel,
                    if (_studentId.isNotEmpty) _studentId,
                  ].join(' • '),
                  style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.75), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('⚧ GAD Advocate',
                    style: GoogleFonts.nunito(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),

          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.primary)))
                  : Column(children: [

                      // ── Stats card ───────────────────────────────
                      AppCard(
                        child: Row(children: [
                          _StatItem(value: '${_earnedBadges.length}', label: 'Badges',    icon: '🏅'),
                          _divider(),
                          _StatItem(value: '${_certificates.length}', label: 'Certificates', icon: '📜'),
                          _divider(),
                          _StatItem(value: '$_completedModules',       label: 'Modules Done', icon: '✅'),
                        ]),
                      ),
                      const SizedBox(height: 12),

                      // ── Certificates horizontal scroll ───────────
                      _HorizontalSection(
                        title: '🏆 My Certificates',
                        count: _certificates.length,
                        emptyIcon: '🏆',
                        emptyText: 'Complete modules & seminars to earn certificates',
                        itemCount: _certificates.length,
                        itemBuilder: (i) => _CertPreviewCard(
                          cert: _certificates[i],
                          fullName: _displayName,
                          onTap: () => _openCertViewer(_certificates[i]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Badges horizontal scroll ─────────────────
                      _HorizontalSection(
                        title: '🏅 My Badges',
                        count: _rawBadges.length,
                        emptyIcon: '🏅',
                        emptyText: 'Complete assessments to earn badges',
                        itemCount: _rawBadges.length,
                        itemBuilder: (i) => _BadgePreviewCard(
                          rawBadge: _rawBadges[i],
                          onTap: () => _openBadgeDetail(_rawBadges[i]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Menu ─────────────────────────────────────
                      AppCard(
                        child: Column(children: [
                          _MenuRow(
                            icon: Icons.person_outline,
                            label: 'Edit Profile',
                            onTap: () => setState(() => _editOpen = true)),
                          _MenuRow(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            onTap: () {}),
                          _MenuRow(
                            icon: Icons.help_outline,
                            label: 'Help & Support',
                            onTap: () {}),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _handleSignOut,
                              icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
                              label: Text('Sign Out',
                                  style: GoogleFonts.nunito(
                                      color: AppColors.danger, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.danger, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEditProfile() {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(children: [
          IconButton(
            onPressed: () => setState(() => _editOpen = false),
            icon: const Icon(Icons.chevron_left, color: AppColors.textMid)),
          Text('Edit Profile', style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        ]),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _EditField(label: 'Full Name',           controller: _nameCtrl,      icon: Icons.person_outline),
            const SizedBox(height: 12),
            _EditField(label: 'Student ID',          controller: _studentIdCtrl, icon: Icons.badge_outlined),
            const SizedBox(height: 12),
            _EditField(label: 'Department / Course', controller: _deptCtrl,      icon: Icons.school_outlined),
            const SizedBox(height: 12),
            Text('Year Level', style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textMid, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(children: List.generate(5, (i) {
              final yr       = i + 1;
              final selected = _yearLevel == yr;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _yearLevel = yr),
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: 1.5)),
                  child: Center(child: Text('$yr', style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.textMid,
                      fontSize: 14))),
                ),
              ));
            })),
          ])),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Save Changes', style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          )),
        ],
      )),
    ]);
  }

  Widget _divider() => Container(width: 1, height: 40, color: AppColors.border);
}

// ─────────────────────────────────────────────────────────────────
//  HORIZONTAL SECTION WRAPPER
//  Shows a header with count, and a horizontal scroll of cards.
//  Falls back to an empty state if there are no items.
// ─────────────────────────────────────────────────────────────────
class _HorizontalSection extends StatelessWidget {
  final String title;
  final int count;
  final String emptyIcon;
  final String emptyText;
  final int itemCount;
  final Widget Function(int) itemBuilder;

  const _HorizontalSection({
    required this.title,
    required this.count,
    required this.emptyIcon,
    required this.emptyText,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Row(children: [
          Expanded(child: Text(title, style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark))),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
        ]),
        const SizedBox(height: 12),
        // Content
        if (itemCount == 0)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text(emptyIcon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(emptyText, style: GoogleFonts.nunito(
                  fontSize: 12, color: AppColors.textLight),
                  textAlign: TextAlign.center),
            ]),
          ))
        else
          SizedBox(
            height: 140,
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
}

// ─────────────────────────────────────────────────────────────────
//  CERTIFICATE PREVIEW CARD
//  Horizontal card showing a mini certificate preview.
//  Tapping opens CertificateViewerScreen (full-screen with download).
// ─────────────────────────────────────────────────────────────────
class _CertPreviewCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  final String fullName;
  final VoidCallback onTap;
  const _CertPreviewCard({
    required this.cert, required this.fullName, required this.onTap,
  });

  String get _certTitle {
    final refType = cert['reference_type'] as String? ?? 'manual';
    return refType == 'manual'
        ? 'Certificate of Achievement'
        : 'Certificate of ${refType[0].toUpperCase()}${refType.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final code   = cert['certificate_code'] as String? ?? '—';
    final issued = _fmtDate(cert['issued_at'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07), blurRadius: 8,
              offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Mini gradient header
          Container(
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A2E1A), Color(0xFF2D6A2D)],
                begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.workspace_premium_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(height: 2),
              Text('BLOOM GAD', style: GoogleFonts.nunito(
                  fontSize: 8, color: Colors.white60,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
            ])),
          ),
          // Body
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Text(_certTitle, style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2E1A)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(fullName.isNotEmpty ? fullName : 'Recipient',
                  style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      color: const Color(0xFF2D6A2D), fontStyle: FontStyle.italic),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // Code + tap hint
              Row(children: [
                Expanded(child: Text(code, style: GoogleFonts.nunito(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: const Color(0xFF2D6A2D), letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis)),
              ]),
              Row(children: [
                const Icon(Icons.touch_app_outlined, size: 10, color: Colors.grey),
                const SizedBox(width: 3),
                Text('Tap to view', style: GoogleFonts.nunito(
                    fontSize: 9, color: Colors.grey)),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  BADGE PREVIEW CARD
//  Horizontal card for a badge. Tapping shows a detail bottom sheet.
// ─────────────────────────────────────────────────────────────────
class _BadgePreviewCard extends StatelessWidget {
  final Map<String, dynamic> rawBadge;
  final VoidCallback onTap;
  const _BadgePreviewCard({required this.rawBadge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge    = rawBadge['badges'] as Map<String, dynamic>? ?? {};
    final name     = badge['name'] as String? ?? 'Badge';
    final iconUrl  = badge['icon_url'] as String?;
    final awardedAt = _fmtDate(rawBadge['awarded_at'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE047), width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06), blurRadius: 6,
              offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Badge icon
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: iconUrl != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Image.network(iconUrl,
                          width: 34, height: 34, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Text('🏅', style: TextStyle(fontSize: 26))))
                  : const Text('🏅', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2E1A)),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(awardedAt, style: GoogleFonts.nunito(
              fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  KEPT ORIGINAL HELPER WIDGETS (unchanged from original)
// ─────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value, label, icon;
  const _StatItem({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
      Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
    ]),
  );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.textMid),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: GoogleFonts.nunito(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark))),
        const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
      ]),
    ),
  );
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  const _EditField({required this.label, required this.controller, required this.icon});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(color: AppColors.textLight),
      prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
      filled: true, fillColor: AppColors.background,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    ),
  );
}