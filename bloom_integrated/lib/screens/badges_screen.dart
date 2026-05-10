import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../theme/app_theme.dart';

final _db = Supabase.instance.client;

String _fmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) { return iso; }
}

// ─────────────────────────────────────────────────────────────────
//  BADGES SCREEN
// ─────────────────────────────────────────────────────────────────
class BadgesScreen extends StatefulWidget {
  final int initialTab;
  const BadgesScreen({super.key, this.initialTab = 0});
  @override State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _earnedBadges = [];
  List<Map<String, dynamic>> _allBadges    = [];
  List<Map<String, dynamic>> _certificates = [];
  String _fullName = '';
  bool   _loading  = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _load();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _db.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }

    final results = await Future.wait([
      _db.from('student_badges')
          .select('*, badges(id, name, description, icon_url, badge_type)')
          .eq('user_id', uid)
          .order('awarded_at', ascending: false),
      _db.from('badges').select('*').order('name'),
      _db.from('certificates')
          .select('id, user_id, certificate_code, reference_type, issued_at, is_revoked, body_text, sig1_name, sig1_title, sig2_name, sig2_title, theme_color')
          .eq('user_id', uid)
          .eq('is_revoked', false)
          .order('issued_at', ascending: false),
      _db.from('profiles').select('full_name').eq('id', uid).maybeSingle(),
    ]);

    setState(() {
      _earnedBadges = List<Map<String, dynamic>>.from(results[0] as List);
      _allBadges    = List<Map<String, dynamic>>.from(results[1] as List);
      _certificates = List<Map<String, dynamic>>.from(results[2] as List);
      _fullName = (results[3] as Map<String, dynamic>?)?['full_name'] as String? ?? '';
      _loading  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9F0),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              expandedHeight: topPadding + 160,
              pinned: true,
              backgroundColor: AppColors.primaryDark,
              automaticallyImplyLeading: false,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context))
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Achievements',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StatPill(
                                icon: Icons.military_tech_rounded,
                                text: '${_earnedBadges.length} Badge${_earnedBadges.length != 1 ? 's' : ''} Earned',
                              ),
                              const SizedBox(width: 10),
                              _StatPill(
                                icon: Icons.workspace_premium_rounded,
                                text: '${_certificates.length} Certificate${_certificates.length != 1 ? 's' : ''}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.military_tech_rounded, size: 16), text: 'Achievements'),
                  Tab(icon: Icon(Icons.workspace_premium_rounded, size: 16), text: 'Certificates'),
                ],
              ),
            ),
          ],
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(controller: _tabs, children: [
                  _BadgesTab(earnedBadges: _earnedBadges, allBadges: _allBadges),
                  _CertsTab(certificates: _certificates, fullName: _fullName),
                ]),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  BADGES TAB
// ─────────────────────────────────────────────────────────────────
class _BadgesTab extends StatelessWidget {
  final List<Map<String, dynamic>> earnedBadges;
  final List<Map<String, dynamic>> allBadges;
  const _BadgesTab({required this.earnedBadges, required this.allBadges});

