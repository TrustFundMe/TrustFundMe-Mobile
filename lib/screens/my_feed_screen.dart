import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/feed_post_media_model.dart';
import '../core/models/feed_post_model.dart';
import '../core/providers/auth_provider.dart';
import '../widgets/feed/community_feed_post_card.dart';
import '../widgets/feed/create_feed_post_sheet.dart';
import '../widgets/feed/feed_comments_sheet.dart';
import '../widgets/feed/feed_dwell_tracker.dart';
import '../widgets/feed/feed_filter_pill.dart';
import 'feed_post_detail_screen.dart';

enum _MyFeedPill { all, draft }

/// Bài viết của tôi — cùng layout/thẻ với feed cộng đồng, dữ liệu chỉ của user đăng nhập.
class MyFeedScreen extends StatefulWidget {
  final bool initialShowDrafts;
  const MyFeedScreen({super.key, this.initialShowDrafts = false});

  @override
  State<MyFeedScreen> createState() => _MyFeedScreenState();
}

class _MyFeedScreenState extends State<MyFeedScreen> {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _api = ApiService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  List<FeedPostModel> _posts = <FeedPostModel>[];
  final Map<int, List<FeedPostMediaItem>> _mediaByPostId =
      <int, List<FeedPostMediaItem>>{};
  final Set<int> _dwellDone = <int>{};

  _MyFeedPill _pill = _MyFeedPill.all;
  int _feedTotalElements = 0;

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;
  String _searchQuery = '';
  String? _fatalError;

