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

// ─────────────────────────────────────────────
// Filter model
// ─────────────────────────────────────────────
enum ProgressFilter { all, notStarted, inProgress, completed }

class _LibraryFilters {
  final ProgressFilter progress;
  final String? categoryName; // match against module.category string

  const _LibraryFilters({
    this.progress = ProgressFilter.all,
    this.categoryName,
  });

  _LibraryFilters copyWith({
    ProgressFilter? progress,
    Object? categoryName = _sentinel,
  }) {
    return _LibraryFilters(
      progress: progress ?? this.progress,
      categoryName:
          categoryName == _sentinel ? this.categoryName : categoryName as String?,
    );
  }

  bool get hasActiveFilters =>
      progress != ProgressFilter.all || categoryName != null;
}

const _sentinel = Object();

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<ModuleModel> _modules     = [];
  Map<String, int>  _progressMap = {};
  bool   _loading     = true;
  bool   _loadingMore = false;
  bool   _hasMore     = true;
  String _search      = '';
  int    _page        = 0;
  static const int _pageSize = 10;

  _LibraryFilters _filters = const _LibraryFilters();

  ModuleModel? _selectedModule;
  List<Map<String, dynamic>> _moduleFiles = [];
  bool _loadingFiles = false;

  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();

  // Derived list of distinct category names from loaded modules
  List<String> get _categories {
    final cats = _modules.map((m) => m.category).where((c) => c.isNotEmpty).toSet().toList();
    cats.sort();
    return cats;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Infinite scroll trigger ────────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        _search.isEmpty &&
        !_filters.hasActiveFilters) {
      _loadMore();
    }
  }

  // ── Initial load (page 0) ──────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _page = 0; _hasMore = true; });
    try {
      final userId = _supabase.auth.currentUser?.id;

      final modulesData = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

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
        final list = (modulesData as List)
            .map((m) => ModuleModel.fromMap(m,
                progress: progressMap[m['id'].toString()] ?? 0))
            .toList();
        setState(() {
          _progressMap = progressMap;
          _modules     = list;
          _hasMore     = list.length == _pageSize;
          _loading     = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Load next page ─────────────────────────────────────
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final from     = nextPage * _pageSize;
      final to       = from + _pageSize - 1;

      final modulesData = await _supabase
          .from('modules')
          .select('*, categories(name)')
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .range(from, to);

      if (mounted) {
        final list = (modulesData as List)
            .map((m) => ModuleModel.fromMap(m,
                progress: _progressMap[m['id'].toString()] ?? 0))
            .toList();
        setState(() {
          _modules.addAll(list);
          _page        = nextPage;
          _hasMore     = list.length == _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Open module detail ─────────────────────────────────
  Future<void> _openModule(ModuleModel module) async {
    setState(() {
      _selectedModule = module;
      _loadingFiles   = true;
      _moduleFiles    = [];
    });

    await ActivityService.log(
      activityType:  'module_opened',
      referenceId:   module.id,
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
          _moduleFiles  = List<Map<String, dynamic>>.from(files as List);
          _loadingFiles = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  // ── Open file ──────────────────────────────────────────
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

    await ActivityService.log(
      activityType:  'file_opened',
      referenceId:   file['id']?.toString(),
      referenceType: 'module_file',
      metadata: {
        'file_name': file['file_name'],
        'module_id': file['module_id'],
      },
    );

    if (_selectedModule != null) {
      final currentProgress = _progressMap[_selectedModule!.id] ?? 0;
      if (currentProgress < 100) {
        final newPct = (currentProgress + 20).clamp(0, 90);
        await _updateProgress(_selectedModule!.id, newPct);
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          url:   url,
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
        'user_id':            userId,
        'module_id':          moduleId,
        'progress_percent':   pct,
        'status':             pct == 100 ? 'completed' : 'in_progress',
        'last_accessed_at':   DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,module_id');
      await _load();
    } catch (_) {}
  }

  // ── Filtered list ──────────────────────────────────────
  List<ModuleModel> get _filtered {
    return _modules.where((m) {
      // Search
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!m.title.toLowerCase().contains(q) &&
            !m.category.toLowerCase().contains(q)) {
          return false;
        }
      }

      // Category
      if (_filters.categoryName != null &&
          m.category != _filters.categoryName) {
        return false;
      }

      // Progress status
      switch (_filters.progress) {
        case ProgressFilter.notStarted:
          if (m.progress > 0) return false;
          break;
        case ProgressFilter.inProgress:
          if (m.progress == 0 || m.progress == 100) return false;
          break;
        case ProgressFilter.completed:
          if (m.progress < 100) return false;
          break;
        default:
          break;
      }

      return true;
    }).toList();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filters.progress != ProgressFilter.all) count++;
    if (_filters.categoryName != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() => _filters = const _LibraryFilters());
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedModule != null) return _buildModuleDetail(_selectedModule!);
    return _buildLibrary();
  }

  // ── Library list view ──────────────────────────────────
  Widget _buildLibrary() {
    return Column(
      children: [
        // Header + search + filter row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_library_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Module Library',
                      style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  const Spacer(),
                  // Filter button with active badge
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _filters.hasActiveFilters
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filters.hasActiveFilters
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded,
                                  size: 16,
                                  color: _filters.hasActiveFilters
                                      ? AppColors.primary
                                      : AppColors.textMid),
                              const SizedBox(width: 5),
                              Text('Filter',
                                  style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _filters.hasActiveFilters
                                          ? AppColors.primary
                                          : AppColors.textMid)),
                              if (_activeFilterCount > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 17,
                                  height: 17,
                                  decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle),
                                  child: Center(
                                    child: Text('$_activeFilterCount',
                                        style: GoogleFonts.nunito(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Search bar
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
                          icon: const Icon(Icons.close,
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
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.border, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        // Active filter chips row
        if (_filters.hasActiveFilters) _buildActiveFiltersRow(),

        // Results count hint
        if (!_loading)
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} of ${_modules.length} modules',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),

        // Module list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filtered.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Column(children: [
                              Icon(
                                _filters.hasActiveFilters || _search.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.menu_book_outlined,
                                size: 48,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _filters.hasActiveFilters || _search.isNotEmpty
                                    ? 'No modules match your filters'
                                    : 'No modules found',
                                style: GoogleFonts.nunito(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w700),
                              ),
                              if (_filters.hasActiveFilters) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: Text('Clear filters',
                                      style: GoogleFonts.nunito(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ]),
                          ),
                        ])
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length +
                              (_loadingMore ? 1 : 0) +
                              (!_hasMore &&
                                      _modules.isNotEmpty &&
                                      _search.isEmpty &&
                                      !_filters.hasActiveFilters
                                  ? 1
                                  : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            if (i == _filtered.length && _loadingMore) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2),
                                ),
                              );
                            }
                            if (i == _filtered.length && !_hasMore) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                child: Center(
                                  child: Text(
                                    'All ${_modules.length} modules loaded',
                                    style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: AppColors.textLight),
                                  ),
                                ),
                              );
                            }
                            return _ModuleCard(
                              module: _filtered[i],
                              onTap: () => _openModule(_filtered[i]),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  // ── Active filter chips ────────────────────────────────
  Widget _buildActiveFiltersRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_filters.progress != ProgressFilter.all)
                    _ActiveChip(
                      label: _progressLabel(_filters.progress),
                      onRemove: () => setState(
                          () => _filters = _filters.copyWith(
                              progress: ProgressFilter.all)),
                    ),
                  if (_filters.categoryName != null) ...[
                    const SizedBox(width: 6),
                    _ActiveChip(
                      label: _filters.categoryName!,
                      onRemove: () => setState(
                          () => _filters =
                              _filters.copyWith(categoryName: null)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearFilters,
            child: Text('Clear all',
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Filter bottom sheet ────────────────────────────────
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        categories: _categories,
        currentFilters: _filters,
        onApply: (f) => setState(() => _filters = f),
      ),
    );
  }

  String _progressLabel(ProgressFilter f) {
    switch (f) {
      case ProgressFilter.notStarted:  return 'Not Started';
      case ProgressFilter.inProgress:  return 'In Progress';
      case ProgressFilter.completed:   return 'Completed';
      default: return 'All';
    }
  }

  // ── Module detail view ─────────────────────────────────
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
                          label: progress == 100 ? 'Completed' : '$progress%',
                          color: Colors.white.withOpacity(0.3)),
                      if (progress == 100) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 14),
                      ],
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
              if (module.description != null &&
                  module.description!.isNotEmpty)
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

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_open_outlined,
                                size: 18, color: AppColors.textDark),
                            const SizedBox(width: 6),
                            Text('Module Files',
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.textDark)),
                          ],
                        ),
                        if (_moduleFiles.isNotEmpty)
                          Text(
                              '${_moduleFiles.length} file${_moduleFiles.length > 1 ? 's' : ''}',
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

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssessmentScreen(
                          moduleId:    module.id,
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
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.5),
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

// ─────────────────────────────────────────────
// Active filter chip (dismissible)
// ─────────────────────────────────────────────
class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Filter bottom sheet
// ─────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<String> categories;
  final _LibraryFilters currentFilters;
  final ValueChanged<_LibraryFilters> onApply;

  const _FilterSheet({
    required this.categories,
    required this.currentFilters,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _LibraryFilters _local;

  @override
  void initState() {
    super.initState();
    _local = widget.currentFilters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Text('Filter Modules',
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    setState(() => _local = const _LibraryFilters()),
                child: Text('Reset',
                    style: GoogleFonts.nunito(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Progress status
          Text('Progress',
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMid)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SheetChip(
                label: 'All',
                selected: _local.progress == ProgressFilter.all,
                onTap: () => setState(() =>
                    _local = _local.copyWith(progress: ProgressFilter.all)),
              ),
              _SheetChip(
                label: 'Not Started',
                icon: Icons.radio_button_unchecked,
                selected: _local.progress == ProgressFilter.notStarted,
                onTap: () => setState(() => _local =
                    _local.copyWith(progress: ProgressFilter.notStarted)),
              ),
              _SheetChip(
                label: 'In Progress',
                icon: Icons.pending_rounded,
                selected: _local.progress == ProgressFilter.inProgress,
                onTap: () => setState(() => _local =
                    _local.copyWith(progress: ProgressFilter.inProgress)),
              ),
              _SheetChip(
                label: 'Completed',
                icon: Icons.check_circle_outline_rounded,
                selected: _local.progress == ProgressFilter.completed,
                onTap: () => setState(() => _local =
                    _local.copyWith(progress: ProgressFilter.completed)),
              ),
            ],
          ),

          // Category
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Category',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMid)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SheetChip(
                  label: 'All',
                  selected: _local.categoryName == null,
                  onTap: () => setState(
                      () => _local = _local.copyWith(categoryName: null)),
                ),
                ...widget.categories.map((cat) => _SheetChip(
                      label: cat,
                      selected: _local.categoryName == cat,
                      onTap: () => setState(() =>
                          _local = _local.copyWith(categoryName: cat)),
                    )),
              ],
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_local);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Apply Filters',
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color:
                      selected ? AppColors.primary : AppColors.textMid),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textMid)),
          ],
        ),
      ),
    );
  }
}

