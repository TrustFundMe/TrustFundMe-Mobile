import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/feed_service.dart';
import '../../core/api/media_service.dart';
import '../../core/models/feed_post_model.dart';
import '../../core/models/feed_comment_model.dart';
import '../../core/models/feed_post_media_model.dart';
import '../../core/providers/auth_provider.dart';

/// Post Detail Screen — chi tiết 1 post + comments + add comment.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // ─── Constants ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _primary = Color(0xFFF84D43);

  // ─── Services ──────────────────────────────────────────────────────────────
  final FeedService _feedSvc = FeedService();
  final MediaService _mediaSvc = MediaService();

  // ─── State ─────────────────────────────────────────────────────────────────
  FeedPostModel? _post;
  List<FeedCommentModel> _comments = <FeedCommentModel>[];
  List<FeedPostMediaItem> _media = <FeedPostMediaItem>[];
  bool _loadingPost = true;
  bool _loadingComments = true;
  bool _sendingComment = false;

  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
    _loadMedia();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadPost() async {
    try {
      final Response<dynamic> res =
          await _feedSvc.getFeedPostById(widget.postId);
      if (res.data is Map<String, dynamic>) {
        if (!mounted) return;
        setState(() {
          _post = FeedPostModel.fromJson(res.data as Map<String, dynamic>);
          _loadingPost = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPost = false);
    }
  }

  Future<void> _loadComments() async {
    try {
      final Response<dynamic> res = await _feedSvc.getFeedPostComments(
        widget.postId,
        page: 0,
        size: 50,
        sort: 'createdAt,asc',
      );
      final dynamic data = res.data;
      List<dynamic> content = <dynamic>[];
      if (data is Map<String, dynamic>) {
        content = (data['content'] as List<dynamic>?) ?? <dynamic>[];
      } else if (data is List) {
        content = data;
      }

      if (!mounted) return;
      setState(() {
        _comments = content
            .whereType<Map<String, dynamic>>()
            .map(FeedCommentModel.fromJson)
            .toList();
        _loadingComments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _loadMedia() async {
    try {
      final Response<dynamic> res =
          await _mediaSvc.getMediaByPostId(widget.postId);
      final List<FeedPostMediaItem> items =
          parseFeedPostMediaResponse(res.data);
      if (mounted) setState(() => _media = items);
    } catch (_) {}
  }

  Future<void> _sendComment() async {
    final String text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để bình luận.')),
      );
      return;
    }

    setState(() => _sendingComment = true);
    try {
      await _feedSvc.createFeedPostComment(widget.postId, text);
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
      await _loadComments();
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không gửi được bình luận.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để thích bài viết.')),
      );
      return;
    }

    final FeedPostModel p = _post!;
    final bool prevLiked = p.isLiked;
    final int prevCount = p.likeCount;

    setState(() {
      _post = p.copyWithLike(
        isLiked: !p.isLiked,
        likeCount: p.isLiked
            ? (p.likeCount > 0 ? p.likeCount - 1 : 0)
            : p.likeCount + 1,
      );
    });

    try {
      final Response<dynamic> res =
          await _feedSvc.toggleFeedPostLike(p.id);
      final dynamic data = res.data;
      bool liked = !prevLiked;
      int count = liked ? prevCount + 1 : (prevCount > 0 ? prevCount - 1 : 0);

      if (data is Map<String, dynamic>) {
        if (data.containsKey('isLiked')) liked = data['isLiked'] == true;
        else if (data.containsKey('liked')) liked = data['liked'] == true;
        final dynamic lc = data['likeCount'];
        if (lc is num) count = lc.toInt();
      }

      if (mounted) {
        setState(() {
          _post = _post!.copyWithLike(isLiked: liked, likeCount: count);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _post = _post!.copyWithLike(isLiked: prevLiked, likeCount: prevCount);
        });
      }
    }
  }

  Future<void> _toggleCommentLike(int index) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    final FeedCommentModel c = _comments[index];
    final bool prevLiked = c.isLiked;
    final int prevCount = c.likeCount;

    setState(() {
      _comments[index] = c.copyWithLike(
        isLiked: !c.isLiked,
        likeCount: c.isLiked
            ? (c.likeCount > 0 ? c.likeCount - 1 : 0)
            : c.likeCount + 1,
      );
    });

    try {
      await _feedSvc.toggleFeedPostCommentLike(c.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _comments[index] = _comments[index]
              .copyWithLike(isLiked: prevLiked, likeCount: prevCount);
        });
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static String _timeAgo(String raw) {
    if (raw.isEmpty) return '';
    final DateTime? d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    final int sec = DateTime.now().difference(d).inSeconds;
    if (sec < 60) return 'Vừa xong';
    if (sec < 3600) return '${sec ~/ 60} phút trước';
    if (sec < 86400) return '${sec ~/ 3600} giờ trước';
    if (sec < 604800) return '${sec ~/ 86400} ngày trước';
    return '${d.day}/${d.month}/${d.year}';
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Chi tiết bài viết',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
      ),
      body: _loadingPost
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? _buildError()
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: RefreshIndicator(
                        color: _primary,
                        onRefresh: () async {
                          await _loadPost();
                          await _loadComments();
                        },
                        child: ListView(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding:
                              const EdgeInsets.fromLTRB(0, 0, 0, 16),
                          children: <Widget>[
                            _buildPostContent(),
                            const Divider(height: 1),
                            _buildCommentsSection(),
                          ],
                        ),
                      ),
                    ),
                    _buildCommentInput(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'Không tải được bài viết',
            style: TextStyle(fontSize: 15, color: _muted),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() => _loadingPost = true);
              _loadPost();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // ─── Post Content ─────────────────────────────────────────────────────────
  Widget _buildPostContent() {
    final FeedPostModel p = _post!;
    final String content = _stripHtml(p.content);
    final String time = _timeAgo(p.updatedAt ?? p.createdAt);
    final List<FeedPostMediaItem> images =
        _media.where((m) => m.isPhoto).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Author
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE5E7EB),
                backgroundImage:
                    p.authorAvatar != null && p.authorAvatar!.isNotEmpty
                        ? NetworkImage(p.authorAvatar!)
                        : null,
                child: p.authorAvatar == null || p.authorAvatar!.isEmpty
                    ? Text(
                        p.authorName.isNotEmpty
                            ? p.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      p.authorName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        if (p.targetName != null &&
                            p.targetName!.isNotEmpty) ...<Widget>[
                          Flexible(
                            child: Text(
                              p.targetName!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(' · ',
                              style:
                                  TextStyle(fontSize: 12, color: _muted)),
                        ],
                        Text(
                          time,
                          style: const TextStyle(
                              fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (p.title != null && p.title!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              p.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
          ],

          if (content.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF374151),
                height: 1.6,
              ),
            ),
          ],

          // Images
          if (images.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            ...images.map((img) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      img.url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: const Color(0xFFE5E7EB),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined,
                            color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 14),

          // Actions bar
          Row(
            children: <Widget>[
              InkWell(
                onTap: _toggleLike,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        p.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: p.isLiked ? _primary : _muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.likeCount}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.isLiked ? _primary : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Row(
                children: <Widget>[
                  const Icon(Icons.chat_bubble_outline,
                      size: 20, color: _muted),
                  const SizedBox(width: 6),
                  Text(
                    '${_comments.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Row(
                children: <Widget>[
                  const Icon(Icons.visibility_outlined,
                      size: 20, color: _muted),
                  const SizedBox(width: 6),
                  Text(
                    '${p.viewCount}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Comments Section ─────────────────────────────────────────────────────
  Widget _buildCommentsSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Bình luận (${_comments.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingComments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Chưa có bình luận nào.\nHãy là người đầu tiên!',
                  style: TextStyle(fontSize: 14, color: _muted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._comments.asMap().entries.map((entry) {
              return _buildCommentTile(entry.key, entry.value);
            }),
        ],
      ),
    );
  }

  Widget _buildCommentTile(int index, FeedCommentModel comment) {
    final String time = _timeAgo(comment.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: comment.authorAvatar != null &&
                    comment.authorAvatar!.isNotEmpty
                ? NetworkImage(comment.authorAvatar!)
                : null,
            child: comment.authorAvatar == null ||
                    comment.authorAvatar!.isEmpty
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      time,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: () => _toggleCommentLike(index),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            comment.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: comment.isLiked ? _primary : _muted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${comment.likeCount}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: comment.isLiked ? _primary : _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Comment Input ────────────────────────────────────────────────────────
  Widget _buildCommentInput() {
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              enabled: auth.isLoggedIn,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
              decoration: InputDecoration(
                hintText: auth.isLoggedIn
                    ? 'Viết bình luận...'
                    : 'Đăng nhập để bình luận',
                hintStyle: const TextStyle(fontSize: 14, color: _muted),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sendingComment
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: auth.isLoggedIn ? _sendComment : null,
                  icon: const Icon(Icons.send_rounded),
                  color: _primary,
                  iconSize: 24,
                ),
        ],
      ),
    );
  }
}
