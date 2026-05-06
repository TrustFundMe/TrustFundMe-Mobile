import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/campaign_service.dart';
import '../../core/api/expenditure_service.dart';
import '../../core/api/feed_service.dart';
import '../../core/api/media_service.dart';
import '../../core/api/api_service.dart';
import '../../core/models/feed_post_model.dart';
import '../../core/models/feed_comment_model.dart';
import '../../core/models/feed_post_media_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../widgets/flags/flag_reason_sheet.dart';
import '../../core/utils/flag_error_resolver.dart';
import '../../core/utils/flag_duplicate_guard.dart';
import '../../widgets/safe_network_avatar.dart';
import '../expenditure_detail_screen.dart';

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
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _purpleLight = Color(0xFFF5F3FF);

  // ─── Status mapping (giống web) ────────────────────────────────────────────
  static const Map<String, String> _statusLabels = <String, String>{
    'PENDING': 'Chờ duyệt',
    'APPROVED': 'Đã duyệt',
    'REJECTED': 'Bị từ chối',
    'DISBURSED': 'Đã giải ngân',
    'COMPLETED': 'Hoàn thành',
  };

  static const Map<String, Color> _statusColors = <String, Color>{
    'PENDING': Colors.amber,
    'APPROVED': Colors.green,
    'REJECTED': Colors.red,
    'DISBURSED': Colors.blue,
    'COMPLETED': Colors.teal,
  };

  // ─── Services ──────────────────────────────────────────────────────────────
  final FeedService _feedSvc = FeedService();
  final MediaService _mediaSvc = MediaService();
  final ExpenditureService _expenditureSvc = ExpenditureService();
  final CampaignService _campaignSvc = CampaignService();
  final ApiService _api = ApiService();

  // ─── State ─────────────────────────────────────────────────────────────────
  FeedPostModel? _post;
  List<FeedCommentModel> _comments = <FeedCommentModel>[];
  List<FeedPostMediaItem> _media = <FeedPostMediaItem>[];
  bool _loadingPost = true;
  bool _loadingComments = true;
  bool _sendingComment = false;

  // Evidence Info Card data
  Map<String, dynamic>? _expenditureData;
  String? _campaignTitle;
  bool _loadingEvidence = false;
  bool _flagged = false;

  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  static final Set<int> _seenInSession = <int>{};

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadComments();
    _loadMedia();
    _markSeenOnce();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Evidence helpers ──────────────────────────────────────────────────────
  static bool _isEvidence(FeedPostModel post) {
    final String tt = (post.targetType ?? '').trim().toUpperCase();
    final String tn = (post.targetName ?? '').trim().toLowerCase();
    return tt == 'EXPENDITURE' && tn.startsWith('evidence');
  }

  /// Extract planName từ targetName pipe format: "evidence|Đợt 1: Mua sắm..."
  /// - Không có pipe → null
  /// - Có pipe nhưng suffix rỗng hoặc chỉ toàn số (ID) → null
  /// - Có pipe + suffix là tên đợt → trả suffix
  static String? _extractPlanName(String? raw) {
    final String t = (raw ?? '').trim();
    if (!t.contains('|')) return null;
    final List<String> parts = t.split('|');
    if (parts.length < 2) return null;
    final String suffix = parts.sublist(1).join('|').trim();
    if (suffix.isEmpty) return null;
    // Nếu suffix chỉ toàn số → đó là ID, không phải tên đợt
    if (RegExp(r'^\d+$').hasMatch(suffix)) return null;
    return suffix;
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
        await _loadFlagStatus();
        // Fetch evidence data after post loaded
        if (_post != null && _isEvidence(_post!)) {
          _loadEvidenceData();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPost = false);
    }
  }

  Future<void> _loadFlagStatus() async {
    if (_post == null) return;
    try {
      final res = await _api.getMyFlags(page: 0, size: 100);
      final dynamic data = res.data;
      List<dynamic> content = <dynamic>[];
      if (data is Map<String, dynamic> && data['content'] is List) {
        content = data['content'] as List<dynamic>;
      } else if (data is List<dynamic>) {
        content = data;
      }
      final bool flagged = content.any((f) =>
          f is Map<String, dynamic> &&
          _parseInt(f['postId']) == _post!.id);
      if (mounted) setState(() => _flagged = flagged);
    } catch (_) {}
  }

  Future<void> _flagPost() async {
    if (_post == null) return;
    final reason = await showCampaignFlagReasonBottomSheet(context);
    if (reason == null || reason.isEmpty || !mounted) return;

    final dup = await hasSubmittedFlag(_api, postId: _post!.id);
    if (dup) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Bạn đã tố cáo bài viết này rồi.'),
          ),
        );
      }
      return;
    }

    try {
      await _api.submitFlag(postId: _post!.id, reason: reason);
      if (mounted) {
        setState(() => _flagged = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi báo cáo. Cảm ơn bạn.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(resolveFlagSubmitError(e)),
          ),
        );
      }
    }
  }

  Future<void> _loadEvidenceData() async {
    final FeedPostModel post = _post!;
    final int? targetId = post.targetId;
    if (targetId == null) return;

    setState(() => _loadingEvidence = true);

    try {
      // Fetch expenditure
      final Response<dynamic> expRes =
          await _expenditureSvc.getExpenditureById(targetId);
      final dynamic expData = expRes.data;
      if (expData is! Map<String, dynamic>) {
        if (mounted) setState(() => _loadingEvidence = false);
        return;
      }

      if (!mounted) return;
      setState(() {
        _expenditureData = Map<String, dynamic>.from(expData);
      });

      // Fetch campaign title
      final int? campaignId = _parseInt(expData['campaignId']) ??
          _parseInt((expData['campaign'] as Map?)?['id']);
      if (campaignId != null) {
        try {
          final Response<dynamic> cRes =
              await _campaignSvc.getCampaign(campaignId);
          if (cRes.data is Map<String, dynamic>) {
            final Map<String, dynamic> cData =
                cRes.data as Map<String, dynamic>;
            if (mounted) {
              setState(() {
                _campaignTitle = (cData['title'] as String?) ?? '';
                // Store campaignId in expenditure data for navigation
                _expenditureData!['campaignId'] = campaignId;
              });
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      // Silently fail evidence loading
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
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

  Future<void> _markSeenOnce() async {
    if (_seenInSession.contains(widget.postId)) return;
    try {
      final Response<dynamic> res = await _feedSvc.markUserPostSeen(widget.postId);
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        _seenInSession.add(widget.postId);
        if (!mounted) return;
        setState(() {
          if (_post != null) {
            _post = _post!.copyWithViewCount(_post!.viewCount + 1);
          }
        });
      }
    } catch (_) {
      // Không chặn UX nếu mark seen lỗi.
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

  /// Nếu targetName bắt đầu bằng "evidence" → hiện "Minh chứng" hoặc "Minh chứng cho {planName}".
  /// Logic: dùng _extractPlanName() để phân biệt evidence có pipe vs không có pipe.
  static String _displayTargetName(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'^evidence', caseSensitive: false).hasMatch(t)) {
      final String? planName = _extractPlanName(t);
      if (planName != null) return 'Minh chứng cho $planName';
      return 'Minh chứng';
    }
    return t;
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final DateTime? d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    return DateFormat('dd/MM/yyyy').format(d);
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
        actions: [
          IconButton(
            tooltip: _flagged ? 'Đã tố cáo' : 'Tố cáo bài viết',
            onPressed: _flagPost,
            icon: Icon(
              _flagged ? Icons.flag : Icons.flag_outlined,
              color: _flagged ? const Color(0xFFEF4444) : null,
            ),
          ),
        ],
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
                            // ─── Evidence Info Card ─────────────────
                            if (_post != null && _isEvidence(_post!))
                              _buildEvidenceInfoCard(),
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

  // ─── Evidence Info Card ────────────────────────────────────────────────────
  Widget _buildEvidenceInfoCard() {
    final FeedPostModel post = _post!;
    final String? planNameFromTarget = _extractPlanName(post.targetName);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _purpleLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _purple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: _loadingEvidence && _expenditureData == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _purple,
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Badge "Minh chứng"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Minh chứng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tên đợt chi
                Text(
                  _expenditureData?['plan'] as String? ??
                      planNameFromTarget ??
                      'Đợt chi #${post.targetId ?? ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEA580C), // orange bold
                  ),
                ),

                // Chiến dịch
                if (_campaignTitle != null &&
                    _campaignTitle!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Chiến dịch: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _campaignTitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Trạng thái
                if (_expenditureData != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _buildStatusRow(),
                ],

                // Ngày tạo
                if (_expenditureData?['createdAt'] != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: _muted),
                      const SizedBox(width: 6),
                      Text(
                        'Ngày tạo: ${_formatDate(_expenditureData!['createdAt'] as String?)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Nút "Xem chi tiết"
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _navigateToExpenditureDetail,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: BorderSide(color: _purple.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text(
                      'Xem chi tiết',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusRow() {
    final String status =
        ((_expenditureData?['status'] ?? _expenditureData?['evidenceStatus']) as String? ?? '')
            .toUpperCase();
    final String label = _statusLabels[status] ?? status;
    final Color color = _statusColors[status] ?? _muted;

    return Row(
      children: <Widget>[
        const Text(
          'Trạng thái: ',
          style: TextStyle(
            fontSize: 13,
            color: _text,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToExpenditureDetail() async {
    if (_expenditureData == null && _post?.targetId == null) return;

    Map<String, dynamic> expenditure;
    String campaignType = 'ITEMIZED';

    if (_expenditureData != null) {
      expenditure = _expenditureData!;
      // Determine campaign type
      final int? campaignId = _parseInt(expenditure['campaignId']);
      if (campaignId != null) {
        try {
          final Response<dynamic> cRes =
              await _campaignSvc.getCampaign(campaignId);
          if (cRes.data is Map<String, dynamic>) {
            final dynamic t = (cRes.data as Map<String, dynamic>)['type'];
            if (t != null && t.toString().trim().isNotEmpty) {
              campaignType = t.toString().trim();
            }
          }
        } catch (_) {}
      }
    } else {
      // Fallback: fetch from API
      try {
        final Response<dynamic> res =
            await _expenditureSvc.getExpenditureById(_post!.targetId!);
        if (res.data is! Map<String, dynamic>) return;
        expenditure = Map<String, dynamic>.from(res.data as Map);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Không mở được minh chứng chi tiêu.')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenditureDetailScreen(
          expenditure: expenditure,
          campaignType: campaignType,
          forcePublicView: true,
        ),
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
              SafeNetworkAvatar(
                imageUrl: p.authorAvatar,
                name: p.authorName.isNotEmpty ? p.authorName : '?',
                radius: 22,
                backgroundColor: const Color(0xFFE5E7EB),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                  fontSize: 18,
                ),
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
                              _displayTargetName(p.targetName!),
                              style: TextStyle(
                                fontSize: 12,
                                color: _isEvidence(p)
                                    ? _purple
                                    : const Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
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
          SafeNetworkAvatar(
            imageUrl: comment.authorAvatar,
            name: comment.authorName.isNotEmpty ? comment.authorName : '?',
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
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
