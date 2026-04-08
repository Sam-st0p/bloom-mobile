import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/forum_service.dart';
import '../theme/app_theme.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});
  @override State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;
  int    _page  = 0;
  bool   _hasMore = true;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200
        && !_loading && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final posts = await ForumService.getPosts(page: 0);
      if (mounted) {
        setState(() {
        _posts   = posts;
        _page    = 0;
        _hasMore = posts.length == 20;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load posts.'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final more = await ForumService.getPosts(page: _page + 1);
      if (mounted) {
        setState(() {
        _posts.addAll(more);
        _page++;
        _hasMore = more.length == 20;
        _loading = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _openPost(Map<String, dynamic> post) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)))
      .then((_) => _load());
  }

  void _openCreate() {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()))
      .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft:  Radius.elliptical(220, 70),
              bottomRight: Radius.elliptical(220, 70),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 48),
          child: Column(children: [
            Text('💬 Forum', style: GoogleFonts.nunito(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Community discussions', style: GoogleFonts.nunito(
              color: Colors.white70, fontSize: 13)),
          ]),
        ),

        // Content
        Expanded(child: _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _posts.isEmpty && !_loading
                ? _EmptyState(onCreate: _openCreate)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    itemCount: _posts.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _posts.length) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ));
                      }
                      return PostCard(
                        post: _posts[i],
                        onTap: () => _openPost(_posts[i]),
                      );
                    },
                  ),
            ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Post', style: GoogleFonts.nunito(
          color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── PostCard ──────────────────────────────────────────────
class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  const PostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final author    = post['profiles']?['full_name'] ?? 'Student';
    final createdAt = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();
    final flair     = post['flair'] ?? 'General';
    final isPinned  = post['is_pinned'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (isPinned) ...[
              const Icon(Icons.push_pin, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(flair, style: GoogleFonts.nunito(
                fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(timeago.format(createdAt), style: GoogleFonts.nunito(
              fontSize: 11, color: AppColors.textLight)),
          ]),
          const SizedBox(height: 8),
          Text(post['title'] ?? '', style: GoogleFonts.nunito(
            fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(post['content'] ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid, height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [
            CircleAvatar(radius: 10,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?',
                style: GoogleFonts.nunito(fontSize: 10, color: AppColors.primary,
                  fontWeight: FontWeight.w800))),
            const SizedBox(width: 6),
            Text(author, style: GoogleFonts.nunito(
              fontSize: 12, color: AppColors.textMid, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

// ── PostDetailScreen ──────────────────────────────────────
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});
  @override State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<Map<String, dynamic>> _replies = [];
  bool   _loading = false;
  final  _replyCtrl = TextEditingController();
  bool   _submitting = false;
  final  _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() { super.initState(); _loadReplies(); }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  Future<void> _loadReplies() async {
    setState(() => _loading = true);
    try {
      final r = await ForumService.getReplies(widget.post['id']);
      if (mounted) setState(() { _replies = r; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _submitReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ForumService.addReply(postId: widget.post['id'], content: text);
      _replyCtrl.clear();
      await _loadReplies();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send reply.')));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Post?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('This cannot be undone.', style: GoogleFonts.nunito()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.nunito())),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.nunito(color: Colors.red))),
        ],
      ));
    if (confirm != true) return;
    try {
      await ForumService.deletePost(widget.post['id']);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post      = widget.post;
    final author    = post['profiles']?['full_name'] ?? 'Student';
    final isOwner   = post['user_id'] == _currentUserId;
    final createdAt = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Post', style: GoogleFonts.nunito(
          color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          if (isOwner) IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: _deletePost),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadReplies,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              // Post body
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post['title'] ?? '', style: GoogleFonts.nunito(
                    fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  Text(post['content'] ?? '', style: GoogleFonts.nunito(
                    fontSize: 14, color: AppColors.textMid, height: 1.6)),
                  const SizedBox(height: 12),
                  Text('$author · ${timeago.format(createdAt)}',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight)),
                ]),
              ),
              const SizedBox(height: 20),

              Text('${_replies.length} Replies', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 10),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else
                ..._replies.map((r) => ReplyTile(
                  reply: r,
                  isOwner: r['user_id'] == _currentUserId,
                  onDelete: () async {
                    await ForumService.deleteReply(r['id']);
                    _loadReplies();
                  },
                )),
            ]),
          ),
        ),

        // Reply input
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16,
            12 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _replyCtrl,
                style: GoogleFonts.nunito(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 10),
            _submitting
              ? const SizedBox(width: 40, height: 40,
                  child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
              : IconButton(
                  onPressed: _submitReply,
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 28)),
          ]),
        ),
      ]),
    );
  }
}