// ── Module Card ───────────────────────────────────────────
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
                  Row(
                    children: [
                      if (module.progress == 100)
                        const Icon(Icons.check_circle,
                            size: 11, color: AppColors.primary),
                      if (module.progress == 100) const SizedBox(width: 3),
                      Text(
                        module.progress == 100
                            ? 'Completed'
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

// ── File Tile ─────────────────────────────────────────────
class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onTap;
  const _FileTile({required this.file, required this.onTap});

  IconData get _icon {
    final type = (file['file_type'] ?? '').toString().toLowerCase();
    final name = (file['file_name'] ?? '').toString().toLowerCase();
    if (type.contains('pdf') || name.endsWith('.pdf'))   return Icons.picture_as_pdf_outlined;
    if (type.contains('video') || name.endsWith('.mp4')) return Icons.play_circle_outline;
    if (type.contains('image') || name.endsWith('.png') || name.endsWith('.jpg')) return Icons.image_outlined;
    if (name.endsWith('.pptx') || name.endsWith('.ppt')) return Icons.slideshow_outlined;
    if (name.endsWith('.docx') || name.endsWith('.doc')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color get _iconColor {
    final type = (file['file_type'] ?? '').toString().toLowerCase();
    final name = (file['file_name'] ?? '').toString().toLowerCase();
    if (type.contains('pdf') || name.endsWith('.pdf'))   return Colors.red.shade400;
    if (type.contains('video') || name.endsWith('.mp4')) return Colors.blue.shade400;
    if (name.endsWith('.pptx') || name.endsWith('.ppt')) return Colors.orange.shade400;
    if (name.endsWith('.docx') || name.endsWith('.doc')) return Colors.blue.shade600;
    return AppColors.primary;
  }

  String get _fileSize {
    final kb = file['file_size_kb'];
    if (kb == null) return '';
    if (kb < 1024) return '$kb KB';
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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