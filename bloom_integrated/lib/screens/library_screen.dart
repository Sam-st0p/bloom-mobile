import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pdf_viewer_screen.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import '../services/activity_service.dart';
import 'assessment_screen.dart';

final _supabase = Supabase.instance.client;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<ModuleModel> _modules = [];
  Map<String, int> _progressMap = {};
  bool _loading = true;
  String _search = '';
  ModuleModel? _selectedModule;
  List<Map<String, dynamic>> _moduleFiles = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;

      final modulesData = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      Map<String, int> progressMap = {};
      if (userId != null) {
        final progressData = await _supabase
            .from('module_progress')
            .select('module_id, progress_percent')
            .eq('user_id', userId);
        for (final p in progressData as List) {
          progressMap[p['module_id'].toString()] =
              (p['progress_percent'] as num?)?.toInt() ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _progressMap = progressMap;
          _modules = (modulesData as List)
              .map((m) => ModuleModel.fromMap(m,
                  progress: progressMap[m['id'].toString()] ?? 0))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openModule(ModuleModel module) async {
    setState(() {
      _selectedModule = module;
      _loadingFiles = true;
      _moduleFiles = [];
    });

    // Log activity
    await ActivityService.log(
      activityType: 'module_opened',
      referenceId: module.id,
      referenceType: 'module',
      metadata: {'title': module.title},
    );

    try {
      final files = await _supabase
          .from('module_files')
          .select('*')
          .eq('module_id', module.id)
          .order('sort_order');
      if (mounted) {
        setState(() {
          _moduleFiles = List<Map<String, dynamic>>.from(files as List);
          _loadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final url = file['file_url']?.toString();
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File URL not available.')),
        );
      }
      return;
    }

    // Log activity
    await ActivityService.log(
      activityType: 'file_opened',
      referenceId: file['id']?.toString(),
      referenceType: 'module_file',
      metadata: {
        'file_name': file['file_name'],
        'module_id': file['module_id'],
      },
    );

    // Update progress when a file is opened
    if (_selectedModule != null) {
      final currentProgress = _progressMap[_selectedModule!.id] ?? 0;
      if (currentProgress < 100) {
        final newPct = (currentProgress + 20).clamp(0, 90);
        await _updateProgress(_selectedModule!.id, newPct);
      }
    }

    if (!mounted) return;

    // Open PDF in-app viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url: url,
          title: file['file_name'] ?? 'Document',
        ),
      ),
    );
  }

  Future<void> _updateProgress(String moduleId, int pct) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('module_progress').upsert({
        'user_id': userId,
        'module_id': moduleId,
        'progress_percent': pct,
        'status': pct == 100 ? 'completed' : 'in_progress',
        'last_accessed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,module_id');
      await _load();
    } catch (_) {}
  }

  List<ModuleModel> get _filtered {
    if (_search.isEmpty) return _modules;
    final q = _search.toLowerCase();
    return _modules.where((m) =>
        m.title.toLowerCase().contains(q) ||
        m.category.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedModule != null) return _buildModuleDetail(_selectedModule!);
    return _buildLibrary();
  }

  Widget _buildLibrary() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📚 Module Library',
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Column(children: [
                              const Icon(Icons.menu_book_outlined,
                                  size: 48, color: AppColors.textLight),
                              const SizedBox(height: 12),
                              Text('No modules found',
                                  style: GoogleFonts.nunito(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          )
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _ModuleCard(
                            module: _filtered[i],
                            onTap: () => _openModule(_filtered[i]),
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildModuleDetail(ModuleModel module) {
    final progress = _progressMap[module.id] ?? 0;

    return Column(
      children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(
                  onPressed: () => setState(() => _selectedModule = null),
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Expanded(
                  child: Text(module.title,
                      style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      BadgeChip(
                          label: module.category,
                          color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 8),
                      BadgeChip(
                          label: progress == 100 ? '✅ Completed' : '$progress%',
                          color: Colors.white.withOpacity(0.3)),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Module description
              if (module.description != null && module.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About this Module',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textDark)),
                        const SizedBox(height: 8),
                        Text(module.description!,
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: AppColors.textMid,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ),

              // PDF Files section
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📄 Module Files',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textDark)),
                        if (_moduleFiles.isNotEmpty)
                          Text('${_moduleFiles.length} file${_moduleFiles.length > 1 ? 's' : ''}',
                              style: GoogleFonts.nunito(
                                  fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingFiles)
                      const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                    else if (_moduleFiles.isEmpty)
                      Column(children: [
                        const Icon(Icons.folder_open_outlined,
                            size: 36, color: AppColors.textLight),
                        const SizedBox(height: 8),
                        Text('No files uploaded yet.',
                            style: GoogleFonts.nunito(
                                color: AppColors.textLight, fontSize: 13)),
                      ])
                    else
                      ..._moduleFiles.map((f) => _FileTile(
                            file: f,
                            onTap: () => _openFile(f),
                          )),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Assessment button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssessmentScreen(
                          moduleId: module.id,
                          moduleTitle: module.title,
                          onComplete: () {
                            Navigator.pop(context);
                            _load();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.quiz_outlined,
                      size: 20, color: AppColors.primary),
                  label: Text('Take Assessment',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Module Card ────────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final ModuleModel module;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(module.colorValue);
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.menu_book_outlined, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.title,
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(module.category,
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.textLight)),
                  const SizedBox(height: 8),
                  AppProgressBar(value: module.progress, color: color),
                  const SizedBox(height: 4),
                  Text(
                    module.progress == 100
                        ? '✅ Completed'
                        : module.progress == 0
                            ? 'Not started'
                            : '${module.progress}% complete',
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: module.progress == 100
                            ? AppColors.primary
                            : AppColors.textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── File Tile ──────────────────────────────────────────────────────────────────

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  const _FileTile({required this.file, required this.onTap});

  IconData get _icon {
    final type = (file['file_type'] ?? '').toString().toLowerCase();
    final name = (file['file_name'] ?? '').toString().toLowerCase();
    if (type.contains('pdf') || name.endsWith('.pdf'))
      return Icons.picture_as_pdf_outlined;
    if (type.contains('video') || name.endsWith('.mp4'))
      return Icons.play_circle_outline;
    if (type.contains('image') || name.endsWith('.png') || name.endsWith('.jpg'))
      return Icons.image_outlined;
    if (name.endsWith('.pptx') || name.endsWith('.ppt'))
      return Icons.slideshow_outlined;
    if (name.endsWith('.docx') || name.endsWith('.doc'))
      return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color get _iconColor {
    final type = (file['file_type'] ?? '').toString().toLowerCase();
    final name = (file['file_name'] ?? '').toString().toLowerCase();
    if (type.contains('pdf') || name.endsWith('.pdf')) return Colors.red.shade400;
    if (type.contains('video') || name.endsWith('.mp4')) return Colors.blue.shade400;
    if (name.endsWith('.pptx') || name.endsWith('.ppt')) return Colors.orange.shade400;
    if (name.endsWith('.docx') || name.endsWith('.doc')) return Colors.blue.shade600;
    return AppColors.primary;
  }

  String get _fileSize {
    final kb = file['file_size_kb'];
    if (kb == null) return '';
    if (kb < 1024) return '${kb} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['file_name'] ?? 'File',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_fileSize.isNotEmpty)
                    Text(_fileSize,
                        style: GoogleFonts.nunito(
                            fontSize: 11, color: AppColors.textLight)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.open_in_new,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Open',
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}