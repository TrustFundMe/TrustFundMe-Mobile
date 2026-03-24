import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_service.dart';
import '../core/models/feed_post_model.dart';
import '../core/models/forum_category_model.dart';
import '../core/providers/auth_provider.dart';
import 'feed_post_detail_screen.dart';
import '../widgets/feed/create_feed_post_sheet.dart';
import '../widgets/feed/feed_comments_sheet.dart';
import '../widgets/feed/feed_dwell_tracker.dart';

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
  final Map<int, List<String>> _imageUrlsByPostId = <int, List<String>>{};
  final Set<int> _dwellDone = <int>{};
  final Set<int> _seenPostIds = <int>{};
  List<ForumCategoryModel> _forumCategories = <ForumCategoryModel>[];

  int? _selectedCategoryId;
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
    _loadForumCategories();
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

  Future<void> _loadForumCategories() async {
    try {
      final Response<dynamic> res = await _api.getForumCategories();
      final dynamic data = res.data;
      if (data is! List<dynamic>) return;
      final List<ForumCategoryModel> list = data
          .whereType<Map<String, dynamic>>()
          .map(ForumCategoryModel.fromJson)
          .toList();
      if (mounted) setState(() => _forumCategories = list);
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

  void _setCategoryAndReload(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _quickFilter = _FeedQuickFilter.all;
    });
    _load(refresh: true);
  }

  void _setQuickFilterAndReload(_FeedQuickFilter f) {
    setState(() {
      _quickFilter = f;
      _selectedCategoryId = null;
    });
    _load(refresh: true);
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    String h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final int? v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  static bool _isHotPost(FeedPostModel p) =>
      p.viewCount >= 20 || p.likeCount >= 10;

  String? _categoryLabel(FeedPostModel p) {
    if (p.categoryId == null) return null;
    for (final ForumCategoryModel c in _forumCategories) {
      if (c.id == p.categoryId) return c.name;
    }
    return '#${p.categoryId}';
  }

  Color? _categoryColorForPost(FeedPostModel p) {
    if (p.categoryId == null) return null;
    for (final ForumCategoryModel c in _forumCategories) {
      if (c.id == p.categoryId) return _parseHexColor(c.color);
    }
    return const Color(0xFF6366F1);
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

  Future<void> _hydrateImages(Iterable<FeedPostModel> posts) async {
    for (final FeedPostModel p in posts) {
      if (_imageUrlsByPostId.containsKey(p.id)) continue;
      try {
        final Response<dynamic> res = await _api.getMediaByPostId(p.id);
        final dynamic data = res.data;
        final List<String> urls = <String>[];
        if (data is List<dynamic>) {
          for (final dynamic e in data) {
            if (e is Map<String, dynamic> && e['url'] != null) {
              urls.add(e['url'].toString());
            }
          }
        }
        if (mounted) {
          setState(() => _imageUrlsByPostId[p.id] = urls);
        }
      } catch (_) {
        if (mounted) setState(() => _imageUrlsByPostId[p.id] = <String>[]);
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
      final int? categoryParam =
          _quickFilter == _FeedQuickFilter.all ? _selectedCategoryId : null;
      final Response<dynamic> res = await _api.getFeedPosts(
        page: refresh ? 0 : _page,
        size: 12,
        categoryId: categoryParam,
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
          _imageUrlsByPostId.clear();
          _dwellDone.clear();
          _feedTotalElements = totalElements;
          _page = 1;
        } else {
          _posts.addAll(chunk);
          _page += 1;
        }
        _hasMore = (refresh ? 1 : _page) < totalPages;
      });
      await _hydrateImages(chunk);
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
    final TextEditingController reason = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        return AlertDialog(
          title: const Text('Báo cáo bài viết'),
          content: TextField(
            controller: reason,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Lý do...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Gửi'),
            ),
          ],
        );
      },
    );
    final String r = reason.text.trim();
    reason.dispose();
    if (ok != true || !mounted) return;
    if (r.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do.')),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi báo cáo thất bại.')),
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
                  _FilterPill(
                    label: 'Tất cả (${_feedTotalElements > 0 ? _feedTotalElements : _posts.length})',
                    selected: _selectedCategoryId == null &&
                        _quickFilter == _FeedQuickFilter.all,
                    selectedBg: const Color(0xFF18181B),
                    selectedFg: Colors.white,
                    onTap: () => _setCategoryAndReload(null),
                  ),
                  for (final ForumCategoryModel c in _forumCategories)
                    _FilterPill(
                      label: '${c.name} (${c.postCount})',
                      selected: _selectedCategoryId == c.id &&
                          _quickFilter == _FeedQuickFilter.all,
                      selectedBg:
                          _parseHexColor(c.color) ?? const Color(0xFF6366F1),
                      selectedFg: Colors.white,
                      onTap: () => _setCategoryAndReload(
                        _selectedCategoryId == c.id ? null : c.id,
                      ),
                    ),
                  _FilterPill(
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
                  _FilterPill(
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
                  _FilterPill(
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
                        final List<String> images =
                            _imageUrlsByPostId[post.id] ?? <String>[];
                        return FeedDwellTracker(
                          visibilityKey: ValueKey<String>('dwell-${post.id}'),
                          dwell: const Duration(seconds: 3),
                          onDwell: () => _onDwellView(post.id),
                          child: _FeedPostCard(
                            post: post,
                            imageUrls: images,
                            timeLabel: _timeAgo(post.updatedAt ?? post.createdAt),
                            textPreview: _stripHtml(post.content),
                            categoryLabel: _categoryLabel(post),
                            categoryColor: _categoryColorForPost(post),
                            showHotBadge: _isHotPost(post),
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
                            onFlag: () => _flagPost(post),
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.selectedFg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedBg;
  final Color selectedFg;
  final VoidCallback onTap;

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : _border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? selectedFg : _muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  const _FeedPostCard({
    required this.post,
    required this.imageUrls,
    required this.timeLabel,
    required this.textPreview,
    this.categoryLabel,
    this.categoryColor,
    this.showHotBadge = false,
    required this.onOpen,
    this.onLike,
    required this.onComment,
    required this.onFlag,
  });

  final FeedPostModel post;
  final List<String> imageUrls;
  final String timeLabel;
  final String textPreview;
  final String? categoryLabel;
  final Color? categoryColor;
  final bool showHotBadge;
  final VoidCallback onOpen;
  final VoidCallback? onLike;
  final VoidCallback onComment;
  final VoidCallback onFlag;

  static const Color _primary = Color(0xFFF84D43);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final Widget inner = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFF3F4F6),
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
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: _text,
                              ),
                            ),
                          ),
                          if (post.isPinned)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Ghim',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFC2410C),
                                ),
                              ),
                            ),
                          if (showHotBadge)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 14,
                                    color: Color(0xFFC2410C),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Hot',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFC2410C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (categoryLabel != null &&
                          categoryLabel!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (categoryColor ?? _muted)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              categoryLabel!.trim(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: categoryColor ?? _muted,
                              ),
                            ),
                          ),
                        ),
                      if (post.targetType == 'CAMPAIGN' &&
                          (post.targetName ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Chiến dịch: ${post.targetName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: _muted),
                  onSelected: (String value) {
                    if (value == 'flag') onFlag();
                  },
                  itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'flag',
                      child: Text('Báo cáo bài viết'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if ((post.title ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(
                post.title!.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _text,
                ),
              ),
            ),
          if (textPreview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                textPreview,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: _text,
                ),
              ),
            ),
          if (imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE5E7EB),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined,
                          color: _muted),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: _muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.viewCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 14),
                if (post.isLocked)
                  const Icon(Icons.lock_outline, size: 16, color: _muted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? _primary : _text,
                  ),
                ),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.mode_comment_outlined, color: _text),
                ),
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              '${post.likeCount} lượt thích',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: _text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onComment,
              child: Text(
                'Xem ${post.commentCount} bình luận',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: inner,
    );
  }
}
