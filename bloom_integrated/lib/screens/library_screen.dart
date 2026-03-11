import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  ModuleModel? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _buildModuleDetail(_selected!);

    final filtered = sampleModules.where((m) => m.title.toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📚 Module Library',
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = filtered[i];
              return GestureDetector(
                onTap: () => setState(() => _selected = m),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Color(m.colorValue).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.menu_book_outlined, color: Color(m.colorValue), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                BadgeChip(label: m.category, color: Color(m.colorValue)),
                                if (m.hasBadge) const Text('🌱', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(m.title,
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                            Text('${m.pages} pages',
                                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                            const SizedBox(height: 10),
                            AppProgressBar(value: m.progress, color: Color(m.colorValue)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  m.progress == 0 ? 'Not started' : m.progress == 100 ? 'Completed ✓' : '${m.progress}% done',
                                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight),
                                ),
                                Text(
                                  m.progress > 0 ? 'Continue →' : 'Start →',
                                  style: GoogleFonts.nunito(fontSize: 11, color: Color(m.colorValue), fontWeight: FontWeight.w700),
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
          ),
        ),
      ],
    );
  }

  Widget _buildModuleDetail(ModuleModel m) {
    final color = Color(m.colorValue);
    final chapters = ['Chapter 1: Overview', 'Chapter 2: Key Concepts', 'Chapter 3: Case Studies', 'Chapter 4: Summary & Assessment'];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.9), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                label: Text('Back', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              BadgeChip(label: m.category, color: Colors.white),
              const SizedBox(height: 8),
              Text(m.title, style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('${m.pages} pages', style: GoogleFonts.nunito(color: Colors.white.withOpacity(0.75), fontSize: 13)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reading Progress', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                        Text('${m.progress}%', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppProgressBar(value: m.progress, color: color),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Page ${(m.pages * m.progress / 100).round()}', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                        Text('${m.pages} pages', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...chapters.asMap().entries.map((entry) {
                final i = entry.key;
                final ch = entry.value;
                final done = (i / 4) * 100 < m.progress;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: done ? color : AppColors.border,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: done
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : Text('${i + 1}', style: GoogleFonts.nunito(color: AppColors.textLight, fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(ch,
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: done ? AppColors.textDark : AppColors.textLight)),
                        ),
                        if (done) const Icon(Icons.chevron_right, color: AppColors.textLight, size: 16),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    m.progress == 100 ? '📖 Review Module' : m.progress > 0 ? '📖 Continue Reading' : '📖 Start Reading',
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
              if (m.hasBadge) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBA08).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Badge Earned!', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                            Text('First Steps — Completed your first module', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}