  @override
  void initState() {
    super.initState();
    if (widget.initialShowDrafts) {
      _pill = _MyFeedPill.draft;
    }
    _scroll.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
      _load();
    }
  }

  String _apiStatusParam() =>
      _pill == _MyFeedPill.all ? 'ALL' : 'DRAFT';

  void _setPill(_MyFeedPill p) {
    if (_pill == p) return;
    setState(() => _pill = p);
    _load(refresh: true);
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  static bool _isHotPost(FeedPostModel p) =>
      p.viewCount >= 20 || p.likeCount >= 10;

  static String? _statusBadgeText(FeedPostModel p) {
    switch (p.status.toUpperCase()) {
      case 'DRAFT':
        return 'Bản nháp';
      case 'REJECTED':
        return 'Từ chối';
      case 'HIDDEN':
        return 'Đã ẩn';
      case 'PENDING':
        return 'Chờ duyệt';
      default:
        return null;
    }
  }

  Future<void> _hydrateMedia(Iterable<FeedPostModel> posts) async {
    for (final FeedPostModel p in posts) {
      if (_mediaByPostId.containsKey(p.id)) continue;
      try {
        final Response<dynamic> res = await _api.getMediaByPostId(p.id);
        final List<FeedPostMediaItem> items =
            parseFeedPostMediaResponse(res.data);
        if (mounted) {
          setState(() => _mediaByPostId[p.id] = items);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _mediaByPostId[p.id] = <FeedPostMediaItem>[]);
        }
      }
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;

    if (refresh) {
      setState(() {
        _loading = true;
        _fatalError = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final Response<dynamic> res = await _api.getMyFeedPosts(
        status: _apiStatusParam(),
        page: refresh ? 0 : _page,
        size: 12,
      );
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Dữ liệu không hợp lệ');
      }
      final List<dynamic> content =
          data['content'] is List<dynamic> ? data['content'] as List<dynamic> : <dynamic>[];
      final int totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
      final int totalElements =
          (data['totalElements'] as num?)?.toInt() ?? 0;
      final List<FeedPostModel> chunk = content
          .whereType<Map<String, dynamic>>()
          .map(FeedPostModel.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _posts = chunk;
          _mediaByPostId.clear();
          _dwellDone.clear();
          _feedTotalElements = totalElements;
          _page = 1;
        } else {
          _posts.addAll(chunk);
          _page += 1;
        }
        _hasMore = (refresh ? 1 : _page) < totalPages;
      });
      await _hydrateMedia(chunk);
    } catch (_) {
      if (!mounted) return;
      if (refresh) {
        setState(() {
          _posts = <FeedPostModel>[];
          _mediaByPostId.clear();
          _fatalError =
              'Không tải được bài viết của bạn. Vui lòng thử lại.';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải thêm được.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<FeedPostModel> get _visiblePosts {
    List<FeedPostModel> list = _posts;
    final String q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((FeedPostModel p) {
        final String t = (p.title ?? '').toLowerCase();
        final String c = _stripHtml(p.content).toLowerCase();
        return t.contains(q) || c.contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _onDwellView(int postId) async {
    if (_dwellDone.contains(postId)) return;
    _dwellDone.add(postId);
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final Response<dynamic> res = await _api.markUserPostSeen(postId);
      final dynamic data = res.data;
      final bool isNew =
          data is Map<String, dynamic> && data['new'] == true;
      if (!isNew || !mounted) return;
      final int idx = _posts.indexWhere((FeedPostModel e) => e.id == postId);
      if (idx < 0) return;
      setState(() {
        final FeedPostModel p = _posts[idx];
        _posts[idx] = p.copyWithViewCount(p.viewCount + 1);
      });
    } catch (_) {
      _dwellDone.remove(postId);
    }
  }

  Future<void> _toggleLike(int indexInFullList) async {
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    final FeedPostModel p = _posts[indexInFullList];
    final bool prevLiked = p.isLiked;
    final int prevCount = p.likeCount;
    setState(() {
      _posts[indexInFullList] = p.copyWithLike(
        isLiked: !p.isLiked,
        likeCount:
            p.isLiked ? (p.likeCount > 0 ? p.likeCount - 1 : 0) : p.likeCount + 1,
      );
    });
    try {
      final Response<dynamic> res = await _api.toggleFeedPostLike(p.id);
      final dynamic data = res.data;
      bool liked = prevLiked;
      int count = prevCount;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('isLiked')) {
          liked = data['isLiked'] == true;
        } else if (data.containsKey('liked')) {
          liked = data['liked'] == true;
        }
        final dynamic lc = data['likeCount'];
        if (lc is int) count = lc;
        if (lc is num) count = lc.toInt();
      }
      if (!mounted) return;
      setState(() {
        _posts[indexInFullList] =
            _posts[indexInFullList].copyWithLike(isLiked: liked, likeCount: count);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts[indexInFullList] =
            _posts[indexInFullList].copyWithLike(isLiked: prevLiked, likeCount: prevCount);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không cập nhật được thích.')),
      );
    }
  }

  Future<void> _editPost(FeedPostModel post) async {
    await showCreateFeedPostSheet(
      context,
      existingPost: post,
      onUpdated: () => _load(refresh: true),
    );
  }

  Future<void> _deletePost(FeedPostModel post) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: const Text('Xóa bài viết?'),
          content: const Text('Hành động này không hoàn tác.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteFeedPost(post.id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((FeedPostModel e) => e.id == post.id);
        _mediaByPostId.remove(post.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bài viết.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xóa được bài.')),
        );
      }
    }
  }

  void _openComments(FeedPostModel post) {
    showFeedCommentsSheet(
      context,
      postId: post.id,
      isLocked: post.isLocked,
      onCommentCountChanged: (int total) {
        final int idx = _posts.indexWhere((FeedPostModel e) => e.id == post.id);
        if (idx < 0 || !mounted) return;
        setState(() {
          _posts[idx].commentCount = total;
          _posts[idx].replyCount = total;
        });
      },
    );
  }

  int _indexInPostsList(FeedPostModel post) {
    return _posts.indexWhere((FeedPostModel e) => e.id == post.id);
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final List<FeedPostModel> visible = _visiblePosts;
    final int? uid = auth.user?.id;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Bài viết của tôi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        actions: <Widget>[
          IconButton(
            tooltip: 'Đăng bài',
            onPressed: auth.isLoggedIn
                ? () => showCreateFeedPostSheet(
                      context,
                      onCreated: () => _load(refresh: true),
                    )
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đăng nhập để đăng bài.')),
                    );
                  },
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (String v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Tìm trong bài viết của bạn...',
                prefixIcon: const Icon(Icons.search, color: _muted, size: 22),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FeedFilterPill(
                    label: _pill == _MyFeedPill.all
                        ? 'Tất cả (${_feedTotalElements > 0 ? _feedTotalElements : _posts.length})'
                        : 'Tất cả',
                    selected: _pill == _MyFeedPill.all,
                    selectedBg: const Color(0xFF18181B),
                    selectedFg: Colors.white,
                    onTap: () => _setPill(_MyFeedPill.all),
                  ),
                  FeedFilterPill(
                    label: _pill == _MyFeedPill.draft
                        ? 'Bản nháp (${_feedTotalElements > 0 ? _feedTotalElements : _posts.length})'
                        : 'Bản nháp',
                    selected: _pill == _MyFeedPill.draft,
                    selectedBg: const Color(0xFF10B981),
                    selectedFg: Colors.white,
                    onTap: () => _setPill(_MyFeedPill.draft),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _fatalError != null && _posts.isEmpty && !_loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _fatalError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => _load(refresh: true),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    child: _loading && _posts.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 100),
                            itemCount: visible.isEmpty
                                ? 1
                                : visible.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext c, int i) {
                              if (visible.isEmpty) {
                                final bool searching =
                                    _searchQuery.trim().isNotEmpty;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 48),
                                  child: Center(
                                    child: Text(
                                      searching
                                          ? 'Không có bài khớp tìm kiếm'
                                          : (_pill == _MyFeedPill.draft
                                              ? 'Chưa có bản nháp'
                                              : 'Chưa có bài viết'),
                                      style: const TextStyle(
                                        color: _muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (i >= visible.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final FeedPostModel post = visible[i];
                              final int fullIdx = _indexInPostsList(post);
                              final List<FeedPostMediaItem> media =
                                  _mediaByPostId[post.id] ??
                                      <FeedPostMediaItem>[];
                              return FeedDwellTracker(
                                visibilityKey:
                                    ValueKey<String>('my-dwell-${post.id}'),
                                dwell: const Duration(seconds: 3),
                                onDwell: () => _onDwellView(post.id),
                                child: CommunityFeedPostCard(
                                  api: _api,
                                  post: post,
                                  media: media,
                                  timeLabel:
                                      _timeAgo(post.updatedAt ?? post.createdAt),
                                  textPreview: _stripHtml(post.content),
                                  categoryLabel: null,
                                  categoryColor: null,
                                  showHotBadge: _isHotPost(post),
                                  statusBadgeText: _statusBadgeText(post),
                                  currentUserId: uid,
                                  onOpen: () async {
                                    await Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext ctx) =>
                                            FeedPostDetailScreen(
                                                postId: post.id),
                                      ),
                                    );
                                    if (mounted) {
                                      await _load(refresh: true);
                                    }
                                  },
                                  onLike: fullIdx >= 0
                                      ? () => _toggleLike(fullIdx)
                                      : null,
                                  onComment: () => _openComments(post),
                                  onFlag: null,
                                  onEdit: uid != null && post.authorId == uid
                                      ? () => _editPost(post)
                                      : null,
                                  onDelete: uid != null && post.authorId == uid
                                      ? () => _deletePost(post)
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
