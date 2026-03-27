import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/api_constants.dart';
import '../core/api/api_service.dart';
import '../core/models/feed_post_model.dart';
import '../core/providers/auth_provider.dart';
import '../widgets/feed/feed_comments_panel.dart';
import '../widgets/feed/feed_dwell_tracker.dart';

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
  List<String> _imageUrls = <String>[];
  bool _loading = true;
  String? _error;
  bool _dwellDone = false;

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
      List<String> urls = <String>[];
      try {
        final Response<dynamic> m = await _api.getMediaByPostId(widget.postId);
        final dynamic md = m.data;
        if (md is List<dynamic>) {
          for (final dynamic e in md) {
            if (e is Map<String, dynamic> && e['url'] != null) {
              urls.add(e['url'].toString());
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _post = post;
        _imageUrls = urls;
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
      await _api.submitFlag(postId: p.id, reason: r);
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

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    final Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: _primary)))
            : _post == null
                ? const SizedBox.shrink()
                : FeedDwellTracker(
                    visibilityKey: ValueKey<String>('dwell-detail-${widget.postId}'),
                    dwell: const Duration(seconds: 3),
                    onDwell: _onDwellView,
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 52,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
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
                                            Text(
                                              _formatPostDate(
                                                _post!.updatedAt ?? _post!.createdAt,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: _muted,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
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
                                  if (_imageUrls.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: AspectRatio(
                                        aspectRatio: 4 / 3,
                                        child: Image.network(
                                          _imageUrls.first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFE5E7EB),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                              color: _muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Divider(height: 1),
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: <Widget>[
                                        InkWell(
                                          onTap: _toggleLike,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 6,
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                Icon(
                                                  _post!.isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 20,
                                                  color: _post!.isLiked ? _primary : _text,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${_post!.likeCount} thích',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: _post!.isLiked ? _primary : _text,
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
                                                'Bình luận (${_post!.commentCount})',
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
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 6,
                                            ),
                                            child: Row(
                                              children: <Widget>[
                                                Icon(
                                                  Icons.send_outlined,
                                                  size: 20,
                                                  color: _text,
                                                ),
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
                                        if (auth.isLoggedIn)
                                          InkWell(
                                            onTap: _flagPost,
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 6,
                                              ),
                                              child: Row(
                                                children: <Widget>[
                                                  Icon(
                                                    Icons.flag_outlined,
                                                    size: 20,
                                                    color: _muted,
                                                  ),
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        Expanded(
                          flex: 48,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                            child: FeedCommentsPanel(
                              postId: widget.postId,
                              isLocked: _post!.isLocked,
                              currentUserId: auth.user?.id,
                              showSheetChrome: false,
                              onTotalChanged: (int n) {
                                if (_post == null || !mounted) return;
                                setState(() {
                                  _post!.commentCount = n;
                                  _post!.replyCount = n;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Bài viết', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
      ),
      body: body,
    );
  }
}
