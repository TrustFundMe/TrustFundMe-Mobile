import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/feed_service.dart';
import '../../core/api/media_service.dart';
import '../../core/models/feed_post_model.dart';
import '../../core/models/feed_post_media_model.dart';
import '../../core/providers/auth_provider.dart';
import 'post_detail_screen.dart';

/// Community Feed Screen — hiển thị bài viết từ tất cả campaigns.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  // ─── Constants ──────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _primary = Color(0xFFF84D43);

  // ─── Services ──────────────────────────────────────────────────────────────
  final FeedService _feedSvc = FeedService();
  final MediaService _mediaSvc = MediaService();

  // ─── State ─────────────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();
  List<FeedPostModel> _posts = <FeedPostModel>[];
  final Map<int, List<FeedPostMediaItem>> _mediaMap =
      <int, List<FeedPostMediaItem>>{};

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadFeed(refresh: true);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadFeed({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;

    if (mounted) {
      setState(() {
        if (refresh) _loading = true;
        else _loadingMore = true;
      });
    }

    try {
      final Response<dynamic> res = await _feedSvc.getFeedPosts(
        page: refresh ? 0 : _page,
        size: 10,
      );
      final dynamic data = res.data;
      List<dynamic> content = <dynamic>[];
      int totalPages = 1;

      if (data is Map<String, dynamic>) {
        content = (data['content'] as List<dynamic>?) ?? <dynamic>[];
        totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      } else if (data is List) {
        content = data;
      }

      final List<FeedPostModel> chunk = content
          .whereType<Map<String, dynamic>>()
          .map(FeedPostModel.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _posts = chunk;
          _mediaMap.clear();
          _page = 1;
        } else {
          _posts.addAll(chunk);
          _page += 1;
        }
        _hasMore = (refresh ? 1 : _page) < totalPages;
        _loading = false;
        _loadingMore = false;
      });

      _loadMediaInBackground(chunk);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được bài viết.')),
        );
      }
    }
  }

  Future<void> _loadMediaInBackground(List<FeedPostModel> posts) async {
    for (final FeedPostModel p in posts) {
      if (_mediaMap.containsKey(p.id)) continue;
      try {
        final Response<dynamic> res = await _mediaSvc.getMediaByPostId(p.id);
        final List<FeedPostMediaItem> items =
            parseFeedPostMediaResponse(res.data);
        if (mounted) {
          setState(() => _mediaMap[p.id] = items);
        }
      } catch (_) {
        if (mounted) setState(() => _mediaMap[p.id] = <FeedPostMediaItem>[]);
      }
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadFeed();
    }
  }

  Future<void> _toggleLike(int index) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để thích bài viết.')),
      );
      return;
    }

    final FeedPostModel p = _posts[index];
    final bool prevLiked = p.isLiked;
    final int prevCount = p.likeCount;

    // Optimistic update
    setState(() {
      _posts[index] = p.copyWithLike(
        isLiked: !p.isLiked,
        likeCount: p.isLiked
            ? (p.likeCount > 0 ? p.likeCount - 1 : 0)
            : p.likeCount + 1,
      );
    });

    try {
      final Response<dynamic> res = await _feedSvc.toggleFeedPostLike(p.id);
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
          _posts[index] =
              _posts[index].copyWithLike(isLiked: liked, likeCount: count);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts[index] = _posts[index]
              .copyWithLike(isLiked: prevLiked, likeCount: prevCount);
        });
      }
    }
  }

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
          'Cộng đồng',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () => _loadFeed(refresh: true),
        child: _loading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: _posts.length + (_loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, int i) {
                      if (i >= _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildPostCard(i);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Chưa có bài viết nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy quay lại sau nhé!',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(int index) {
    final FeedPostModel post = _posts[index];
    final List<FeedPostMediaItem> media =
        _mediaMap[post.id] ?? <FeedPostMediaItem>[];
    final String content = _stripHtml(post.content);
    final String time = _timeAgo(post.updatedAt ?? post.createdAt);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PostDetailScreen(postId: post.id),
            ),
          );
          if (mounted) _loadFeed(refresh: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ─── Author row ──────────────────────────────────────
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE5E7EB),
                    backgroundImage: post.authorAvatar != null &&
                            post.authorAvatar!.isNotEmpty
                        ? NetworkImage(post.authorAvatar!)
                        : null,
                    child: post.authorAvatar == null ||
                            post.authorAvatar!.isEmpty
                        ? Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
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
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: <Widget>[
                            if (post.targetName != null &&
                                post.targetName!.isNotEmpty) ...<Widget>[
                              Flexible(
                                child: Text(
                                  post.targetName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Text(' · ',
                                  style: TextStyle(
                                      fontSize: 11, color: _muted)),
                            ],
                            Text(
                              time,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── Content ─────────────────────────────────────────
              if (content.isNotEmpty)
                _ExpandableText(
                  text: content,
                  maxLines: 4,
                ),

              // ─── Media ───────────────────────────────────────────
              if (media.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _buildMediaCarousel(media),
              ],

              const SizedBox(height: 10),

              // ─── Actions ─────────────────────────────────────────
              Row(
                children: <Widget>[
                  _ActionButton(
                    icon: post.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: '${post.likeCount}',
                    color: post.isLiked ? _primary : _muted,
                    onTap: () => _toggleLike(index),
                  ),
                  const SizedBox(width: 20),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: '${post.commentCount}',
                    color: _muted,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PostDetailScreen(postId: post.id),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _ActionButton(
                    icon: Icons.visibility_outlined,
                    label: '${post.viewCount}',
                    color: _muted,
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCarousel(List<FeedPostMediaItem> media) {
    final List<FeedPostMediaItem> images =
        media.where((m) => m.isPhoto).toList();
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          images[0].url,
          height: 200,
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
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, int i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              images[i].url,
              width: 240,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 240,
                height: 200,
                color: const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: Color(0xFF9CA3AF)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Expandable Text ──────────────────────────────────────────────────────────
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text, this.maxLines = 4});
  final String text;
  final int maxLines;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            height: 1.5,
          ),
        ),
        if (widget.text.length > 200)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Thu gọn' : 'Xem thêm',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