// ── ReplyTile ─────────────────────────────────────────────
class ReplyTile extends StatelessWidget {
  final Map<String, dynamic> reply;
  final bool isOwner;
  final VoidCallback onDelete;
  const ReplyTile({super.key, required this.reply,
    required this.isOwner, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final author    = reply['profiles']?['full_name'] ?? 'Student';
    final createdAt = DateTime.tryParse(reply['created_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 12,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?',
              style: GoogleFonts.nunito(fontSize: 11,
                color: AppColors.primary, fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(author, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(timeago.format(createdAt), style: GoogleFonts.nunito(
              fontSize: 11, color: AppColors.textLight)),
          ])),
          if (isOwner) GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline, size: 18, color: Colors.red)),
        ]),
        const SizedBox(height: 8),
        Text(reply['content'] ?? '', style: GoogleFonts.nunito(
          fontSize: 13, color: AppColors.textMid, height: 1.5)),
      ]),
    );
  }
}

// ── CreatePostScreen ──────────────────────────────────────
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _flair      = 'General';
  bool   _submitting = false;
  String? _error;

  static const _flairs = ['General', 'Question', 'Discussion', 'Resource'];

  Future<void> _submit() async {
    final title   = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.length < 3)   { setState(() => _error = 'Title must be at least 3 characters.'); return; }
    if (content.length < 10){ setState(() => _error = 'Content must be at least 10 characters.'); return; }
    setState(() { _submitting = true; _error = null; });
    try {
      await ForumService.createPost(title: title, content: content, flair: _flair);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
        _error = 'Failed to create post. Please try again.';
        _submitting = false;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('New Post', style: GoogleFonts.nunito(
          color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text('Post', style: GoogleFonts.nunito(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          )
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200)),
            child: Text(_error!, style: GoogleFonts.nunito(
              color: Colors.red.shade700, fontSize: 13)),
          ),

        // Flair selector
        Text('Category', style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.textMid, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: _flairs.map((f) {
          final selected = _flair == f;
          return GestureDetector(
            onTap: () => setState(() => _flair = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border)),
              child: Text(f, style: GoogleFonts.nunito(
                color: selected ? Colors.white : AppColors.textMid,
                fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          );
        }).toList()),
        const SizedBox(height: 16),

        // Title
        TextField(
          controller: _titleCtrl,
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Post title...',
            hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border)),
          ),
          maxLength: 200,
        ),
        const SizedBox(height: 12),

        // Content
        TextField(
          controller: _contentCtrl,
          style: GoogleFonts.nunito(fontSize: 14),
          maxLines: 10,
          decoration: InputDecoration(
            hintText: 'Share something with the community...',
            hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border)),
          ),
          maxLength: 5000,
        ),
      ]),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});
  @override Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('💬', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('No posts yet', style: GoogleFonts.nunito(
        fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
      const SizedBox(height: 6),
      Text('Be the first to start a discussion!', style: GoogleFonts.nunito(
        color: AppColors.textLight)),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: onCreate,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text('Create Post', style: GoogleFonts.nunito(
          color: Colors.white, fontWeight: FontWeight.w800))),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.wifi_off, size: 48, color: AppColors.textLight),
      const SizedBox(height: 12),
      Text(message, style: GoogleFonts.nunito(color: AppColors.textMid)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        child: Text('Retry', style: GoogleFonts.nunito(color: Colors.white))),
    ]),
  );
}