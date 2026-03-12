import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

final _supabase = Supabase.instance.client;

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> _posts = [];
  Set<String> _myVotes = {};
  String? _selectedPostId;
  bool _composing = false;
  bool _loading = true;
  String _filter = 'New ✨';

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String _selectedFlair = 'Discussion';

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

      // Fetch posts with profile join
      final posts = await _supabase
          .from('forum_posts')
          .select('*, profiles(first_name, last_name), forum_comments(count), forum_votes(count)')
          .order('created_at', ascending: false);

      // Fetch my votes
      Set<String> myVotes = {};
      if (userId != null) {
        final votes = await _supabase
            .from('forum_votes')
            .select('post_id')
            .eq('user_id', userId);
        myVotes = Set<String>.from(
            List<Map<String, dynamic>>.from(votes).map((v) => v['post_id'].toString()));
      }

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(posts);
          _myVotes = myVotes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleVote(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final alreadyVoted = _myVotes.contains(postId);
    setState(() {
      if (alreadyVoted) {
        _myVotes.remove(postId);
      } else {
        _myVotes.add(postId);
      }
      // Optimistic update on vote count
      final idx = _posts.indexWhere((p) => p['id'] == postId);
      if (idx != -1) {
        final current = _posts[idx]['votes'] ?? 1;
        _posts[idx] = {..._posts[idx], 'votes': current + (alreadyVoted ? -1 : 1)};
      }
    });

    try {
      if (alreadyVoted) {
        await _supabase.from('forum_votes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await _supabase.from('forum_votes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
      // Update votes count in forum_posts
      final voteCount = await _supabase
          .from('forum_votes')
          .select('id')
          .eq('post_id', postId);
      final newCount = (voteCount as List).length;
      await _supabase.from('forum_posts').update({'votes': newCount}).eq('id', postId);
    } catch (_) {}
  }

  Future<void> _submitPost() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('forum_posts').insert({
        'user_id': userId,
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'flair': _selectedFlair,
        'votes': 1,
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() { _composing = false; _selectedFlair = 'Discussion'; });
      await _load();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadComments(String postId) async {
    try {
      final data = await _supabase
          .from('forum_comments')
          .select('*, profiles(first_name, last_name)')
          .eq('post_id', postId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {}
    return [];
  }

  Future<void> _submitComment(String postId) async {
    if (_commentCtrl.text.trim().isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('forum_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'body': _commentCtrl.text.trim(),
      });
      _commentCtrl.clear();
      setState(() {}); // trigger rebuild to reload comments
    } catch (_) {}
  }

  String _initials(Map<String, dynamic> post) {
    final first = (post['profiles']?['first_name'] ?? '?')[0].toUpperCase();
    final last = (post['profiles']?['last_name'] ?? '?')[0].toUpperCase();
    return '$first$last';
  }

  String _authorName(Map<String, dynamic> post) {
    final first = post['profiles']?['first_name'] ?? 'Student';
    final last = post['profiles']?['last_name'] ?? '';
    return '$first $last'.trim();
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  List<Map<String, dynamic>> get _filteredPosts {
    final sorted = List<Map<String, dynamic>>.from(_posts);
    if (_filter == 'Top 📈') {
      sorted.sort((a, b) => (b['votes'] ?? 0).compareTo(a['votes'] ?? 0));
    } else if (_filter == 'Hot 🔥') {
      sorted.sort((a, b) {
        final bComments = (b['forum_comments'] as List?)?.first?['count'] ?? 0;
        final aComments = (a['forum_comments'] as List?)?.first?['count'] ?? 0;
        return bComments.compareTo(aComments);
      });
    }
    // Filter by flair
    if (!['Hot 🔥', 'New ✨', 'Top 📈'].contains(_filter)) {
      return sorted.where((p) => p['flair'] == _filter).toList();
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (_composing) return _buildCompose();
    if (_selectedPostId != null) {
      final post = _posts.firstWhere(
        (p) => p['id'] == _selectedPostId,
        orElse: () => {},
      );
      if (post.isNotEmpty) return _buildPostDetail(post);
    }
    return _buildFeed();
  }

  Widget _buildFeed() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('💬 GAD Forum',
                      style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _composing = true),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Post', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Hot 🔥', 'New ✨', 'Top 📈', 'Discussion', 'Help', 'Experience', 'Question'].map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filter == t ? AppColors.primary : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t, style: GoogleFonts.nunito(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _filter == t ? Colors.white : AppColors.textMid,
                        )),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _filteredPosts.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.forum_outlined, size: 48, color: AppColors.textLight),
                                  const SizedBox(height: 12),
                                  Text('No posts yet', style: GoogleFonts.nunito(color: AppColors.textLight, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text('Be the first to start a discussion!',
                                      style: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredPosts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final p = _filteredPosts[i];
                            final postId = p['id'].toString();
                            final voted = _myVotes.contains(postId);
                            final commentCount = (p['forum_comments'] as List?)?.first?['count'] ?? 0;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedPostId = postId),
                              child: AppCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Vote column
                                    Column(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleVote(postId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: voted ? AppColors.danger.withOpacity(0.12) : AppColors.background,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(Icons.arrow_drop_up_rounded,
                                                color: voted ? AppColors.danger : AppColors.textLight, size: 22),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('${p['votes'] ?? 1}',
                                            style: GoogleFonts.nunito(
                                                fontWeight: FontWeight.w800, fontSize: 13,
                                                color: voted ? AppColors.danger : AppColors.textMid)),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              UserAvatar(initials: _initials(p), color: AppColors.primary, size: 24),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('${_authorName(p)} • ${_timeAgo(p['created_at'])}',
                                                    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                                              ),
                                              BadgeChip(label: p['flair'] ?? 'Discussion', color: AppColors.primary),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(p['title'] ?? '',
                                              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark, height: 1.3)),
                                          if ((p['body'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(p['body'],
                                                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight),
                                                maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.textLight),
                                              const SizedBox(width: 4),
                                              Text('$commentCount comments',
                                                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
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

  Widget _buildPostDetail(Map<String, dynamic> post) {
    final postId = post['id'].toString();
    final voted = _myVotes.contains(postId);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () { setState(() => _selectedPostId = null); _load(); },
                icon: const Icon(Icons.chevron_left, color: AppColors.textMid),
              ),
              Text('Back to Forum',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 14)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadComments(postId),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(initials: _initials(post), color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_authorName(post), style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark)),
                                  Text(_timeAgo(post['created_at']), style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            BadgeChip(label: post['flair'] ?? 'Discussion', color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(post['title'] ?? '',
                            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                        if ((post['body'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(post['body'],
                              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid, height: 1.6)),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleVote(postId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: voted ? AppColors.danger.withOpacity(0.1) : AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(voted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        color: voted ? AppColors.danger : AppColors.textLight, size: 18),
                                    const SizedBox(width: 6),
                                    Text('${post['votes'] ?? 1}',
                                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700,
                                            color: voted ? AppColors.danger : AppColors.textLight)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textLight),
                                const SizedBox(width: 6),
                                Text('${comments.length}',
                                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textLight)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Comments (${comments.length})',
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  if (comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No comments yet. Be the first!',
                            style: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 13)),
                      ),
                    ),
                  ...comments.map((c) {
                    final cFirst = (c['profiles']?['first_name'] ?? '?')[0].toUpperCase();
                    final cLast = (c['profiles']?['last_name'] ?? '?')[0].toUpperCase();
                    final cName = '${c['profiles']?['first_name'] ?? 'Student'} ${c['profiles']?['last_name'] ?? ''}'.trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(initials: '$cFirst$cLast', color: AppColors.info, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cName, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textDark)),
                                      Text(_timeAgo(c['created_at']), style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c['body'] ?? '', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: GoogleFonts.nunito(color: AppColors.textLight),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _submitComment(postId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: Text('Post', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompose() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() { _composing = false; _titleCtrl.clear(); _bodyCtrl.clear(); }),
                child: Text('Cancel', style: GoogleFonts.nunito(color: AppColors.textMid, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text('New Post', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const Spacer(),
              ElevatedButton(
                onPressed: _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text('Post', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Title of your post...',
                    hintStyle: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 18, fontWeight: FontWeight.w800),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _bodyCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textDark, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts about GAD topics...',
                      hintStyle: GoogleFonts.nunito(color: AppColors.textLight, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Flair', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMid)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Discussion', 'Help', 'Experience', 'News', 'Question'].map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFlair = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedFlair == f ? AppColors.primary : AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(f, style: GoogleFonts.nunito(
                            color: _selectedFlair == f ? Colors.white : AppColors.primary,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}