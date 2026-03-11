import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  String _search = '';
  ModuleModel? _selected;
  List<ModuleModel> _modules = [];
  bool _loading = true;

  // Module detail state
  List<Map<String, dynamic>> _moduleFiles = [];
  bool _filesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Fetch published modules with category name
      final modulesData = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      // Fetch user progress
      Map<String, int> progressMap = {};
      if (userId != null) {
        final progressData = await _supabase
            .from('module_progress')
            .select('module_id, progress_percent')
            .eq('user_id', userId);
        for (final p in progressData as List) {
          progressMap[p['module_id']] = p['progress_percent'] as int? ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _modules = (modulesData as List).map((m) {
            final pct = progressMap[m['id']] ?? 0;
            return ModuleModel.fromMap(m, progress: pct);
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadModuleFiles(String moduleId) async {
    setState(() => _filesLoading = true);
    try {
      final data = await _supabase
          .from('module_files')
          .select('id, title, file_type, file_url, sort_order')
          .eq('module_id', moduleId)
          .order('sort_order');
      if (mounted) {
        setState(() {
          _moduleFiles = List<Map<String, dynamic>>.from(data as List);
          _filesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _filesLoading = false);
    }
  }

  Future<void> _upsertProgress(String moduleId, int percent) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('module_progress').upsert({
        'user_id': userId,
        'module_id': moduleId,
        'progress_percent': percent,
        'status': percent == 100 ? 'completed' : 'in_progress',
        'last_accessed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,module_id');
      // Refresh modules list
      await _loadModules();
    } catch (e) {
      // silent
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _buildModuleDetail(_selected!);

    final filtered = _modules
        .where((m) =>
            m.title.toLowerCase().contains(_search.toLowerCase()) ||
            m.category.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📚 Module Library',
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.nunito(
                    fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textLight, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.textLight, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Module List ──────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off,
                              size: 48, color: AppColors.textLight),
                          const SizedBox(height: 12),
                          Text(
                              _search.isNotEmpty
                                  ? 'No modules found for "$_search"'
                                  : 'No modules available yet',
                              style: GoogleFonts.nunito(
                                  color: AppColors.textLight,
                                  fontSize: 14)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadModules,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final m = filtered[i];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selected = m);
                              _loadModuleFiles(m.id);
                            },
                            child: AppCard(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                        Icons.menu_book_outlined,
                                        color: AppColors.primary,
                                        size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            BadgeChip(
                                                label: m.category,
                                                color: AppColors.primary),
                                            if (m.progress == 100)
                                              const Text('✅',
                                                  style: TextStyle(
                                                      fontSize: 16)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(m.title,
                                            style: GoogleFonts.nunito(
                                                fontWeight:
                                                    FontWeight.w800,
                                                fontSize: 14,
                                                color:
                                                    AppColors.textDark)),
                                        const SizedBox(height: 10),
                                        AppProgressBar(
                                            value: m.progress,
                                            color: AppColors.primary),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            Text(
                                              m.progress == 0
                                                  ? 'Not started'
                                                  : m.progress == 100
                                                      ? 'Completed ✓'
                                                      : '${m.progress}% done',
                                              style: GoogleFonts.nunito(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textLight),
                                            ),
                                            Text(
                                              m.progress > 0
                                                  ? 'Continue →'
                                                  : 'Start →',
                                              style: GoogleFonts.nunito(
                                                  fontSize: 11,
                                                  color: AppColors.primary,
                                                  fontWeight:
                                                      FontWeight.w700),
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
        ),
      ],
    );
  }

  // ── Module Detail View ─────────────────────────────────────────────
  Widget _buildModuleDetail(ModuleModel m) {
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selected = null;
                    _moduleFiles = [];
                  });
                },
                icon:
                    const Icon(Icons.chevron_left, color: Colors.white),
                label: Text('Back',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              BadgeChip(label: m.category, color: Colors.white),
              const SizedBox(height: 8),
              Text(m.title,
                  style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Progress card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reading Progress',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textDark)),
                        Text('${m.progress}%',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AppProgressBar(
                        value: m.progress, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Module files / chapters
              if (_filesLoading)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                ))
              else if (_moduleFiles.isEmpty)
                AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No files uploaded for this module yet.',
                          style: GoogleFonts.nunito(
                              color: AppColors.textLight, fontSize: 13)),
                    ),
                  ),
                )
              else
                ..._moduleFiles.asMap().entries.map((entry) {
                  final i = entry.key;
                  final file = entry.value;
                  final fileType =
                      file['file_type']?.toString().toLowerCase() ?? '';
                  IconData fileIcon = Icons.insert_drive_file_outlined;
                  if (fileType == 'pdf') fileIcon = Icons.picture_as_pdf;
                  if (fileType == 'video') fileIcon = Icons.play_circle_outline;
                  if (fileType == 'image') fileIcon = Icons.image_outlined;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(fileIcon,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    file['title'] ??
                                        'File ${i + 1}',
                                    style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.textDark)),
                                Text(fileType.toUpperCase(),
                                    style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: AppColors.textLight)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textLight, size: 18),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 8),

              // Action buttons
              if (m.progress < 100)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final newProgress = m.progress == 0 ? 10 : (m.progress + 10).clamp(0, 100);
                      await _upsertProgress(m.id, newProgress);
                      if (mounted) {
                        final updated = _modules.firstWhere((mod) => mod.id == m.id, orElse: () => m);
                        setState(() => _selected = updated);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      m.progress > 0
                          ? '📖 Continue Reading'
                          : '📖 Start Reading',
                      style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('📖 Review Module',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),

              // Completed badge
              if (m.progress == 100) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFBA08).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFFBA08).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Module Completed!',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.textDark)),
                            Text(
                                'Great work finishing this module.',
                                style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: AppColors.textLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}