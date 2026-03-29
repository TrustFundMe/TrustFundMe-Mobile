import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/payment_models.dart';
import 'donation_screen.dart';
import 'chat_screen.dart';
import '../widgets/feed/create_feed_post_sheet.dart';
import '../core/models/feed_post_model.dart';
import 'feed_post_detail_screen.dart';
import 'campaign_posts_screen.dart';
import '../widgets/flags/flag_reason_sheet.dart';
import '../core/utils/flag_error_resolver.dart';
import '../core/utils/flag_duplicate_guard.dart';

/// Màn chi tiết chiến dịch: số tiền đã quyên / mục tiêu / % và người ủng hộ gần đây (tương tự web campaigns-details).
class CampaignDetailScreen extends StatefulWidget {
  const CampaignDetailScreen({
    super.key,
    required this.campaign,
    this.initialProgress,
  });

  final CampaignModel campaign;
  final CampaignProgressModel? initialProgress;

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final ApiService _api = ApiService();

  /// Bản hiển thị (có thể được bổ sung từ API khi mở từ luồng chỉ có id + title, ví dụ màn Tác động).
  late CampaignModel _campaign;

  CampaignProgressModel? _progress;
  List<RecentDonorModel> _donors = <RecentDonorModel>[];
  List<FeedPostModel> _posts = <FeedPostModel>[];
  bool _loadingPosts = false;
  bool _loading = true;
  String? _errorMessage;
  bool _refreshCampaignsList = false;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _progress = widget.initialProgress;
    _load();
    _loadPosts();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      CampaignModel campaign = _campaign;
      final String? cover = campaign.coverImageUrl?.trim();
      if (cover == null || cover.isEmpty) {
        try {
          final dynamic cRes = await _api.getCampaign(_campaign.id);
          final dynamic raw = cRes.data;
          if (raw is Map<String, dynamic>) {
            campaign = CampaignModel.fromJson(raw);
          }
        } catch (_) {
          // Giữ bản tối thiểu; ảnh bìa có thể vẫn trống nếu API lỗi.
        }
      }

      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.getCampaignProgress(_campaign.id),
        _api.getRecentDonors(_campaign.id, limit: 10),
      ]);

      final dynamic progRaw = results[0].data;
      final dynamic donorsRaw = results[1].data;

      CampaignProgressModel? nextProgress = _progress;
      if (progRaw is Map<String, dynamic>) {
        nextProgress = CampaignProgressModel.fromJson(progRaw);
      }

      final List<RecentDonorModel> donors = <RecentDonorModel>[];
      if (donorsRaw is List<dynamic>) {
        for (final dynamic e in donorsRaw) {
          if (e is Map<String, dynamic>) {
            try {
              donors.add(RecentDonorModel.fromJson(e));
            } catch (_) {
              // bỏ qua bản ghi lỗi định dạng
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _campaign = campaign;
        _progress = nextProgress;
        _donors = donors;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Không tải được chi tiết gây quỹ. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _loadPosts() async {
    if (_loadingPosts) return;
    if (mounted) setState(() => _loadingPosts = true);
    try {
      final res = await _api.getFeedPosts(
        page: 0,
        size: 12,
        campaignId: _campaign.id,
      );
      final dynamic data = res.data;
      if (data is! Map<String, dynamic>) return;
      final List<dynamic> content =
          data['content'] as List<dynamic>? ?? <dynamic>[];
      final Response<dynamic> expRes =
          await _api.getExpendituresByCampaign(_campaign.id);
      final Set<int> expenditureIds = <int>{};
      if (expRes.data is List<dynamic>) {
        for (final dynamic row in (expRes.data as List<dynamic>)) {
          if (row is Map<String, dynamic>) {
            final dynamic rawId = row['id'];
            final int? id = rawId is int
                ? rawId
                : int.tryParse(rawId?.toString() ?? '');
            if (id != null) expenditureIds.add(id);
          }
        }
      }
      final List<FeedPostModel> list = content
          .whereType<Map<String, dynamic>>()
          .map(FeedPostModel.fromJson)
          .where((FeedPostModel p) {
            final String type = (p.targetType ?? '').toUpperCase();
            if (type == 'CAMPAIGN') {
              return p.targetId == _campaign.id;
            }
            if (type == 'EXPENDITURE') {
              return p.targetId != null && expenditureIds.contains(p.targetId);
            }
            return false;
          })
          .toList()
        ..sort((FeedPostModel a, FeedPostModel b) {
          final DateTime ta =
              DateTime.tryParse((a.updatedAt ?? a.createdAt).replaceFirst(' ', 'T')) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime tb =
              DateTime.tryParse((b.updatedAt ?? b.createdAt).replaceFirst(' ', 'T')) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      final List<FeedPostModel> top = list.take(4).toList();
      if (!mounted) return;
      setState(() => _posts = top);
    } catch (_) {
      if (!mounted) return;
      setState(() => _posts = <FeedPostModel>[]);
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _flagCampaign() async {
    final String? r = await showCampaignFlagReasonBottomSheet(context);
    if (r == null || r.isEmpty || !mounted) return;
    final bool duplicated =
        await hasSubmittedFlag(_api, campaignId: _campaign.id);
    if (duplicated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Bạn đã tố cáo chiến dịch này rồi.'),
        ),
      );
      return;
    }
    try {
      await _api.submitFlag(campaignId: _campaign.id, reason: r);
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

  Future<void> _openDonate() async {
    final bool? shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DonationScreen(campaign: _campaign),
      ),
    );
    if (shouldRefresh == true && mounted) {
      setState(() {
        _refreshCampaignsList = true;
      });
      await _load();
    }
  }

  String _fmtInt(int value) {
    return NumberFormat.decimalPattern('vi_VN').format(value);
  }

  String _timeAgo(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final DateTime? date = DateTime.tryParse(dateString);
      if (date == null) return dateString;
      final Duration diff = DateTime.now().difference(date);
      final int sec = diff.inSeconds;
      if (sec < 60) return 'Vừa xong';
      if (sec < 3600) return '${sec ~/ 60} phút trước';
      if (sec < 86400) return '${sec ~/ 3600} giờ trước';
      return DateFormat.yMd('vi_VN').format(date);
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color webPrimary = Color(0xFFF84D43);
    const Color webBgGray = Color(0xFFF9FAFB);
    const Color webTextDark = Color(0xFF1F2937);
    const Color webMuted = Color(0xFF6B7280);
    const Color webGreen = Color(0xFF1A685B);

    final int raised = _progress?.raisedAmount ?? 0;
    final int goal = _progress?.goalAmount ?? 0;
    final int pct = _progress?.progressPercentage ?? 0;
    final double ratio = (pct / 100).clamp(0.0, 1.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Navigator.of(context).pop(_refreshCampaignsList);
      },
      child: Scaffold(
        backgroundColor: webBgGray,
        appBar: AppBar(
          title: const Text(
            'Chi tiết chiến dịch',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: webTextDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_refreshCampaignsList),
          ),
          actions: [
            IconButton(
              tooltip: 'Báo cáo chiến dịch',
              icon: const Icon(Icons.flag_outlined, color: webTextDark),
              onPressed: _flagCampaign,
            ),
            IconButton(
              tooltip: 'Đăng bài về chiến dịch',
              icon: const Icon(Icons.post_add_outlined, color: webGreen),
              onPressed: () {
                showCreateFeedPostSheet(
                  context,
                  linkedCampaignId: _campaign.id,
                  linkedCampaignTitle: _campaign.title,
                  onCreated: () {
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: webPrimary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      campaignId: _campaign.id,
                      campaignTitle: _campaign.title,
                      staffId: _campaign.assignedStaffId,
                      staffName: _campaign.assignedStaffName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF202426),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: _openDonate,
                child: const Text(
                  'Quyên góp ngay',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: _campaign.coverImageUrl != null &&
                                _campaign.coverImageUrl!.isNotEmpty
                            ? Image.network(
                                _campaign.coverImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (BuildContext context, Object error, StackTrace? st) =>
                                        _coverPlaceholder(),
                              )
                            : _coverPlaceholder(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _campaign.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: webTextDark,
                            ),
                          ),
                          if ((_campaign.categoryName ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _campaign.categoryName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: webMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: _loading && _progress == null
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            SizedBox(
                                              width: 72,
                                              height: 72,
                                              child: CircularProgressIndicator(
                                                value: ratio,
                                                strokeWidth: 8,
                                                backgroundColor: Colors.black.withOpacity(0.1),
                                                color: webPrimary,
                                                strokeCap: StrokeCap.round,
                                              ),
                                            ),
                                            Text(
                                              '$pct%',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                color: Color(0xFF202426),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              'Tiến trình gây quỹ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                height: 1.2,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Trạng thái gây quỹ hiện tại',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: webMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _MoneyBlock(
                                          label: 'Đã quyên góp',
                                          value: '${_fmtInt(raised)} đ',
                                          emphasize: true,
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 44,
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                      Expanded(
                                        child: _MoneyBlock(
                                          label: 'Mục tiêu',
                                          value: '${_fmtInt(goal)} đ',
                                          emphasize: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Còn lại: ${_fmtInt((goal - raised).clamp(0, goal))} đ',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: webMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_campaign.description?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Giới thiệu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: webTextDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _campaign.description!.trim(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Người vừa ủng hộ',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF202426),
                                  ),
                                ),
                                Text(
                                  'Mới nhất',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: webPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_donors.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Chưa có người ủng hộ nào',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: webMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ..._donors.map((RecentDonorModel d) {
                                final String name = d.anonymous
                                    ? 'Người ủng hộ ẩn danh'
                                    : d.donorName;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      ClipOval(
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: d.donorAvatar != null &&
                                                  d.donorAvatar!.isNotEmpty
                                              ? Image.network(
                                                  d.donorAvatar!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (BuildContext c, Object e, StackTrace? s) =>
                                                          _avatarFallback(),
                                                )
                                              : _avatarFallback(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF202426),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _timeAgo(d.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.black.withOpacity(0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '+${_fmtInt(d.amount)} đ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: webGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                const Text(
                                  'Bài viết về chiến dịch',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF202426),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => CampaignPostsScreen(
                                          campaignId: _campaign.id,
                                          campaignTitle: _campaign.title,
                                        ),
                                      ),
                                    );
                                    if (mounted) await _loadPosts();
                                  },
                                  child: const Text(
                                    'Xem thêm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: webGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_loadingPosts)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_posts.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Chưa có bài viết nào',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: webMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ..._posts.map((FeedPostModel p) {
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => FeedPostDetailScreen(
                                          postId: p.id,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          (p.title ?? '').trim().isEmpty
                                              ? 'Bài viết #${p.id}'
                                              : p.title!.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: webTextDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          p.authorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: webMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: <Widget>[
                                            const Icon(
                                              Icons.remove_red_eye_outlined,
                                              size: 16,
                                              color: webMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.viewCount}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: webMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            const Icon(
                                              Icons.favorite_border,
                                              size: 16,
                                              color: webMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.likeCount}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: webMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            const Icon(
                                              Icons.mode_comment_outlined,
                                              size: 16,
                                              color: webMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.commentCount}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: webMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
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
    );
  }

  Widget _coverPlaceholder() {
    return ColoredBox(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Text(
          'Ảnh bìa',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return ColoredBox(
      color: const Color(0xFFEEEEEE),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MoneyBlock extends StatelessWidget {
  const _MoneyBlock({
    required this.label,
    required this.value,
    required this.emphasize,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 17 : 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF202426),
            ),
          ),
        ],
      ),
    );
  }
}
