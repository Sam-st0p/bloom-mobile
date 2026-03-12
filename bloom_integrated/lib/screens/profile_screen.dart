import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

final _supabase = Supabase.instance.client;

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const ProfileScreen({super.key, required this.onSignOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  List<BadgeModel> _earnedBadges = [];
  List<CertificateModel> _certs = [];
  int _completedModules = 0;
  bool _loading = true;
  bool _editOpen = false;
  bool _saving = false;

  final _nameCtrl       = TextEditingController();
  final _studentIdCtrl  = TextEditingController();
  final _deptCtrl       = TextEditingController();
  int _yearLevel        = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

      final profile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      final badgeIds = await _supabase
          .from('student_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final earnedIds = Set<String>.from(
          (badgeIds as List).map((b) => b['badge_id'].toString()));

      final allBadges = await _supabase.from('badges').select('*');
      final earnedBadges = (allBadges as List)
          .where((b) => earnedIds.contains(b['id'].toString()))
          .map((b) => BadgeModel.fromMap(b, earned: true))
          .toList();

      final certs = await _supabase
          .from('certificates')
          .select('*')
          .eq('user_id', userId)
          .eq('is_revoked', false);

      final progress = await _supabase
          .from('module_progress')
          .select('status')
          .eq('user_id', userId)
          .eq('status', 'completed');

      if (mounted) {
        setState(() {
          _profileData = profile;
          _earnedBadges = earnedBadges;
          _certs = (certs as List).map((c) => CertificateModel.fromMap(c)).toList();
          _completedModules = (progress as List).length;

          // Pre-fill edit controllers
          _nameCtrl.text = profile?['full_name'] ?? '';
          _studentIdCtrl.text = profile?['student_id'] ?? '';
          _deptCtrl.text = profile?['department'] ?? '';
          _yearLevel = profile?['year_level'] ?? 1;
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
        'full_name': _nameCtrl.text.trim(),
        'student_id': _studentIdCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'year_level': _yearLevel,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await _load();
      if (mounted) setState(() => _editOpen = false);
    } catch (e) {
      // show error
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _supabase.auth.signOut();
    widget.onSignOut();
  }

  String get _displayName => _profileData?['full_name'] ?? 'Student';
  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }
  String get _department => _profileData?['department'] ?? '';
  String get _studentId => _profileData?['student_id'] ?? '';
  String get _yearLabel {
    final yr = _profileData?['year_level'] as int? ?? 0;
    if (yr == 0) return '';
    const suffixes = ['', '1st', '2nd', '3rd', '4th', '5th'];
    return yr <= 5 ? '${suffixes[yr]} Year' : '${yr}th Year';
  }

  @override
  Widget build(BuildContext context) {
    if (_editOpen) return _buildEditProfile();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 60),
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                    ),
                    child: Center(
                      child: Text(_initials,
                          style: const TextStyle(
                              fontSize: 28, color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_displayName,
                      style: GoogleFonts.nunito(
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
                ],
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ))
                    : Column(
                        children: [
                          // Stats
                          AppCard(
                            child: Row(children: [
                              _StatItem(value: '${_earnedBadges.length}', label: 'Badges', icon: '🏅'),
                              _divider(),
                              _StatItem(value: '${_certs.length}', label: 'Certificates', icon: '📜'),
                              _divider(),
                              _StatItem(value: '$_completedModules', label: 'Modules Done', icon: '✅'),
                            ]),
                          ),
                          const SizedBox(height: 12),

                          // Certificates
                          if (_certs.isNotEmpty) ...[
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionHeader(title: 'My Certificates', action: null, onAction: null),
                                  const SizedBox(height: 12),
                                  ..._certs.map((c) => _CertTile(cert: c)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Badges
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionHeader(title: 'My Badges', action: null, onAction: null),
                                const SizedBox(height: 12),
                                if (_earnedBadges.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('Complete modules to earn badges!',
                                          style: GoogleFonts.nunito(
                                              color: AppColors.textLight, fontSize: 13)),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: _earnedBadges.map((b) => _BadgePill(badge: b)).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Menu
                          AppCard(
                            child: Column(
                              children: [
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfile() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _editOpen = false),
                icon: const Icon(Icons.chevron_left, color: AppColors.textMid),
              ),
              Text('Edit Profile',
                  style: GoogleFonts.nunito(
                      fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditField(label: 'Full Name', controller: _nameCtrl, icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _EditField(label: 'Student ID', controller: _studentIdCtrl, icon: Icons.badge_outlined),
                    const SizedBox(height: 12),
                    _EditField(label: 'Department / Course', controller: _deptCtrl, icon: Icons.school_outlined),
                    const SizedBox(height: 12),
                    Text('Year Level',
                        style: GoogleFonts.nunito(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textMid, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        final yr = i + 1;
                        final selected = _yearLevel == yr;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _yearLevel = yr),
                            child: Container(
                              margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: selected ? AppColors.primary : AppColors.border,
                                    width: 1.5),
                              ),
                              child: Center(
                                child: Text('$yr',
                                    style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        color: selected ? Colors.white : AppColors.textMid,
                                        fontSize: 14)),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save Changes',
                          style: GoogleFonts.nunito(
                              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: AppColors.border);
}

class _StatItem extends StatelessWidget {
  final String value, label, icon;
  const _StatItem({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.nunito(
                fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
        Text(label, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
      ]),
    );
  }
}

class _CertTile extends StatelessWidget {
  final CertificateModel cert;
  const _CertTile({required this.cert});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('📜', style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cert.title,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
            Text('${cert.issuer} • ${cert.date}',
                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
          ]),
        ),
      ]),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final BadgeModel badge;
  const _BadgePill({required this.badge});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(badge.icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(badge.name,
            style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.textMid),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark))),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
        ]),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  const _EditField({required this.label, required this.controller, required this.icon});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: AppColors.textLight),
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        filled: true,
        fillColor: AppColors.background,
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
}