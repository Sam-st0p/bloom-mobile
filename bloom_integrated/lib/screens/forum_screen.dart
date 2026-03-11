import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final List<ForumPost> _posts = List.from(sampleForumPosts);
  String? _selectedPostId;
  bool _composing = false;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  void _toggleLike(String id) {
    setState(() {
      final post = _posts.firstWhere((p) => p.id == id);
      post.liked = !post.liked;
      post.votes += post.liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_composing) return _buildCompose();
    if (_selectedPostId != null) {
      final post = _posts.firstWhere((p) => p.id == _selectedPostId);
      return _buildPostDetail(post);
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
                  children: ['Hot 🔥', 'New ✨', 'Top 📈', 'Discussion', 'Help'].map((t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: t == 'Hot 🔥' ? AppColors.primary : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t, style: GoogleFonts.nunito(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: t == 'Hot 🔥' ? Colors.white : AppColors.textMid,
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
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = _posts[i];
              return GestureDetector(
                onTap: () => setState(() => _selectedPostId = p.id),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vote column
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleLike(p.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: p.liked ? AppColors.danger.withOpacity(0.12) : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.arrow_drop_up_rounded,
                                  color: p.liked ? AppColors.danger : AppColors.textLight, size: 22),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('${p.votes}',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800, fontSize: 13,
                                  color: p.liked ? AppColors.danger : AppColors.textMid)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatar(initials: p.avatar, color: AppColors.primary, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('${p.user} • ${p.time}',
                                      style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                                ),
                                BadgeChip(label: p.flair, color: AppColors.primary),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(p.title,
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark, height: 1.3)),
                            const SizedBox(height: 6),
                            Text(p.body,
                                style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textLight),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            // Only comment count, NO share button
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Text('${p.comments} comments',
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
      ],
    );
  }

  Widget _buildPostDetail(ForumPost post) {
    final commentExamples = [
      ('JD', 'Great question! I think gender equality means equal opportunities.', AppColors.info),
      ('RL', "Thanks for bringing this up — it's been on my mind too.", AppColors.accent),
      ('MS', 'The modules really helped me understand this better.', AppColors.purple),
    ];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedPostId = null),
                icon: const Icon(Icons.chevron_left, color: AppColors.textMid),
              ),
              Text('Back to Forum',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textMid, fontSize: 14)),
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
                      children: [
                        UserAvatar(initials: post.avatar, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post.user, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textDark)),
                              Text(post.time, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        BadgeChip(label: post.flair, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(post.title,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    Text('${post.body} This is a meaningful conversation about GAD topics that matter to students. The community\'s input is valued here.',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid, height: 1.6)),
                    const SizedBox(height: 14),
                    // Vote & comment — NO share button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(post.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: post.liked ? AppColors.danger.withOpacity(0.1) : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: post.liked ? AppColors.danger : AppColors.textLight, size: 18),
                                const SizedBox(width: 6),
                                Text('${post.votes}',
                                    style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                        color: post.liked ? AppColors.danger : AppColors.textLight)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textLight),
                            const SizedBox(width: 6),
                            Text('${post.comments}',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.textLight)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Comments (${post.comments})',
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 12),
              ...commentExamples.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(initials: c.$1, color: c.$3, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Student ${commentExamples.indexOf(c) + 1}',
                                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textDark)),
                                Text('1h ago',
                                    style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textLight)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(c.$2, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textMid)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
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
                onPressed: () => setState(() => _commentCtrl.clear()),
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
                onPressed: () => setState(() => _composing = false),
                child: Text('Cancel', style: GoogleFonts.nunito(color: AppColors.textMid, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text('New Post', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (_titleCtrl.text.isNotEmpty) {
                    setState(() {
                      _posts.insert(0, ForumPost(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        user: 'Ana Reyes', avatar: 'AR',
                        title: _titleCtrl.text,
                        body: _bodyCtrl.text,
                        votes: 1, comments: 0,
                        time: 'just now', liked: false, flair: 'Discussion',
                      ));
                      _composing = false;
                      _titleCtrl.clear();
                      _bodyCtrl.clear();
                    });
                  }
                },
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Discussion', 'Help', 'Experience', 'News', 'Question'].map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(f, style: GoogleFonts.nunito(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
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