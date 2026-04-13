import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/api_constants.dart';
import '../core/api/api_service.dart';
import '../core/models/feed_post_media_model.dart';
import '../core/models/feed_post_model.dart';
import '../core/providers/auth_provider.dart';
import '../widgets/feed/create_feed_post_sheet.dart';
import '../widgets/feed/feed_comments_panel.dart';
import '../widgets/feed/feed_dwell_tracker.dart';
import '../widgets/feed/feed_post_attachments.dart';
import '../widgets/feed/feed_post_target_nav.dart';
import '../widgets/flags/flag_reason_sheet.dart';
import '../core/utils/flag_error_resolver.dart';
import '../core/utils/flag_duplicate_guard.dart';
import '../core/utils/feed_post_flag_guard.dart';
import '../widgets/feed/post_revision_history_sheet.dart';

/// Full post + inline comments (danbox `/post/[id]` parity).
class FeedPostDetailScreen extends StatefulWidget {
  const FeedPostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<FeedPostDetailScreen> createState() => _FeedPostDetailScreenState();
}

class _FeedPostDetailScreenState extends State<FeedPostDetailScreen> {
  static const Color _primary = Color(0xFFF84D43);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  final ApiService _api = ApiService();
  FeedPostModel? _post;
  List<FeedPostMediaItem> _media = <FeedPostMediaItem>[];
  bool _loading = true;
  String? _error;
  bool _dwellDone = false;
  bool _isFollowingCampaign = true;
  bool _followStateResolved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _formatPostDate(String raw) {
    if (raw.isEmpty) return '';
    final DateTime? d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mm = d.minute.toString().padLeft(2, '0');
    return 'lúc $hh:$mm ${d.day} tháng ${d.month}, ${d.year}';
  }

  static String _visibilityVi(String v) {
    switch (v.toUpperCase()) {
      case 'PUBLIC':
        return 'CÔNG KHAI';
      case 'PRIVATE':
        return 'RIÊNG TƯ';
      case 'FOLLOWERS':
        return 'CHỈ NGƯỜI THEO DÕI';
      default:
        return v;
    }
  }