  @override
  Widget build(BuildContext context) {
    final earnedIds = earnedBadges
        .map((b) => b['badge_id'] as String? ?? b['badges']?['id'] as String? ?? '')
        .toSet();

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (earnedBadges.isNotEmpty) ...[
        _SectionHeader(icon: Icons.military_tech_rounded,
            text: 'Earned Achievements (${earnedBadges.length})'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 1.1,
              crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: earnedBadges.length,
          itemBuilder: (ctx, i) {
            final sb    = earnedBadges[i];
            final badge = sb['badges'] as Map<String, dynamic>? ?? {};
            return _BadgeCard(
              name:        badge['name'] as String? ?? 'Badge',
              description: badge['description'] as String?,
              iconUrl:     badge['icon_url'] as String?,
              badgeType:   badge['badge_type'] as String?,
              awardedAt:   sb['awarded_at'] as String?,
              earned:      true,
            );
          },
        ),
        const SizedBox(height: 24),
      ],

      ...(() {
        final locked = allBadges
            .where((b) => !earnedIds.contains(b['id'] as String? ?? ''))
            .toList();
        if (locked.isEmpty) return <Widget>[];
        return <Widget>[
          _SectionHeader(icon: Icons.lock_outline_rounded,
              text: 'Locked Achievements (${locked.length})'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 1.1,
                crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: locked.length,
            itemBuilder: (ctx, i) => _BadgeCard(
              name:        locked[i]['name'] as String? ?? 'Badge',
              description: locked[i]['description'] as String?,
              iconUrl:     locked[i]['icon_url'] as String?,
              badgeType:   locked[i]['badge_type'] as String?,
              earned:      false,
            ),
          ),
        ];
      })(),

      if (earnedBadges.isEmpty && allBadges.isEmpty)
        const _EmptyState(
          icon: Icons.military_tech_outlined,
          title: 'No achievements yet',
          sub: 'Complete assessments and modules to earn achievements',
        ),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionHeader({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: AppColors.primaryDark),
    const SizedBox(width: 6),
    Text(text, style: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
  ]);
}

class _BadgeCard extends StatelessWidget {
  final String name;
  final String? description, iconUrl, badgeType, awardedAt;
  final bool earned;
  const _BadgeCard({
    required this.name, this.description, this.iconUrl,
    this.badgeType, this.awardedAt, required this.earned,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: earned ? Colors.white : Colors.white.withOpacity(0.6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: earned ? const Color(0xFFFDE047) : const Color(0xFFE5E7EB),
          width: earned ? 1.5 : 1),
      boxShadow: earned
          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]
          : null,
    ),
    padding: const EdgeInsets.all(14),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Stack(alignment: Alignment.topRight, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: earned ? const Color(0xFFFEF9C3) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: iconUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(iconUrl!,
                        width: 36, height: 36, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.military_tech_rounded, size: 28,
                            color: earned ? AppColors.primaryDark : Colors.grey)))
                : Icon(
                    earned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                    size: 28,
                    color: earned ? AppColors.primaryDark : Colors.grey),
          ),
        ),
        if (!earned)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle),
            child: const Icon(Icons.lock, size: 12, color: Colors.grey),
          ),
      ]),
      const SizedBox(height: 8),
      Text(name,
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: earned ? AppColors.primaryDark : Colors.grey[500])),
      if (awardedAt != null) ...[
        const SizedBox(height: 3),
        Text(_fmtDate(awardedAt), style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey)),
      ] else if (description != null) ...[
        const SizedBox(height: 3),
        Text(description!,
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey)),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  CERTIFICATES TAB
// ─────────────────────────────────────────────────────────────────
class _CertsTab extends StatelessWidget {
  final List<Map<String, dynamic>> certificates;
  final String fullName;
  const _CertsTab({required this.certificates, required this.fullName});

