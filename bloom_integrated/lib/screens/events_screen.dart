import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _joiningId;
  bool _evalOpen = false;
  bool _evalSubmitted = false;
  int _rating = 0;
  final _evalCommentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_evalOpen) return _buildEvaluation();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📅 Events & Seminars',
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textLight,
                  labelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800),
                  unselectedLabelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800),
                  dividerColor: Colors.transparent,
                  tabs: const [Tab(text: '🎓 Seminars'), Tab(text: '📆 Events'), Tab(text: '📜 Certs')],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildSeminars(), _buildEvents(), _buildCertificates()],
          ),
        ),
      ],
    );
  }

  Widget _buildSeminars() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sampleSeminars.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = sampleSeminars[i];
        final isLive = s.type == 'Live';
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BadgeChip(
                    label: isLive ? '🔴 LIVE' : '📅 Upcoming',
                    color: isLive ? AppColors.danger : AppColors.info,
                  ),
                  Text('${s.participants} joining', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
              const SizedBox(height: 10),
              Text(s.title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('🎤 ${s.speaker} • ${s.date} ${s.time}',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMid)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _joiningId = _joiningId == s.id ? null : s.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLive ? AppColors.danger : AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(isLive ? 'Join Now 🔴' : 'Register',
                          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  if (isLive) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _evalOpen = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        foregroundColor: AppColors.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                      child: Text('Evaluate', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
              if (_joiningId == s.id) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_outlined, color: AppColors.info, size: 18),
                      const SizedBox(width: 10),
                      Text('Opening webinar... Please wait',
                          style: GoogleFonts.nunito(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvents() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Simple Calendar
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('March 2025', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    Row(
                      children: [
                        const Icon(Icons.chevron_left, color: AppColors.textLight),
                        const Icon(Icons.chevron_right, color: AppColors.textLight),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
                    child: Center(child: Text(d, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight))),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
                  itemCount: 31,
                  itemBuilder: (context, i) {
                    final highlighted = [7, 17, 24].contains(i);
                    final colors = [AppColors.accent, AppColors.purple, AppColors.primary];
                    final colorIdx = [7, 17, 24].indexOf(i);
                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: highlighted ? colors[colorIdx] : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500,
                              color: highlighted ? Colors.white : AppColors.textDark,
                            )),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...sampleEvents.map((ev) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: Color(ev.colorValue), borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(ev.date, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ev.title, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            BadgeChip(label: ev.category, color: Color(ev.colorValue)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCertificates() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sampleCertificates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = sampleCertificates[i];
        final color = Color(c.colorValue);
        return AppCard(
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 4))),
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.workspace_premium_outlined, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                      Text('${c.issuer} • ${c.date}', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: color),
                                foregroundColor: color,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text('👁️ View', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text('⬇️ Save', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvaluation() {
    if (_evalSubmitted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text('Thank You!', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text('Your feedback has been submitted to GADRC.', style: GoogleFonts.nunito(color: AppColors.textLight)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() { _evalOpen = false; _evalSubmitted = false; _rating = 0; }),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _evalOpen = false),
                icon: const Icon(Icons.chevron_left, color: AppColors.textMid),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seminar Evaluation', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    Text('GAD Summit 2025 • Help us improve', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Text('Overall Rating', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.star_rounded, size: 40, color: i < _rating ? const Color(0xFFFFBA08) : AppColors.border),
                        ),
                      )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...['Content Quality', 'Speaker Effectiveness', 'Overall Organization'].map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textDark, fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(
                        children: ['Poor', 'Fair', 'Good', 'Excellent'].map((opt) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.textMid,
                              ),
                              child: Text(opt, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              )),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comments & Suggestions', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _evalCommentCtrl,
                      maxLines: 4,
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts...',
                        hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _evalSubmitted = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Submit Evaluation', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}