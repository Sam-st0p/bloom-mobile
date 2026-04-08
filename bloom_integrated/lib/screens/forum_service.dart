import 'package:supabase_flutter/supabase_flutter.dart';

final _db = Supabase.instance.client;

class ForumService {
  // ── Posts ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPosts({
    int page = 0,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to   = from + pageSize - 1;
    final data = await _db
        .from('forum_posts')
        .select('*, profiles(full_name, avatar_url, department, year_level)')
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>?> getPost(String postId) async {
    return await _db
        .from('forum_posts')
        .select('*, profiles(full_name, avatar_url, department, year_level)')
        .eq('id', postId)
        .maybeSingle();
  }

  static Future<void> createPost({
    required String title,
    required String content,
    required String flair,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _db.from('forum_posts').insert({
      'user_id': userId,
      'title':   title.trim(),
      'content': content.trim(),
      'flair':   flair,
    });
  }

  static Future<void> deletePost(String postId) async {
    await _db.from('forum_posts').delete().eq('id', postId);
  }

  // ── Replies ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getReplies(String postId) async {
    final data = await _db
        .from('forum_replies')
        .select('*, profiles(full_name, avatar_url, department, year_level)')
        .eq('post_id', postId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> addReply({
    required String postId,
    required String content,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    await _db.from('forum_replies').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content.trim(),
    });
  }

  static Future<void> deleteReply(String replyId) async {
    await _db.from('forum_replies').delete().eq('id', replyId);
  }
}