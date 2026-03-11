import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const ProfileScreen({super.key, required this.onSignOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StudentProfile? _profile;
  List<CertificateModel> _certs = [];
  List<BadgeModel> _badges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool cancelled = false;

    final profileData = await DatabaseService.fetchMyProfile();
    final certsData   = await DatabaseService.fetchMyCertificates();
    final badgesData  = await DatabaseService.fetchBadges();
    final earnedIds   = await DatabaseService.fetchMyBadgeIds();

    if (cancelled || !mounted) return;

    setState(() {
      _profile = profileData != null ? StudentProfile.fromMap(profileData) : null;
      _certs   = certsData.map((m) => CertificateModel.fromMap(m)).toList();
      _badges  = badgesData.map((m) => BadgeModel.fromMap(m, earned: earnedIds.contains(m['id']?.toString()))).toList();
      _loading = false;
    });

    // ignore cancelled flag — set it to avoid linter warning
    cancelled = true;
  }

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final user  = AuthService.currentUser;
    final name  = _profile?.fullName ?? user?.email ?? 'Student';
    final course = _profile?.courseYear ?? '';
    final sid   = _profile?.studentId ?? '';

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                    child: Text(
                      _profile?.initials ?? '👩‍🎓',
                      style: TextStyle(
                        fontSize: (_profile != null) ? 28 : 36,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 4),
                if (course.isNotEmpty || sid.isNotEmpty)
                  Text('$course${sid.isNotEmpty ? " • $sid" : ""}',
                      style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text('⚧ GAD Advocate', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),

          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  : Column(
                      children: [
                        // Stats row
                        AppCard(
                          child: Row(children: [
                            _StatItem(value: '${_badges.where((b) => b.earned).length}', label: 'Badges', icon: '🏅'),
                            _divider(),
                            _StatItem(value: '${_certs.length}', label: 'Certificates', icon: '📜'),
                            _divider(),
                            _StatItem(value: '0', label: 'Modules Done', icon: '✅'),
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
                              if (_badges.isEmpty)
                                _EmptyState(message: 'Complete modules to earn badges!')
                              else
                                Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: _badges.map((b) => _BadgePill(badge: b)).toList(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Sign out
                        AppCard(
                          child: Column(
                            children: [
                              _MenuRow(icon: Icons.person_outline, label: 'Edit Profile', onTap: () {}),
                              _MenuRow(icon: Icons.lock_outline, label: 'Change Password', onTap: () {}),
                              _MenuRow(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
                              _MenuRow(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _handleSignOut,
                                  icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
                                  label: Text('Sign Out', style: GoogleFonts.nunito(color: AppColors.danger, fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
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
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Color(cert.colorValue).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('📜', style: TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cert.title, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
          Text('${cert.issuer} • ${cert.date}', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
        ])),
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
        color: badge.earned ? Color(badge.colorValue).withOpacity(0.12) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badge.earned ? Color(badge.colorValue).withOpacity(0.4) : AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(badge.icon, style: TextStyle(fontSize: 14, color: badge.earned ? null : const Color(0x66000000))),
        const SizedBox(width: 6),
        Text(badge.name, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700,
            color: badge.earned ? AppColors.textDark : AppColors.textLight)),
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
          Expanded(child: Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark))),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 13)),
      ),
    );
  }
}