  static bool _isHot(FeedPostModel p) =>
      p.viewCount >= 20 || p.likeCount >= 10;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Response<dynamic> res = await _api.getFeedPostById(widget.postId);
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Dữ liệu không hợp lệ');
      }
      final FeedPostModel post = FeedPostModel.fromJson(data);
      await _resolveFollowState(post);
      List<FeedPostMediaItem> media = <FeedPostMediaItem>[];
      try {
        final Response<dynamic> m = await _api.getMediaByPostId(widget.postId);
        media = parseFeedPostMediaResponse(m.data);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _post = post;
        _media = media;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được bài viết';
      });
    }
  }

  int? _linkedCampaignId(FeedPostModel p) {
    if ((p.targetType ?? '').toUpperCase() == 'CAMPAIGN') return p.targetId;
    return null;
  }

  Future<void> _resolveFollowState(FeedPostModel post) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final int? campaignId = _linkedCampaignId(post);
    if (post.visibility.toUpperCase() != 'FOLLOWERS' || campaignId == null) {
      _isFollowingCampaign = true;
      _followStateResolved = true;
      return;
    }
    if (!auth.isLoggedIn) {
      _isFollowingCampaign = false;
      _followStateResolved = true;
      return;
    }
    try {
      final Response<dynamic> res = await _api.isFollowingCampaign(campaignId);
      final dynamic data = res.data;
      _isFollowingCampaign = data is Map<String, dynamic> && data['following'] == true;
    } catch (_) {
      // Unknown follow state from network error: do not hard-lock by default.
      _isFollowingCampaign = true;
    }
    _followStateResolved = true;
  }

  bool _isFollowerLocked(FeedPostModel post, AuthProvider auth) {
    if (post.visibility.toUpperCase() != 'FOLLOWERS') return false;
    if (auth.user?.id == post.authorId) return false;
    if (!_followStateResolved) return true;
    return !_isFollowingCampaign;
  }

  Future<void> _followCampaignFromLocked(FeedPostModel post) async {
    final int? campaignId = _linkedCampaignId(post);
    if (campaignId == null) return;
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để theo dõi campaign.')),
      );
      return;
    }
    try {
      await _api.followCampaign(campaignId);
      if (!mounted) return;
      setState(() {
        _isFollowingCampaign = true;
        _followStateResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không theo dõi được campaign lúc này.')),
      );
    }
  }

  Future<void> _onDwellView() async {
    if (_dwellDone) return;
    _dwellDone = true;
    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    try {
      final Response<dynamic> res = await _api.markUserPostSeen(widget.postId);
      final dynamic data = res.data;
      final bool isNew =
          data is Map<String, dynamic> && data['new'] == true;
      if (!isNew || !mounted || _post == null) return;
      setState(() {
        _post = _post!.copyWithViewCount(_post!.viewCount + 1);
      });
    } catch (_) {
      _dwellDone = false;
    }
  }

  Future<void> _toggleLike() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final FeedPostModel? p = _post;
    if (!auth.isLoggedIn || p == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng nhập để thích bài viết.')),
        );
      }
      return;
    }
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
      final Response<dynamic> res = await _api.toggleFeedPostLike(p.id);
      final dynamic data = res.data;
      bool liked = prevLiked;
      int count = prevCount;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('isLiked')) {
          liked = data['isLiked'] == true;
        }
        final dynamic lc = data['likeCount'];
        if (lc is int) count = lc;
        if (lc is num) count = lc.toInt();
      }
      if (!mounted) return;
      setState(() {
        _post = _post!.copyWithLike(isLiked: liked, likeCount: count);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = _post!.copyWithLike(isLiked: prevLiked, likeCount: prevCount);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không cập nhật được thích.')),
      );
    }
  }

  Future<void> _shareLink() async {
    final String base = '${ApiConfig.campaignUrl}/feed-posts/${widget.postId}';
    await Clipboard.setData(ClipboardData(text: base));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép liên kết bài viết.')),
      );
    }
  }

  Future<void> _flagPost() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final FeedPostModel? p = _post;
    if (!auth.isLoggedIn || p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập để báo cáo bài viết.')),
      );
      return;
    }
    if (!userCanFlagFeedPost(p, auth.user?.id)) {
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
    final bool duplicated = await hasSubmittedFlag(_api, postId: p.id);
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
      await _api.submitFlag(postId: p.id, reason: r);
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

  Future<void> _editPost() async {
    final FeedPostModel? p = _post;
    if (p == null) return;
    await showCreateFeedPostSheet(
      context,
      existingPost: p,
      onUpdated: () => _load(),
    );
  }

  Widget _buildPostActionBar(FeedPostModel post, AuthProvider auth) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: _toggleLike,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: post.isLiked ? _primary : _text,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post.likeCount} thích',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: post.isLiked ? _primary : _text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 20,
                  color: _text,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bình luận (${post.commentCount})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          InkWell(
            onTap: _shareLink,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.send_outlined, size: 20, color: _text),
                  SizedBox(width: 6),
                  Text(
                    'Chia sẻ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          if (auth.isLoggedIn &&
              userCanFlagFeedPost(post, auth.user?.id))
            InkWell(
              onTap: _flagPost,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.flag_outlined, size: 20, color: _muted),
                    SizedBox(width: 6),
                    Text(
                      'Báo cáo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    final FeedPostModel? p = _post;
    if (p == null) return;
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
      await _api.deleteFeedPost(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa bài viết.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xóa được bài.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final double mediaImageCap =
        (MediaQuery.sizeOf(context).height * 0.26).clamp(160.0, 220.0);
    final bool isOwner =
        auth.user != null && _post != null && auth.user!.id == _post!.authorId;

    final bool locked = !_loading && _post != null && _isFollowerLocked(_post!, auth);
    final Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: _primary)))
            : locked
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.lock_outline, size: 36, color: _muted),
                            const SizedBox(height: 10),
                            const Text(
                              'Nội dung này chỉ dành cho người theo dõi campaign.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700, color: _text),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Theo dõi campaign để mở khóa toàn bộ nội dung.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => _followCampaignFromLocked(_post!),
                              child: const Text('Theo dõi campaign'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
            : _post == null
                ? const SizedBox.shrink()
                : FeedDwellTracker(
                    visibilityKey: ValueKey<String>('dwell-detail-${widget.postId}'),
                    dwell: const Duration(seconds: 3),
                    onDwell: _onDwellView,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: FeedCommentsPanel(
                        postId: widget.postId,
                        isLocked: _post!.isLocked,
                        currentUserId: auth.user?.id,
                        showSheetChrome: false,
                        mergedScrollWithComposer: true,
                        onTotalChanged: (int n) {
                          if (_post == null || !mounted) return;
                          setState(() {
                            _post!.commentCount = n;
                            _post!.replyCount = n;
                          });
                        },
                        prependInScroll: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 18, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _visibilityVi(_post!.visibility),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF166534),
                                            letterSpacing: 0.04,
                                          ),
                                        ),
                                      ),
                                      if (_isHot(_post!)) ...<Widget>[
                                        const SizedBox(width: 8),
                                        Container(
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
                                                size: 16,
                                                color: Color(0xFFC2410C),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Hot',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFC2410C),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  if ((_post!.title ?? '').trim().isNotEmpty)
                                    Text(
                                      _post!.title!.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        height: 1.25,
                                        color: _text,
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: const Color(0xFFF3F4F6),
                                        backgroundImage: _post!.authorAvatar != null &&
                                                _post!.authorAvatar!.isNotEmpty
                                            ? NetworkImage(_post!.authorAvatar!)
                                            : null,
                                        child: _post!.authorAvatar == null ||
                                                _post!.authorAvatar!.isEmpty
                                            ? Text(
                                                _post!.authorName.isNotEmpty
                                                    ? _post!.authorName[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: _muted,
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
                                              _post!.authorName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: _text,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 4,
                                              children: <Widget>[
                                                Text(
                                                  _formatPostDate(_post!.createdAt),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: _muted,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (_post!.hasRevisions && _post!.updatedAt != null) ...<Widget>[
                                                  const Text('·', style: TextStyle(fontSize: 13, color: _muted)),
                                                  GestureDetector(
                                                    onTap: () => showPostRevisionHistorySheet(
                                                      context,
                                                      postId: _post!.id,
                                                    ),
                                                    child: const Text(
                                                      'Đã chỉnh sửa',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF1A685B),
                                                        fontWeight: FontWeight.w600,
                                                        decoration: TextDecoration.underline,
                                                        decorationColor: Color(0xFF1A685B),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  FeedPostTargetPill(api: _api, post: _post!),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    _stripHtml(_post!.content).isNotEmpty
                                        ? _stripHtml(_post!.content)
                                        : _post!.content,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  if (_media.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 16),
                                    FeedPostAttachmentsPreview(
                                      media: _media,
                                      imageHeight: mediaImageCap,
                                      borderRadius: 14,
                                    ),
                                  ],
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 1),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 4, 8, 10),
                                child: _buildPostActionBar(_post!, auth),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Bài viết', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        actions: <Widget>[
          if (!_loading && _post != null)
            PopupMenuButton<String>(
              onSelected: (String v) {
                if (v == 'edit') _editPost();
                if (v == 'delete') _deletePost();
                if (v == 'history') {
                  showPostRevisionHistorySheet(
                    context,
                    postId: _post!.id,
                  );
                }
              },
              itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
                if (isOwner) ...<PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Chỉnh sửa'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Xóa'),
                  ),
                  const PopupMenuDivider(),
                ],
                const PopupMenuItem<String>(
                  value: 'history',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.history, size: 16),
                      SizedBox(width: 8),
                      Text('Lịch sử chỉnh sửa'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: body,
    );
  }
}
