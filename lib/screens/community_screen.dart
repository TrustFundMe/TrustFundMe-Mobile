import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_service.dart';
import '../core/models/feed_post_media_model.dart';
import '../core/models/feed_post_model.dart';
import '../core/providers/auth_provider.dart';
import 'feed_post_detail_screen.dart';
import '../widgets/feed/community_feed_post_card.dart';
import '../widgets/feed/create_feed_post_sheet.dart';
import '../widgets/feed/feed_comments_sheet.dart';
import '../widgets/feed/feed_dwell_tracker.dart';
import '../widgets/feed/feed_filter_pill.dart';
import '../widgets/flags/flag_reason_sheet.dart';
import '../core/utils/flag_error_resolver.dart';
import '../core/utils/flag_duplicate_guard.dart';
import '../core/utils/feed_post_flag_guard.dart';

enum _FeedQuickFilter { all, unseen, seen, hot }

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const String _seenPrefsKey = 'community_feed_seen_v1';

  final ApiService _api = ApiService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  List<FeedPostModel> _posts = <FeedPostModel>[];
  final Map<int, List<FeedPostMediaItem>> _mediaByPostId =
      <int, List<FeedPostMediaItem>>{};
  final Set<int> _dwellDone = <int>{};
  final Set<int> _seenPostIds = <int>{};
  _FeedQuickFilter _quickFilter = _FeedQuickFilter.all;
  int _feedTotalElements = 0;

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _initSeenFromPrefs();
    _load(refresh: true);
  }

  Future<void> _initSeenFromPrefs() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final List<String> raw =
          p.getStringList(_seenPrefsKey) ?? <String>[];
      final Set<int> next = <int>{};
      for (final String s in raw) {
        final int? id = int.tryParse(s);
        if (id != null) next.add(id);
      }
      if (mounted) {
        setState(() {
          _seenPostIds.clear();
          _seenPostIds.addAll(next);
        });
      }
    } catch (_) {}
  }

  Future<void> _persistSeenPost(int postId) async {
    if (_seenPostIds.contains(postId)) return;
    if (mounted) {
      setState(() => _seenPostIds.add(postId));
    } else {
      _seenPostIds.add(postId);
    }
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setStringList(
        _seenPrefsKey,
        _seenPostIds.map((int e) => '$e').toList(),
      );
    } catch (_) {}
  }

  void _setQuickFilterAndReload(_FeedQuickFilter f) {
    setState(() => _quickFilter = f);
    _load(refresh: true);
  }

  static bool _isHotPost(FeedPostModel p) =>
      p.viewCount >= 20 || p.likeCount >= 10;

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
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final Response<dynamic> res = await _api.getFeedPosts(
        page: refresh ? 0 : _page,
        size: 12,
        categoryId: null,
      );
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Dữ liệu không hợp lệ');
      }
      final List<dynamic> content =
          data['content'] as List<dynamic>? ?? <dynamic>[];
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được feed.')),
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
        final String a = p.authorName.toLowerCase();
        return t.contains(q) || c.contains(q) || a.contains(q);
      }).toList();
    }
    switch (_quickFilter) {
      case _FeedQuickFilter.unseen:
        return list
            .where((FeedPostModel p) => !_seenPostIds.contains(p.id))
            .toList();
      case _FeedQuickFilter.seen:
        return list.where((FeedPostModel p) => _seenPostIds.contains(p.id)).toList();
      case _FeedQuickFilter.hot:
        return list.where(_isHotPost).toList();
      case _FeedQuickFilter.all:
        return list;
    }
  }

  Future<void> _onDwellView(int postId) async {
    if (_dwellDone.contains(postId)) return;
    _dwellDone.add(postId);
    await _persistSeenPost(postId);
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
        _posts[idx] =
            p.copyWithViewCount(p.viewCount + 1);
      });
    } catch (_) {
      _dwellDone.remove(postId);
    }
  }

  Future<void> _toggleLike(int indexInFullList) async {
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để thích bài viết.')),
      );
      return;
    }
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

  Future<void> _flagPost(FeedPostModel post) async {
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để báo cáo bài viết.')),
      );
      return;
    }
    if (!userCanFlagFeedPost(post, auth.user?.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Bạn không thể tố cáo bài viết của chính mình.'),
        ),
      );
      return;
    }
    final String? r = await showFeedPostFlagReasonBottomSheet(context);
    if (r == null || r.isEmpty || !mounted) return;
    final bool duplicated = await hasSubmittedFlag(_api, postId: post.id);
    if (duplicated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Bạn đã tố cáo bài viết này rồi.'),
        ),
      );
      return;
    }
    try {
      await _api.submitFlag(postId: post.id, reason: r);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi báo cáo. Cảm ơn bạn.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Color(0xFFDC2626),
            content: Text(resolveFlagSubmitError(e)),
          ),
        );
      }
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

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Feed cộng đồng',
          style: TextStyle(fontWeight: FontWeight.w800),
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
                      const SnackBar(
                        content: Text('Đăng nhập để đăng bài.'),
                      ),
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
                hintText: 'Tìm bài viết, tác giả...',
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
                    label: 'Tất cả (${_feedTotalElements > 0 ? _feedTotalElements : _posts.length})',
                    selected: _quickFilter == _FeedQuickFilter.all,
                    selectedBg: const Color(0xFF18181B),
                    selectedFg: Colors.white,
                    onTap: () => _setQuickFilterAndReload(_FeedQuickFilter.all),
                  ),
                  FeedFilterPill(
                    label: 'Chưa xem',
                    selected: _quickFilter == _FeedQuickFilter.unseen,
                    selectedBg: const Color(0xFF10B981),
                    selectedFg: Colors.white,
                    onTap: () => _setQuickFilterAndReload(
                      _quickFilter == _FeedQuickFilter.unseen
                          ? _FeedQuickFilter.all
                          : _FeedQuickFilter.unseen,
                    ),
                  ),
                  FeedFilterPill(
                    label: 'Đã xem',
                    selected: _quickFilter == _FeedQuickFilter.seen,
                    selectedBg: const Color(0xFFE5E7EB),
                    selectedFg: _text,
                    onTap: () => _setQuickFilterAndReload(
                      _quickFilter == _FeedQuickFilter.seen
                          ? _FeedQuickFilter.all
                          : _FeedQuickFilter.seen,
                    ),
                  ),
                  FeedFilterPill(
                    label: 'Đang hot',
                    selected: _quickFilter == _FeedQuickFilter.hot,
                    selectedBg: const Color(0xFFEF4444),
                    selectedFg: Colors.white,
                    onTap: () => _setQuickFilterAndReload(
                      _quickFilter == _FeedQuickFilter.hot
                          ? _FeedQuickFilter.all
                          : _FeedQuickFilter.hot,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
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
                      itemCount: visible.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext c, int i) {
                        if (i >= visible.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final FeedPostModel post = visible[i];
                        final int fullIdx = _indexInPostsList(post);
                        final List<FeedPostMediaItem> media =
                            _mediaByPostId[post.id] ?? <FeedPostMediaItem>[];
                        final int? uid = auth.user?.id;
                        return FeedDwellTracker(
                          visibilityKey: ValueKey<String>('dwell-${post.id}'),
                          dwell: const Duration(seconds: 3),
                          onDwell: () => _onDwellView(post.id),
                          child: CommunityFeedPostCard(
                            api: _api,
                            post: post,
                            media: media,
                            timeLabel: _timeAgo(post.updatedAt ?? post.createdAt),
                            textPreview: _stripHtml(post.content),
                            categoryLabel: null,
                            categoryColor: null,
                            showHotBadge: _isHotPost(post),
                            statusBadgeText: null,
                            currentUserId: uid,
                            onOpen: () async {
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext ctx) =>
                                      FeedPostDetailScreen(postId: post.id),
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
                            onFlag: userCanFlagFeedPost(post, uid)
                                ? () => _flagPost(post)
                                : null,
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