  String _certTitle(Map<String, dynamic> cert) {
    final refType = cert['reference_type'] as String? ?? 'manual';
    return refType == 'manual'
        ? 'Certificate of Achievement'
        : 'Certificate of ${refType[0].toUpperCase()}${refType.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    if (certificates.isEmpty) {
      return const _EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'No certificates yet',
          sub: 'Attend seminars and complete modules to earn certificates');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: certificates.length,
      itemBuilder: (ctx, i) {
        final cert = certificates[i];
        return GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => CertificateViewerScreen(cert: cert, fullName: fullName))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.07), blurRadius: 10,
                  offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.workspace_premium_outlined,
                        color: Colors.white, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BLOOM GAD · GADRC CvSU',
                        style: GoogleFonts.nunito(
                            fontSize: 9, color: Colors.white60,
                            letterSpacing: 1, fontWeight: FontWeight.w600)),
                    Text(_certTitle(cert),
                        style: GoogleFonts.nunito(
                            fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('VIEW',
                        style: GoogleFonts.nunito(
                            fontSize: 9, color: Colors.white,
                            fontWeight: FontWeight.w800, letterSpacing: 1))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('This certifies that',
                      style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text(fullName.isNotEmpty ? fullName : 'Recipient',
                      style: GoogleFonts.nunito(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Text('has successfully fulfilled the requirements of the BLOOM GAD e-Learning Program.',
                      style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[600], height: 1.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC8E6C9))),
                      child: Text(cert['certificate_code'] ?? '—',
                          style: GoogleFonts.nunito(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: AppColors.primary, letterSpacing: 1))),
                    const Spacer(),
                    Text('Issued ${_fmtDate(cert['issued_at'] as String?)}',
                        style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  CERTIFICATE VIEWER SCREEN
// ─────────────────────────────────────────────────────────────────
class CertificateViewerScreen extends StatefulWidget {
  final Map<String, dynamic> cert;
  final String fullName;
  const CertificateViewerScreen({super.key, required this.cert, required this.fullName});
  @override State<CertificateViewerScreen> createState() => _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<CertificateViewerScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  String get _certTitle {
    final refType = widget.cert['reference_type'] as String? ?? 'manual';
    return refType == 'manual'
        ? 'Certificate of Achievement'
        : 'Certificate of ${refType[0].toUpperCase()}${refType.substring(1)}';
  }
  String get _recipientName => widget.fullName.isNotEmpty ? widget.fullName : 'Recipient';
  String get _code     => widget.cert['certificate_code'] as String? ?? '—';
  String get _issued   => _fmtDate(widget.cert['issued_at'] as String?);
  String get _bodyText => widget.cert['body_text'] as String? ??
      'has successfully completed the requirements of the BLOOM GAD e-Learning Program and is hereby awarded this certificate in recognition of outstanding participation and commitment to Gender and Development advocacy.';
  String get _sig1Name  => widget.cert['sig1_name']  as String? ?? 'GAD Coordinator';
  String get _sig1Title => widget.cert['sig1_title'] as String? ?? 'Cavite State University';
  String get _sig2Name  => widget.cert['sig2_name']  as String? ?? 'GADRC Director';
  String get _sig2Title => widget.cert['sig2_title'] as String? ?? 'Cavite State University';

  Color get _themeColor {
    final c = widget.cert['theme_color'] as String?;
    if (c == null) return AppColors.primary;
    try { return Color(int.parse(c.replaceFirst('#', '0xff'))); }
    catch (_) { return AppColors.primary; }
  }

  /// Capture the RepaintBoundary as a high-res PNG
  Future<Uint8List?> _capturePng() async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image    = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Triggers a browser file download of the certificate PNG
  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception('Could not capture certificate.');

      final fileName =
          'BLOOM_GAD_${_code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.png';

      final blob   = html.Blob([bytes], 'image/png');
      final url    = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      _showSnack('✓ Certificate download started!', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Share icon on web — just re-triggers the download
  Future<void> _shareImage() => _saveToGallery();

  Future<void> _shareBytes(Uint8List bytes) async {
    final fileName =
        'BLOOM_GAD_${_code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.png';
    final blob   = html.Blob([bytes], 'image/png');
    final url    = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }





  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(fontSize: 13, color: Colors.white)),
      backgroundColor: isSuccess ? AppColors.primary : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final certW   = screenW - 32;
    final certH   = certW / 1.1;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_certTitle,
            style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          // Share button
          if (!_saving)
            IconButton(
              tooltip: 'Share',
              onPressed: _shareImage,
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            ),
          // Save to gallery button
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveToGallery,
              icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
              label: Text('Save',
                  style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8, maxScale: 4.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: RepaintBoundary(
              key: _repaintKey,
              child: SizedBox(
                width: certW, height: certH,
                child: CertificateCard(
                  certTitle: _certTitle, name: _recipientName,
                  code: _code, issued: _issued, bodyText: _bodyText,
                  sig1Name: _sig1Name, sig1Title: _sig1Title,
                  sig2Name: _sig2Name, sig2Title: _sig2Title,
                  themeColor: _themeColor,
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.primaryDark,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.pinch_outlined, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          Text('Pinch to zoom  ·  Tap Save to download',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.white54)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  CERTIFICATE CARD
// ─────────────────────────────────────────────────────────────────
class CertificateCard extends StatelessWidget {
  final String certTitle, name, code, issued, bodyText,
               sig1Name, sig1Title, sig2Name, sig2Title;
  final Color themeColor;
  const CertificateCard({super.key,
    required this.certTitle, required this.name,
    required this.code,      required this.issued,
    this.bodyText  = 'has successfully completed the requirements of the BLOOM GAD e-Learning Program and is hereby awarded this certificate in recognition of outstanding participation and commitment to Gender and Development advocacy.',
    this.sig1Name  = 'GAD Coordinator',
    this.sig1Title = 'Cavite State University',
    this.sig2Name  = 'GADRC Director',
    this.sig2Title = 'Cavite State University',
    this.themeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFAFDF6), Color(0xFFF0F7EC)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor, width: 6),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.25), blurRadius: 24,
            offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned.fill(child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(decoration: BoxDecoration(
              border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.circular(4))),
        )),
        ..._corners(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(children: [
                Text('CAVITE STATE UNIVERSITY',
                    style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800,
                        color: themeColor, letterSpacing: 2.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text('Gender and Development Resource Center (GADRC)',
                    style: GoogleFonts.nunito(fontSize: 8, color: Colors.grey[600], letterSpacing: 0.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Divider(color: themeColor.withOpacity(0.4), thickness: 1)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: themeColor, width: 1.5)),
                      child: Icon(Icons.eco_outlined, size: 12, color: themeColor))),
                  Expanded(child: Divider(color: themeColor.withOpacity(0.4), thickness: 1)),
                ]),
              ]),
              Column(children: [
                Text(certTitle,
                    style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('THIS IS TO CERTIFY THAT',
                    style: GoogleFonts.nunito(fontSize: 7, color: Colors.grey[500], letterSpacing: 3),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFC8E6C9), width: 2))),
                  child: Text(name,
                      style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.w700,
                          color: themeColor, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center)),
                const SizedBox(height: 8),
                Text(bodyText,
                    style: GoogleFonts.nunito(fontSize: 8, color: Colors.grey[600], height: 1.5),
                    textAlign: TextAlign.center, overflow: TextOverflow.clip),
              ]),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: CertSignatureBlock(title: sig1Name, sub: sig1Title)),
                  Flexible(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: themeColor, width: 2),
                          color: const Color(0xFFE8F5E9)),
                      child: Icon(Icons.verified_outlined, size: 16, color: themeColor)),
                    const SizedBox(height: 3),
                    Text('Certificate Code',
                        style: GoogleFonts.nunito(fontSize: 6, color: Colors.grey, letterSpacing: 0.5),
                        textAlign: TextAlign.center),
                    Text(code,
                        style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w800,
                            color: themeColor, letterSpacing: 1),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    Text('Issued: $issued',
                        style: GoogleFonts.nunito(fontSize: 6, color: Colors.grey[500]),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ])),
                  Expanded(child: CertSignatureBlock(title: sig2Name, sub: sig2Title)),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }

  List<Widget> _corners() {
    const size = 16.0;
    return [
      Positioned(top: 14, left: 14,     child: CertCorner(color: themeColor, size: size, flip: false, vert: false)),
      Positioned(top: 14, right: 14,    child: CertCorner(color: themeColor, size: size, flip: true,  vert: false)),
      Positioned(bottom: 14, left: 14,  child: CertCorner(color: themeColor, size: size, flip: false, vert: true)),
      Positioned(bottom: 14, right: 14, child: CertCorner(color: themeColor, size: size, flip: true,  vert: true)),
    ];
  }
}

class CertCorner extends StatelessWidget {
  final Color color;
  final double size;
  final bool flip, vert;
  const CertCorner({super.key, required this.color, required this.size, required this.flip, required this.vert});
  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: flip, flipY: vert,
    child: SizedBox(width: size, height: size,
        child: CustomPaint(painter: CertCornerPainter(color))));
}

class CertCornerPainter extends CustomPainter {
  final Color color;
  const CertCornerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, size.height), p);
  }
  @override bool shouldRepaint(_) => false;
}

class CertSignatureBlock extends StatelessWidget {
  final String title, sub;
  const CertSignatureBlock({super.key, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Divider(color: AppColors.primaryDark, thickness: 1),
      Text(title,
          style: GoogleFonts.nunito(fontSize: 7, fontWeight: FontWeight.w700,
              color: AppColors.primaryDark, letterSpacing: 0.3),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
      Text(sub,
          style: GoogleFonts.nunito(fontSize: 6, color: Colors.grey),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    ]);
}

// ─────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _EmptyState({required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey)),
      ]
      )
    )
  );
}