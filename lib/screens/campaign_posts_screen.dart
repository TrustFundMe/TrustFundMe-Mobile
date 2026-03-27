import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/feed_post_media_model.dart';
import '../core/models/feed_post_model.dart';
import '../core/providers/auth_provider.dart';
import '../widgets/feed/create_feed_post_sheet.dart';
import '../widgets/feed/feed_comments_sheet.dart';
import '../widgets/feed/feed_dwell_tracker.dart';
import '../widgets/feed/feed_post_attachments.dart';
import 'feed_post_detail_screen.dart';
import '../widgets/flags/flag_reason_sheet.dart';
import '../core/utils/flag_error_resolver.dart';
import '../core/utils/flag_duplicate_guard.dart';
import '../core/utils/feed_post_flag_guard.dart';

class CampaignPostsScreen extends StatefulWidget {
  const CampaignPostsScreen({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
  });

  final int campaignId;
  final String campaignTitle;

  @override
  State<CampaignPostsScreen> createState() => _CampaignPostsScreenState();
}

class _CampaignPostsScreenState extends State<CampaignPostsScreen> {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _primary = Color(0xFFF84D43);

  final ApiService _api = ApiService();
  final ScrollController _scroll = ScrollController();

  List<FeedPostModel> _posts = <FeedPostModel>[];
  final Map<int, List<FeedPostMediaItem>> _mediaByPostId =
      <int, List<FeedPostMediaItem>>{};
  final Set<int> _dwellDone = <int>{};

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
      _load();
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
      final res = await _api.getFeedPosts(
        page: refresh ? 0 : _page,
        size: 12,
        campaignId: widget.campaignId,
      );
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Dữ liệu không hợp lệ');
      }
      final List<dynamic> content =
          data['content'] as List<dynamic>? ?? <dynamic>[];
      final int totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
      final List<FeedPostModel> chunk = content
          .whereType<Map<String, dynamic>>()
          .map(FeedPostModel.fromJson)
          .where((FeedPostModel p) {
            final String type = (p.targetType ?? '').toUpperCase();
            return type == 'CAMPAIGN' && p.targetId == widget.campaignId;
          })
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _posts = chunk;
          _mediaByPostId.clear();
          _dwellDone.clear();
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
          const SnackBar(content: Text('Không tải được bài viết.')),
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

  Future<void> _hydrateMedia(Iterable<FeedPostModel> posts) async {
    for (final FeedPostModel p in posts) {
      if (_mediaByPostId.containsKey(p.id)) continue;
      try {
        final res = await _api.getMediaByPostId(p.id);
        final List<FeedPostMediaItem> items =
            parseFeedPostMediaResponse(res.data);
        if (mounted) setState(() => _mediaByPostId[p.id] = items);
      } catch (_) {
        if (mounted) {
          setState(() => _mediaByPostId[p.id] = <FeedPostMediaItem>[]);
        }
      }
    }
  }

  Future<void> _editPost(FeedPostModel post) async {
    await showCreateFeedPostSheet(
      context,
      linkedCampaignId: widget.campaignId,
      linkedCampaignTitle: widget.campaignTitle,
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

  Future<void> _onDwellView(int postId) async {
    if (_dwellDone.contains(postId)) return;
    _dwellDone.add(postId);
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final res = await _api.markUserPostSeen(postId);
      final dynamic data = res.data;
      final bool isNew = data is Map<String, dynamic> && data['new'] == true;
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

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final int? uid = auth.user?.id;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Bài viết về chiến dịch',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: _loading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                itemCount: _posts.length + (_loadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (BuildContext c, int i) {
                  if (i >= _posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final FeedPostModel post = _posts[i];
                  final List<FeedPostMediaItem> media =
                      _mediaByPostId[post.id] ?? <FeedPostMediaItem>[];
                  final bool isOwner = uid != null && post.authorId == uid;
                  return FeedDwellTracker(
                    visibilityKey: ValueKey<String>('dwell-campaign-${post.id}'),
                    dwell: const Duration(seconds: 3),
                    onDwell: () => _onDwellView(post.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => FeedPostDetailScreen(postId: post.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      (post.title ?? '').trim().isEmpty
                                          ? 'Bài viết #${post.id}'
                                          : post.title!.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: _text,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz, color: _muted),
                                    onSelected: (String value) {
                                      if (value == 'flag') _flagPost(post);
                                      if (value == 'edit') _editPost(post);
                                      if (value == 'delete') _deletePost(post);
                                    },
                                    itemBuilder: (BuildContext c) =>
                                        <PopupMenuEntry<String>>[
                                      if (isOwner) ...<PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('Chỉnh sửa'),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Xóa'),
                                        ),
                                      ],
                                      if (!isOwner)
                                        const PopupMenuItem<String>(
                                          value: 'flag',
                                          child: Text('Báo cáo bài viết'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (media.isNotEmpty) ...<Widget>[
                                FeedPostAttachmentsPreview(
                                  media: media,
                                  imageHeight: 120,
                                  borderRadius: 12,
                                ),
                                const SizedBox(height: 10),
                              ],
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.remove_red_eye_outlined, size: 16, color: _muted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.viewCount}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(
                                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 16,
                                    color: post.isLiked ? _primary : _muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.likeCount}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Icon(Icons.mode_comment_outlined, size: 16, color: _muted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${post.commentCount}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _muted,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _openComments(post),
                                    child: const Text(
                                      'Bình luận',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

