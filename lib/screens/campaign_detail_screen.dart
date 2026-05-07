import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/api/donation_service.dart';
import '../core/api/expenditure_service.dart';
import '../core/api/media_service.dart';
import '../core/api/trust_score_service.dart';
import '../core/api/user_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/payment_models.dart';
import '../core/models/feed_post_model.dart';
import '../core/providers/auth_provider.dart';
import 'donation/vietqr_screen.dart';
import 'feed_post_detail_screen.dart';
import 'campaign_posts_screen.dart';
import 'expenditure_detail_screen.dart';
import '../widgets/flags/flag_reason_sheet.dart';
import '../widgets/safe_network_avatar.dart';
import '../core/utils/flag_error_resolver.dart';
import '../core/utils/flag_duplicate_guard.dart';

// ─────────────────── Constants ───────────────────
const Color _brand = Color(0xFFFF5E14);
const Color _dark = Color(0xFF0F172A);
const Color _muted = Color(0xFF94A3B8);
const Color _bgGray = Color(0xFFF8FAFC);
const Color _textDark = Color(0xFF1F2937);
const Color _green = Color(0xFF10B981);
const Color _red = Color(0xFFEF4444);

const List<int> _quickAmounts = [50000, 100000, 200000, 500000];

// ─────────────────── Helpers ───────────────────
String _fmtMoney(int v) => NumberFormat.decimalPattern('vi_VN').format(v);

String _timeAgo(String dateString) {
  if (dateString.isEmpty) return '';
  try {
    final DateTime? date = DateTime.tryParse(dateString);
    if (date == null) return dateString;
    final int sec = DateTime.now().difference(date).inSeconds;
    if (sec < 60) return 'Vừa xong';
    if (sec < 3600) return '${sec ~/ 60} phút trước';
    if (sec < 86400) return '${sec ~/ 3600} giờ trước';
    return DateFormat('dd/MM/yyyy').format(date);
  } catch (_) {
    return dateString;
  }
}

String _formatVnDateRange(String? start, String? end, [String? fallback]) {
  if ((start == null || start.isEmpty) && (end == null || end.isEmpty)) {
    return fallback ?? '';
  }
  String fmt(String s) {
    final d = DateTime.tryParse(s);
    return d != null ? DateFormat('dd/MM/yyyy').format(d) : s;
  }
  final a = start != null && start.isNotEmpty ? fmt(start) : '';
  final b = end != null && end.isNotEmpty ? fmt(end) : '';
  if (a.isNotEmpty && b.isNotEmpty) return '$a - $b';
  return a.isNotEmpty ? a : b.isNotEmpty ? b : (fallback ?? '');
}

String _statusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'Chờ xử lý';
    case 'PENDING_REVIEW':
      return 'Chờ duyệt';
    case 'APPROVED':
      return 'Đã duyệt';
    case 'ALLOWED_EDIT':
      return 'Yêu cầu chỉnh sửa';
    case 'WITHDRAWAL_REQUESTED':
      return 'Đã yêu cầu rút tiền';
    case 'DISBURSED':
      return 'Đã giải ngân';
    case 'COMPLETED':
      return 'Hoàn thành';
    case 'CLOSED':
      return 'Đã đóng';
    case 'REJECTED':
      return 'Từ chối';
    default:
      return status;
  }
}


// ─────────────────── Main Screen ───────────────────

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
  final DonationService _donationSvc = DonationService();
  final ExpenditureService _expenditureSvc = ExpenditureService();
  final MediaService _mediaSvc = MediaService();
  final UserService _userSvc = UserService();
  final TrustScoreService _trustScoreSvc = TrustScoreService();

  late CampaignModel _campaign;
  CampaignProgressModel? _progress;
  List<RecentDonorModel> _donors = [];
  List<FeedPostModel> _posts = [];
  List<ExpenditurePlanModel> _plans = [];
  List<String> _galleryImages = [];

  // Creator info
  String _creatorName = '';
  String _creatorAvatar = '';
  int? _creatorTrustScore;

  // Follow/flag
  bool _followed = false;
  int _followerCount = 0;
  bool _flagged = false;

  bool _loading = true;
  bool _loadingCreator = true;
  bool _loadingPosts = false;
  String? _errorMessage;
  bool _refreshCampaignsList = false;
  bool _descExpanded = false;

  // Inline donate
  int _donateAmount = 50000;
  bool _isAnonymous = false;
  bool _isAgreed = false;
  bool _donateLoading = false;

  // Gallery
  int _galleryIndex = 0;
  final PageController _galleryCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _progress = widget.initialProgress;
    _load();
    _loadPosts();
  }

  @override
  void dispose() {
    _galleryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _loadingCreator = true; _errorMessage = null; });

    try {
      // Phase 1: Critical data in parallel — each non-critical call has catchError
      // so a single service failure doesn't crash the entire page.
      final results = await Future.wait<dynamic>([
        _api.getCampaign(_campaign.id),
        _donationSvc.getCampaignProgress(_campaign.id).then<dynamic>((r) => r).catchError((_) => null),
        _donationSvc.getRecentDonors(_campaign.id, limit: 10).then<dynamic>((r) => r).catchError((_) => null),
        _expenditureSvc.getExpendituresByCampaign(_campaign.id).then<dynamic>((r) => r).catchError((_) => null),
        _mediaSvc.getMediaByCampaignId(_campaign.id).then<dynamic>((r) => r).catchError((_) => null),
      ]);

      if (!mounted) return;

      // Parse campaign
      final dynamic r0 = results[0];
      final dynamic cRaw = _unwrap(r0);
      if (cRaw is Map<String, dynamic>) {
        _campaign = CampaignModel.fromJson(cRaw);
        final dynamic followerRaw =
            cRaw['followerCount'] ?? cRaw['followersCount'] ?? cRaw['followCount'];
        if (followerRaw is num) {
          _followerCount = followerRaw.toInt();
        }
      } else {
        // If critical data is missing or in wrong format, throw to show error state
        throw Exception('Invalid campaign data format');
      }

      // Parse progress
      final dynamic r1 = results[1];
      final dynamic pRaw = _unwrap(r1);
      if (pRaw is Map<String, dynamic>) {
        try {
          _progress = CampaignProgressModel.fromJson(pRaw);
        } catch (_) {}
      }

      // Parse donors
      final dynamic r2 = results[2];
      final dynamic dRaw = _unwrap(r2);
      if (dRaw is List) {
        _donors = dRaw
            .whereType<Map<String, dynamic>>()
            .map((e) {
              try { return RecentDonorModel.fromJson(e); } catch (_) { return null; }
            })
            .whereType<RecentDonorModel>()
            .toList();
      } else if (dRaw is Map<String, dynamic> && dRaw['content'] is List) {
        // Handle paginated donors if backend returns it that way
        final List<dynamic> content = dRaw['content'] as List<dynamic>;
        _donors = content
            .whereType<Map<String, dynamic>>()
            .map((e) {
              try { return RecentDonorModel.fromJson(e); } catch (_) { return null; }
            })
            .whereType<RecentDonorModel>()
            .toList();
      }

      // Parse expenditures → plans (đồng bộ logic danbox: backend thường không nhúng
      // categories trong GET /expenditures/campaign/{id}, phải gọi thêm GET .../categories)
      final dynamic r3 = results[3];
      final dynamic eRaw = _unwrap(r3);
      if (eRaw is List) {
        try {
          final enriched = await _embedExpenditureCategoriesIfNeeded(eRaw);
          _plans = _parseExpenditures(enriched);
        } catch (_) {}
      } else if (eRaw is Map<String, dynamic> && eRaw['content'] is List) {
        try {
          final enriched = await _embedExpenditureCategoriesIfNeeded(
            eRaw['content'] as List<dynamic>,
          );
          _plans = _parseExpenditures(enriched);
        } catch (_) {}
      }

      // Parse media → gallery
      final dynamic r4 = results[4];
      final dynamic mRaw = _unwrap(r4);
      if (mRaw is List) {
        final List<String> photos = [];
        String? coverUrl;
        final coverRef = _campaign.coverImageUrl ?? '';
        final coverRefInt = int.tryParse(coverRef);
        for (final m in mRaw) {
          if (m is Map<String, dynamic>) {
            final type = (m['mediaType'] ?? m['type'] ?? '').toString();
            final url = (m['url'] ?? '').toString();
            if (url.isEmpty) continue;
            final mediaId = m['id'];
            if (coverRefInt != null && mediaId == coverRefInt) {
              coverUrl = url;
            } else if (mediaId != null && mediaId.toString() == coverRef) {
              coverUrl = url;
            }
            if (type == 'PHOTO' || type == 'VIDEO') {
              photos.add(url);
            }
          }
        }
        if (coverUrl != null && !photos.contains(coverUrl)) {
          photos.insert(0, coverUrl);
        }
        _galleryImages = photos;
      }

      // Fallback gallery: use coverImageUrl if no media
      if (_galleryImages.isEmpty && (_campaign.coverImageUrl?.isNotEmpty == true)) {
        _galleryImages = [_campaign.coverImageUrl!];
      }

      // ── Fetch creator info (critical — must complete before UI renders) ──
      final ownerId = _campaign.fundOwnerId;
      if (ownerId != null && mounted) {
        try {
          final ownerResults = await Future.wait<dynamic>([
            _userSvc.getUserById(ownerId).then<dynamic>((r) => r).catchError((_) => null),
            _trustScoreSvc.getUserScore(ownerId).then<dynamic>((r) => r).catchError((_) => null),
          ]);

          if (mounted) {
            // Owner info
            final dynamic o0 = ownerResults[0];
            final dynamic uRaw = o0 is Response ? o0.data : null;
            if (uRaw is Map<String, dynamic>) {
              if (uRaw.containsKey('fullName')) {
                _creatorName = (uRaw['fullName'] ?? '') as String;
                _creatorAvatar = (uRaw['avatarUrl'] ?? '') as String;
              } else {
                final data = uRaw['data'];
                if (data is Map<String, dynamic>) {
                  _creatorName = (data['fullName'] ?? '') as String;
                  _creatorAvatar = (data['avatarUrl'] ?? '') as String;
                }
              }
            }

            // Trust score
            final dynamic o1 = ownerResults[1];
            final dynamic tsRaw = o1 is Response ? o1.data : null;
            if (tsRaw is Map<String, dynamic>) {
              final totalScore = tsRaw['totalScore'];
              if (totalScore is num && totalScore > 0) {
                _creatorTrustScore = totalScore.toInt();
              }
            }
          }
        } catch (_) {
          // Creator info fetch failed — non-fatal, fallback name will show
        }
      }

      if (mounted) setState(() { _loading = false; _loadingCreator = false; });

      // Phase 2: Non-blocking — follow/flag info
      await _loadSecondaryData();
    } catch (e) {
      if (!mounted) return;
      // Luôn tắt loading. Chỉ set errorMessage khi KHÔNG có data nào để hiển thị.
      // Nếu widget.campaign đã có id hợp lệ (đến từ danh sách), render với data sẵn có
      // và chỉ thông báo toast thay vì chặn toàn bộ màn hình.
      debugPrint('[CampaignDetail] _load lỗi id=${_campaign.id}: $e');
      if (_campaign.id > 0) {
        setState(() { _loading = false; _loadingCreator = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể làm mới dữ liệu. Kéo xuống để thử lại.'),
            action: SnackBarAction(
              label: 'Thử lại',
              onPressed: _load,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _loadingCreator = false;
          _errorMessage = 'Không tải được chi tiết. Kéo xuống để thử lại.';
        });
      }
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      // Owner info + trust score are already fetched in Phase 1 (_load).
      // Phase 2 only fetches follow/flag status — non-critical UI data.
      final results = await Future.wait<dynamic>([
        _api.isFollowingCampaign(_campaign.id).then<dynamic>((r) => r).catchError((_) => null),
        _api.getMyFlags(page: 0, size: 100).then<dynamic>((r) => r).catchError((_) => null),
        _api.getCampaignFollowerCount(_campaign.id).then<dynamic>((r) => r).catchError((_) => null),
      ]);

      if (!mounted) return;

      // Follow status
      final dynamic s0 = results[0];
      final dynamic fRaw = s0 is Response ? s0.data : null;
      if (fRaw is bool) {
        _followed = fRaw;
      } else if (fRaw is Map && fRaw['following'] != null) {
        _followed = fRaw['following'] as bool;
      }

      // Flag check
      final dynamic s1 = results[1];
      final dynamic flagRaw = s1 is Response ? s1.data : null;
      if (flagRaw is Map<String, dynamic>) {
        final content = flagRaw['content'];
        if (content is List) {
          _flagged = content.any((f) =>
              f is Map<String, dynamic> && f['campaignId'] == _campaign.id);
        }
      } else if (flagRaw is List) {
        // Some backends return flags as a direct list
        _flagged = flagRaw.any((f) =>
            f is Map<String, dynamic> && f['campaignId'] == _campaign.id);
      }

      // Follower count
      final dynamic s2 = results[2];
      final dynamic countRaw = s2 is Response ? s2.data : null;
      if (countRaw is num) {
        _followerCount = countRaw.toInt();
      } else if (countRaw is Map && countRaw['count'] is num) {
        _followerCount = (countRaw['count'] as num).toInt();
      }

      if (mounted) setState(() {});
    } catch (_) {
      // Non-critical, silently ignore
    }
  }

  /// Giống [campaigns-details/page.tsx]: nếu expenditure không có `categories` trong
  /// payload list campaign, fetch từng `/expenditures/{id}/categories` kèm items.
  Future<List<dynamic>> _embedExpenditureCategoriesIfNeeded(
    List<dynamic> raw,
  ) async {
    final out = <dynamic>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) {
        out.add(e);
        continue;
      }
      final m = Map<String, dynamic>.from(e);
      final cats = m['categories'] as List<dynamic>?;
      if (cats != null && cats.isNotEmpty) {
        out.add(m);
        continue;
      }
      final id = (m['id'] as num?)?.toInt();
      if (id == null) {
        out.add(m);
        continue;
      }
      try {
        final res = await _expenditureSvc.getExpenditureCategories(id);
        final data = res.data;
        if (data is List<dynamic> && data.isNotEmpty) {
          m['categories'] = data;
        }
      } catch (_) {
        // giữ không categories — expandable vẫn hiện như hiện tại
      }
      out.add(m);
    }
    return out;
  }

  List<ExpenditurePlanModel> _parseExpenditures(List<dynamic> raw) {
    final sorted = [...raw]
      ..sort((a, b) {
        final aId = (a is Map ? (a['id'] as num?)?.toInt() : 0) ?? 0;
        final bId = (b is Map ? (b['id'] as num?)?.toInt() : 0) ?? 0;
        return aId.compareTo(bId);
      });

    return sorted.map((exp) {
      if (exp is! Map<String, dynamic>) return null;
      final List<ExpenditureCategoryModel> cats = [];
      final rawCats = exp['categories'] as List<dynamic>? ?? [];
      for (final cat in rawCats) {
        if (cat is! Map<String, dynamic>) continue;
        final items = (cat['items'] as List<dynamic>? ?? []).map((item) {
          if (item is! Map<String, dynamic>) {
            return ExpenditureCategoryItemModel(name: '');
          }
          return ExpenditureCategoryItemModel(
            id: (item['id'] as num?)?.toInt(),
            name: (item['category'] ?? item['name'] ?? 'Hạng mục') as String,
            expectedQuantity: (item['quantity'] ?? item['expectedQuantity'] as num? ?? 0).toInt(),
            expectedPrice: (item['expectedPrice'] as num?)?.toInt() ?? 0,
            actualQuantity: (item['actualQuantity'] as num?)?.toInt() ?? 0,
            price: (item['price'] as num?)?.toInt() ?? 0,
            note: item['note'] as String?,
          );
        }).toList();

        cats.add(ExpenditureCategoryModel(
          id: (cat['id'] as num?)?.toInt(),
          name: (cat['name'] ?? 'Nhóm hạng mục') as String,
          description: cat['description'] as String?,
          expectedAmount: (cat['expectedAmount'] as num?)?.toInt() ?? 0,
          actualAmount: (cat['actualAmount'] as num?)?.toInt() ?? 0,
          items: items,
        ));
      }

      final totalItems = cats.fold<int>(0, (s, c) => s + c.items.length);
      final date = _formatVnDateRange(
        exp['startDate'] as String?,
        exp['endDate'] as String?,
        exp['createdAt'] != null
            ? DateFormat('dd/MM/yyyy')
                .format(DateTime.tryParse(exp['createdAt'].toString()) ?? DateTime.now())
            : null,
      );

      return ExpenditurePlanModel(
        id: (exp['id'] as num?)?.toInt() ?? 0,
        title: (exp['plan'] ?? 'Milestone') as String,
        amount: (exp['totalExpectedAmount'] ?? exp['totalAmount'] as num? ?? 0).toInt(),
        description: cats.where((c) => (c.description ?? '').trim().isNotEmpty).firstOrNull?.description,
        date: date,
        status: exp['status'] as String?,
        startDate: exp['startDate'] as String?,
        endDate: exp['endDate'] as String?,
        totalItems: totalItems,
        categories: cats,
      );
    }).whereType<ExpenditurePlanModel>().toList();
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
      final content = data['content'] as List<dynamic>? ?? [];

      final expenditureIds = <int>{};
      try {
        final expRes = await _expenditureSvc.getExpendituresByCampaign(_campaign.id);
        if (expRes.data is List) {
          for (final row in (expRes.data as List)) {
            if (row is Map<String, dynamic>) {
              final id = row['id'];
              if (id is int) expenditureIds.add(id);
            }
          }
        }
      } catch (_) {
        // Expenditure fetch failed — proceed with campaign-only posts
      }

      final list = content
          .whereType<Map<String, dynamic>>()
          .map(FeedPostModel.fromJson)
          .where((p) {
            final type = (p.targetType ?? '').toUpperCase();
            if (type == 'CAMPAIGN') return p.targetId == _campaign.id;
            if (type == 'EXPENDITURE') return p.targetId != null && expenditureIds.contains(p.targetId);
            return false;
          })
          .toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse((a.updatedAt ?? a.createdAt).replaceFirst(' ', 'T')) ?? DateTime(2000);
          final tb = DateTime.tryParse((b.updatedAt ?? b.createdAt).replaceFirst(' ', 'T')) ?? DateTime(2000);
          return tb.compareTo(ta);
        });

      if (!mounted) return;
      setState(() => _posts = list.take(4).toList());
    } catch (_) {
      if (mounted) setState(() => _posts = []);
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (_followed) {
        await _api.unfollowCampaign(_campaign.id);
      } else {
        await _api.followCampaign(_campaign.id);
      }
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _followed = !_followed;
          _followerCount = (_followerCount + (_followed ? 1 : -1)).clamp(0, 1 << 30);
        });
      }
    } catch (_) {}
  }

  Future<void> _flagCampaign() async {
    final reason = await showCampaignFlagReasonBottomSheet(context);
    if (reason == null || reason.isEmpty || !mounted) return;

    final dup = await hasSubmittedFlag(_api, campaignId: _campaign.id);
    if (dup) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _red,
            content: Text('Bạn đã tố cáo chiến dịch này rồi.'),
          ),
        );
      }
      return;
    }

    try {
      await _api.submitFlag(campaignId: _campaign.id, reason: reason);
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
            backgroundColor: _red,
            content: Text(resolveFlagSubmitError(e)),
          ),
        );
      }
    }
  }

  Future<void> _handleDirectDonate() async {
    if (_donateAmount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền tối thiểu là 10.000 đ')),
      );
      return;
    }

    final int raised = _progress?.raisedAmount ?? 0;
    final int goal = _progress?.goalAmount ?? 0;
    final int remaining = (goal - raised).clamp(0, goal);
    if (goal > 0 && _donateAmount > remaining) {
      final bool continueDonate = await _showDonationExceedWarning(
        goalAmount: goal,
        raisedAmount: raised,
        donationAmount: _donateAmount,
      );
      if (!continueDonate) return;
    }

    setState(() => _donateLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final int? donorId = auth.user?.id;
      final userIdStr = donorId?.toString() ?? 'GUEST';
      final description = 'USER${userIdStr}CAMPAIGN${_campaign.id}';

      final payload = CreatePaymentRequestModel(
        donorId: donorId,
        campaignId: _campaign.id,
        donationAmount: _donateAmount,
        tipAmount: 0,
        description: description,
        isAnonymous: _isAnonymous || donorId == null,
        items: [],
      );

      final res = await _donationSvc.createPayment(payload.toJson());
      final data = res.data as Map<String, dynamic>;
      final paymentUrl = data['paymentUrl'] as String?;
      final donationId = (data['donationId'] as num?)?.toInt();
      final orderCode = data['paymentLinkId'] as String?;

      if (paymentUrl != null && paymentUrl.isNotEmpty && donationId != null) {
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => VietQRScreen(
              qrUrl: paymentUrl,
              donationId: donationId,
              orderCode: orderCode,
              amount: _donateAmount,
              campaignTitle: _campaign.title,
            ),
          ),
        );
        if (mounted) {
          _refreshCampaignsList = true;
          await _load();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không nhận được liên kết thanh toán')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khởi tạo thanh toán: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _donateLoading = false);
    }
  }

  Future<bool> _showDonationExceedWarning({
    required int goalAmount,
    required int raisedAmount,
    required int donationAmount,
  }) async {
    final int remaining = (goalAmount - raisedAmount).clamp(0, goalAmount);
    final int excess = (donationAmount - remaining).clamp(0, donationAmount);

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: const Text(
            'Số tiền vượt quá mục tiêu đợt này',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đợt này chỉ cần thêm ${_fmtMoney(remaining)} VNĐ nữa là hoàn thành. '
                'Phần dư sẽ được ưu tiên cho đợt tiếp theo của cùng chiến dịch.',
                style: const TextStyle(
                  fontSize: 13,
                  color: _textDark,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A0F172A)),
                ),
                child: Column(
                  children: [
                    _warnRow('Bạn muốn quyên góp', '${_fmtMoney(donationAmount)} VNĐ', _textDark),
                    const Divider(height: 14),
                    _warnRow('Vào đợt hiện tại', '${_fmtMoney(remaining)} VNĐ', _green),
                    const SizedBox(height: 6),
                    _warnRow('Giữ cho đợt tiếp theo', '+${_fmtMoney(excess)} VNĐ', _brand),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Tiếp tục quyên góp',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Điều chỉnh số tiền',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Widget _warnRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  /// Unwrap response data if it is wrapped in { data: ... } or { code, message, data }.
  dynamic _unwrap(dynamic r) {
    if (r is! Response) return r;
    final dynamic raw = r.data;
    if (raw is! Map<String, dynamic>) return raw;

    // Priority 1: Direct 'data' field
    if (raw.containsKey('data')) {
      final dynamic d = raw['data'];
      // If it's another map, it might be further wrapped (rare but happens in some gateways)
      if (d is Map<String, dynamic> && d.containsKey('data') && d.length == 1) {
        return d['data'];
      }
      return d;
    }

    // Priority 2: 'result' field (some APIs use this)
    if (raw.containsKey('result')) return raw['result'];

    // Priority 3: Fallback to the whole map if it looks like the actual object (has 'id' or other known fields)
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final int raised = _progress?.raisedAmount ?? 0;
    final int goal = _progress?.goalAmount ?? 0;
    final int pct = _progress?.progressPercentage ?? 0;
    final int donorCount = _progress?.donorCount ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_refreshCampaignsList);
      },
      child: Scaffold(
        backgroundColor: _bgGray,
        body: RefreshIndicator(
          onRefresh: () async {
            await _load();
            await _loadPosts();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ─── SliverAppBar with gallery ───
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: _dark,
                leading: _circleAppBarBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(_refreshCampaignsList),
                ),
                actions: [
                  _circleAppBarBtn(
                    icon: _flagged ? Icons.flag : Icons.flag_outlined,
                    color: _flagged ? _red : null,
                    onTap: _flagCampaign,
                  ),
                  _circleAppBarBtn(
                    icon: Icons.share_outlined,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // TODO: share
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _galleryImages.isEmpty
                      ? Container(color: const Color(0xFFE2E8F0))
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _galleryCtrl,
                              itemCount: _galleryImages.length,
                              onPageChanged: (i) =>
                                  setState(() => _galleryIndex = i),
                              itemBuilder: (_, i) => Image.network(
                                _galleryImages[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFE2E8F0),
                                  child: const Icon(Icons.broken_image,
                                      size: 48, color: _muted),
                                ),
                              ),
                            ),
                            if (_galleryImages.length > 1)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _galleryImages.length,
                                    (i) => AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      width: i == _galleryIndex ? 20 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(99),
                                        color: i == _galleryIndex
                                            ? _brand
                                            : Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),

              // ─── Content ───
              if (_loading && _progress == null)
                const SliverFillRemaining(
                  child: Center(child: _SkeletonBody()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: _ErrorState(
                    message: _errorMessage!,
                    onRetry: _load,
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category badge
                        if ((_campaign.categoryName ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: _brand.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                  color: Colors.black.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_campaign.categoryIconUrl != null &&
                                    _campaign.categoryIconUrl!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Image.network(
                                      _campaign.categoryIconUrl!,
                                      width: 18,
                                      height: 18,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                Text(
                                  _campaign.categoryName!.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          _campaign.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Creator info
                        _buildCreatorRow(),
                        const SizedBox(height: 12),

                        // Follow / Flag actions
                        _buildActionRow(),
                        const SizedBox(height: 16),

                        // Description
                        if ((_campaign.description ?? '').trim().isNotEmpty)
                          _buildDescriptionCard(),

                        const SizedBox(height: 14),

                        // ── Donate Card (inline) ──
                        _buildDonateCard(raised, goal, pct, donorCount),

                        const SizedBox(height: 14),

                        // Milestone Timeline / Hồ sơ chi tiêu
                        _buildMilestoneTimeline(raised),

                        const SizedBox(height: 14),

                        // Posts section
                        _buildPostsSection(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AppBar circle button ───
  Widget _circleAppBarBtn({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.black.withOpacity(0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color ?? Colors.white),
          ),
        ),
      ),
    );
  }

  // ─── Creator row ───
  Widget _buildCreatorRow() {
    // While creator info is still loading, show a shimmer-like placeholder
    // instead of the raw "Người tạo #30002" fallback.
    final bool stillLoading = _loadingCreator && _creatorName.isEmpty;

    if (stillLoading) {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final name = _creatorName.isNotEmpty
        ? _creatorName
        : 'Người tạo #${_campaign.fundOwnerId ?? ''}';
    return Row(
      children: [
        SafeNetworkAvatar(
          imageUrl: _creatorAvatar.isNotEmpty ? _creatorAvatar : null,
          name: _creatorName.isNotEmpty ? _creatorName : 'U',
          radius: 22,
          backgroundColor: const Color(0xFFE2E8F0),
          fallbackIcon: const Icon(Icons.person, color: _muted, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Người tạo',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_campaign.kycVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.verified, color: _brand, size: 16),
                    ),
                  if (_creatorTrustScore != null && _creatorTrustScore! > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _brand.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(99),
                        border:
                            Border.all(color: _brand.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: Color(0xFFEA580C), size: 11),
                          const SizedBox(width: 3),
                          Text(
                            '$_creatorTrustScore',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEA580C),
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
    );
  }

  // ─── Action row: Follow + Flag ───
  Widget _buildActionRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _actionChip(
          icon: _followed ? Icons.person_remove : Icons.person_add_alt_1,
          label: _followed
              ? 'Đang theo dõi ($_followerCount)'
              : 'Theo dõi ($_followerCount)',
          active: _followed,
          onTap: _toggleFollow,
        ),
        _actionChip(
          icon: _flagged ? Icons.flag : Icons.flag_outlined,
          label: _flagged ? 'Đã tố cáo' : 'Tố cáo',
          active: _flagged,
          color: _red,
          onTap: _flagCampaign,
        ),
      ],
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required bool active,
    Color? color,
    required VoidCallback onTap,
  }) {
    final c = color ?? const Color(0xFF0F5D51);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? c : _muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? c : _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Description ───
  Widget _buildDescriptionCard() {
    final desc = _campaign.description!.trim();
    final isLong = desc.length > 200;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A0F172A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giới thiệu chiến dịch',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            maxLines: _descExpanded ? null : 5,
            overflow: _descExpanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF334155),
            ),
          ),
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _descExpanded ? 'Thu gọn' : 'Xem thêm',
                  style: const TextStyle(
                    color: _brand,
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

  // ─── Donate Card (inline) — redesigned to match web layout ───
  Widget _buildDonateCard(int raised, int goal, int pct, int donorCount) {
    // ── Color constants matching web design ──
    const Color primaryOrange = Color(0xFFEA580C);   // orange-600
    const Color textPrimary = Color(0xFF1E3A5F);     // dark blue
    const Color textSecondary = Color(0xFF6B7280);   // gray-500
    const Color borderColor = Color(0xFFE5E7EB);     // gray-200
    const Color successGreen = Color(0xFF16A34A);

    final bool hasGoal = goal > 0;
    final int percentLabel = hasGoal
        ? ((raised * 100) ~/ goal).clamp(0, 999)
        : pct.clamp(0, 999);
    final double barRatio = hasGoal
        ? (raised / goal).clamp(0.0, 1.0)
        : (pct / 100).clamp(0.0, 1.0);

    // ── Campaign end date from milestones ──
    DateTime? campaignEndDate;
    for (final plan in _plans) {
      if (plan.endDate != null && plan.endDate!.isNotEmpty) {
        final dt = DateTime.tryParse(plan.endDate!);
        if (dt != null && (campaignEndDate == null || dt.isAfter(campaignEndDate))) {
          campaignEndDate = dt;
        }
      }
    }
    final int? remainingDays = campaignEndDate != null
        ? (() {
            final diffMs = campaignEndDate!.difference(DateTime.now()).inMilliseconds;
            return diffMs <= 0 ? 0 : (diffMs / (1000 * 60 * 60 * 24)).ceil();
          })()
        : null;
    final bool isExpired = remainingDays != null && remainingDays <= 0;

    // ── Campaign status check ──
    final String campaignStatus = (_campaign.status ?? '').toUpperCase();

    // Check if there's an approved milestone currently in date range
    bool hasApprovedMilestoneInRange() {
      final now = DateTime.now();
      for (final plan in _plans) {
        final s = (plan.status ?? '').toUpperCase();
        if (s == 'APPROVED') {
          final start = plan.startDate != null ? DateTime.tryParse(plan.startDate!) : null;
          final end = plan.endDate != null ? DateTime.tryParse(plan.endDate!) : null;
          if (start != null && end != null && now.isAfter(start) && now.isBefore(end.add(const Duration(days: 1)))) {
            return true;
          }
          // If no date constraints, consider it valid
          if (start == null && end == null) return true;
        }
      }
      return _plans.isEmpty; // No milestones = ok to donate
    }

    // ── Status overlay cards ──
    if (campaignStatus == 'CLOSED') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: successGreen),
            const SizedBox(height: 12),
            const Text(
              'Chiến dịch đã kết thúc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cảm ơn tất cả mọi người đã ủng hộ chiến dịch này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 16),
            // Still show progress summary
            _buildProgressSummary(raised, goal, percentLabel, barRatio, donorCount,
                textPrimary, textSecondary, primaryOrange, borderColor, successGreen),
            // Recent donors
            const SizedBox(height: 12),
            Divider(color: borderColor),
            const SizedBox(height: 8),
            _buildRecentDonorsSection(textPrimary, textSecondary, borderColor),
          ],
        ),
      );
    }

    if (campaignStatus == 'DISABLED') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.pause_circle_outline, size: 48, color: Color(0xFFEA580C)),
            const SizedBox(height: 12),
            const Text(
              'Chiến dịch tạm dừng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _campaign.rejectionReason ?? 'Chiến dịch đang tạm dừng nhận quyên góp.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 16),
            _buildProgressSummary(raised, goal, percentLabel, barRatio, donorCount,
                textPrimary, textSecondary, primaryOrange, borderColor, successGreen),
            const SizedBox(height: 12),
            Divider(color: borderColor),
            const SizedBox(height: 8),
            _buildRecentDonorsSection(textPrimary, textSecondary, borderColor),
          ],
        ),
      );
    }

    if (_plans.isNotEmpty && !hasApprovedMilestoneInRange()) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.hourglass_empty, size: 48, color: Color(0xFFEA580C)),
            const SizedBox(height: 12),
            const Text(
              'Tạm dừng nhận quyên góp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hiện tại không có đợt chi tiêu nào được duyệt trong khoảng thời gian này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 16),
            _buildProgressSummary(raised, goal, percentLabel, barRatio, donorCount,
                textPrimary, textSecondary, primaryOrange, borderColor, successGreen),
            const SizedBox(height: 12),
            Divider(color: borderColor),
            const SizedBox(height: 8),
            _buildRecentDonorsSection(textPrimary, textSecondary, borderColor),
          ],
        ),
      );
    }

    // ── Main donation card (active campaign) ──
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Header row: Goal + Remaining days ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: campaign goal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mục tiêu chiến dịch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasGoal ? '${_fmtMoney(goal)} VNĐ' : 'Chưa đặt',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: remaining days
              if (remainingDays != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Thời gian còn lại',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isExpired ? 'Đã hết hạn' : '$remainingDays ngày',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isExpired ? _red : primaryOrange,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 2. Progress section ──
          // "Đã đạt được X VNĐ" + "Y%"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Đã đạt được ${_fmtMoney(raised)} VNĐ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '$percentLabel%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: hasGoal && raised >= goal ? successGreen : primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  // Background
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                  // Fill with gradient
                  FractionallySizedBox(
                    widthFactor: barRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasGoal && raised >= goal
                              ? [successGreen, const Color(0xFF15803D)]
                              : [const Color(0xFFF97316), primaryOrange],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Donor count
          Text(
            'Lượt ủng hộ: $donorCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Quick amount buttons ──
          Row(
            children: _quickAmounts.map((v) {
              final selected = _donateAmount == v;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: v == _quickAmounts.last ? 0 : 8,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _donateAmount = v);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: selected
                            ? primaryOrange.withOpacity(0.1)
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? primaryOrange
                              : borderColor,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '${v ~/ 1000}k',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: selected ? primaryOrange : textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ── 4. Amount input + Donate button ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          controller: TextEditingController(
                            text: _fmtMoney(_donateAmount),
                          )..selection = TextSelection.collapsed(
                              offset: _fmtMoney(_donateAmount).length),
                          onChanged: (val) {
                            final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                            setState(() {
                              _donateAmount = int.tryParse(digits) ?? 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'VNĐ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: (!_isAgreed || _donateAmount < 10000 || _donateLoading)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        ),
                  color: (!_isAgreed || _donateAmount < 10000 || _donateLoading)
                      ? const Color(0xFFCBD5E1)
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: (!_isAgreed || _donateAmount < 10000 || _donateLoading)
                        ? null
                        : _handleDirectDonate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      child: _donateLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Quyên góp',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 5. Checkboxes ──
          _checkRow(
            value: _isAnonymous,
            onChanged: (v) => setState(() => _isAnonymous = v ?? false),
            label: 'Quyên góp ẩn danh',
          ),
          _checkRow(
            value: _isAgreed,
            onChanged: (v) => setState(() => _isAgreed = v ?? false),
            label: 'Tôi đồng ý với điều khoản sử dụng',
            richLabel: true,
          ),

          if (!_isAgreed && _donateAmount >= 10000)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Vui lòng đánh dấu đồng ý điều khoản để bật nút quyên góp.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primaryOrange.withOpacity(0.95),
                ),
              ),
            ),

          // ── Recent donors ──
          const SizedBox(height: 8),
          Divider(color: borderColor),
          const SizedBox(height: 8),
          _buildRecentDonorsSection(textPrimary, textSecondary, borderColor),
        ],
      ),
    );
  }

  // ── Helper: Progress summary (used in CLOSED/DISABLED/PAUSED cards) ──
  Widget _buildProgressSummary(
    int raised, int goal, int percentLabel, double barRatio, int donorCount,
    Color textPrimary, Color textSecondary, Color primaryOrange,
    Color borderColor, Color successGreen,
  ) {
    final bool hasGoal = goal > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Đã đạt được ${_fmtMoney(raised)} VNĐ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            Text(
              '$percentLabel%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: hasGoal && raised >= goal ? successGreen : primaryOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Color(0xFFE5E7EB)),
                ),
                FractionallySizedBox(
                  widthFactor: barRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: hasGoal && raised >= goal
                            ? [successGreen, const Color(0xFF15803D)]
                            : [const Color(0xFFF97316), primaryOrange],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasGoal ? 'Mục tiêu: ${_fmtMoney(goal)} VNĐ' : '',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            Text(
              'Lượt ủng hộ: $donorCount',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper: Recent donors section ──
  Widget _buildRecentDonorsSection(
    Color textPrimary, Color textSecondary, Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Người vừa ủng hộ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_donors.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              'Chưa có người ủng hộ nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ..._donors.map(_buildDonorRow),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1A0F172A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _checkRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    bool richLabel = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        // Tăng vùng bấm để dễ thao tác (đặc biệt trên mobile).
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: _brand,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: richLabel
                    ? RichText(
                        text: TextSpan(
                          style:
                              const TextStyle(fontSize: 13, color: _textDark),
                          children: [
                            const TextSpan(text: 'Tôi đồng ý với '),
                            TextSpan(
                              text: 'điều khoản sử dụng',
                              style: TextStyle(
                                color: _brand,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' của nền tảng'),
                          ],
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorRow(RecentDonorModel d) {
    final name = d.anonymous ? 'Người ủng hộ ẩn danh' : d.donorName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A0F172A)),
        ),
        child: Row(
          children: [
            SafeNetworkAvatar(
              imageUrl: d.donorAvatar,
              name: d.donorName.isNotEmpty ? d.donorName : 'D',
              radius: 18,
              backgroundColor: const Color(0xFFE2E8F0),
              fallbackIcon: const Icon(Icons.person, size: 18, color: _muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _timeAgo(d.createdAt),
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            Text(
              '+${_fmtMoney(d.amount)} đ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _brand,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Milestone Timeline ───
  Widget _buildMilestoneTimeline(int raisedAmount) {
    final completed = _plans.where((p) {
      final s = (p.status ?? '').toUpperCase();
      return ['DISBURSED', 'COMPLETED', 'CLOSED'].contains(s);
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A0F172A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Giai đoạn của chiến dịch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$completed/${_plans.length} đợt đã hoàn thành',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_plans.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x1A0F172A)),
              ),
              child: const Text(
                'Chưa có hồ sơ chi tiêu cho chiến dịch này.',
                style: TextStyle(
                  fontSize: 12,
                  color: _muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ..._plans.asMap().entries.map((entry) {
              return _MilestoneItem(
                plan: entry.value,
                index: entry.key,
                isLast: entry.key == _plans.length - 1,
                onOpenDetail: () => _openExpenditureDetail(entry.value),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _openExpenditureDetail(ExpenditurePlanModel plan) async {
    final payload = <String, dynamic>{
      'id': plan.id,
      'campaignId': _campaign.id,
      'plan': plan.title,
      'status': plan.status,
      'startDate': plan.startDate,
      'endDate': plan.endDate,
      'totalExpectedAmount': plan.amount,
      'categories': plan.categories
          .map((cat) => <String, dynamic>{
                'id': cat.id,
                'name': cat.name,
                'description': cat.description,
                'expectedAmount': cat.expectedAmount,
                'actualAmount': cat.actualAmount,
                'items': cat.items
                    .map((item) => <String, dynamic>{
                          'id': item.id,
                          'name': item.name,
                          'category': item.name,
                          'quantity': item.expectedQuantity,
                          'expectedQuantity': item.expectedQuantity,
                          'expectedPrice': item.expectedPrice,
                          'actualQuantity': item.actualQuantity,
                          'price': item.price,
                          'note': item.note,
                        })
                    .toList(),
              })
          .toList(),
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenditureDetailScreen(
          expenditure: payload,
          campaignType: _campaign.type ?? 'ITEMIZED',
        ),
      ),
    );
  }

  // ─── Posts section ───
  Widget _buildPostsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A0F172A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bài viết',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
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
                    color: _brand,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_loadingPosts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Chưa có bài viết nào',
                  style: TextStyle(
                    fontSize: 13,
                    color: _muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ..._posts.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedPostDetailScreen(postId: p.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0x14000000)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SafeNetworkAvatar(
                              imageUrl: p.authorAvatar,
                              name: p.authorName.isNotEmpty ? p.authorName : 'P',
                              radius: 16,
                              fallbackIcon: const Icon(Icons.person,
                                  size: 16, color: _muted),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.authorName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _timeAgo(p.createdAt),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (p.content.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            p.content.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.favorite_border,
                                size: 14, color: _muted),
                            const SizedBox(width: 3),
                            Text('${p.likeCount}',
                                style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                            const SizedBox(width: 12),
                            const Icon(Icons.mode_comment_outlined,
                                size: 14, color: _muted),
                            const SizedBox(width: 3),
                            Text('${p.commentCount}',
                                style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────── Milestone Item Widget ───────────────────

class _MilestoneItem extends StatefulWidget {
  const _MilestoneItem({
    required this.plan,
    required this.index,
    required this.onOpenDetail,
    this.isLast = false,
  });

  final ExpenditurePlanModel plan;
  final int index;
  final VoidCallback onOpenDetail;
  final bool isLast;

  @override
  State<_MilestoneItem> createState() => _MilestoneItemState();
}

class _MilestoneItemState extends State<_MilestoneItem> {
  bool _expanded = false;

  String get _state {
    final s = (widget.plan.status ?? '').toUpperCase();
    if (['DISBURSED', 'COMPLETED', 'CLOSED'].contains(s)) return 'completed';
    if (['APPROVED', 'WITHDRAWAL_REQUESTED', 'PENDING_REVIEW', 'PENDING',
         'ALLOWED_EDIT'].contains(s)) return 'active';
    return 'upcoming';
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.plan.status ?? '').toUpperCase();
    final isCompleted = _state == 'completed';
    final isApproved = status == 'APPROVED';
    final isPending = ['PENDING', 'PENDING_REVIEW', 'ALLOWED_EDIT'].contains(status);
    final isRejected = status == 'REJECTED';
    final isActive = _state == 'active';
    final accent = isRejected
        ? _red
        : (isCompleted || isApproved)
            ? _green
            : isPending
                ? const Color(0xFFF59E0B)
                : isActive
                    ? _brand
                    : _muted;
    final bg = isRejected
        ? const Color(0xFFFEF2F2)
        : (isCompleted || isApproved)
            ? const Color(0xFFECFDF5)
            : isPending
                ? const Color(0xFFFFFBEB)
                : isActive
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFF8FAFC);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline dot + line
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 8, color: Colors.white)
                        : null,
                  ),
                  if (!widget.isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFF1F5F9),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Content
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? _brand.withOpacity(0.1)
                          : const Color(0x0D0F172A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plan.title.toLowerCase().contains('đợt ${widget.index + 1}')
                                ? widget.plan.title
                                : 'Đợt ${widget.index + 1}: ${widget.plan.title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 10, color: _muted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.plan.date ?? 'Chưa xác định',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: _muted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_fmtMoney(widget.plan.amount)}đ',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: _dark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _expanded ? 'Thu gọn' : 'Xem chi tiết hạng mục',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 14,
                                color: accent,
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: widget.onOpenDetail,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: _brand.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long, size: 13, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Xem chi tiết hồ sơ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios, size: 9, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 10),
                        Divider(
                          color: isActive
                              ? _brand.withOpacity(0.2)
                              : const Color(0x1A0F172A),
                        ),
                        if (widget.plan.categories.isEmpty)
                          const Text(
                            'Chưa có chi tiết cho đợt này.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          ...widget.plan.categories.map((cat) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0x080F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cat.name.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      Text(
                                        '${_fmtMoney(cat.expectedAmount)}đ',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _dark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...cat.items.map((item) {
                                  final total = item.expectedQuantity *
                                      item.expectedPrice;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6, left: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      Color(0xFF334155),
                                                ),
                                              ),
                                              Text(
                                                '${item.expectedQuantity} x ${_fmtMoney(item.expectedPrice)}đ',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: _muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${_fmtMoney(total)}đ',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _dark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Skeleton loading ───────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(width: 120, height: 28),
          const SizedBox(height: 12),
          _box(width: double.infinity, height: 24),
          const SizedBox(height: 6),
          _box(width: 200, height: 24),
          const SizedBox(height: 16),
          Row(
            children: [
              _circle(44),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(width: 80, height: 12),
                  const SizedBox(height: 6),
                  _box(width: 120, height: 14),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _box(width: double.infinity, height: 180),
          const SizedBox(height: 16),
          _box(width: double.infinity, height: 120),
          const SizedBox(height: 16),
          _box(width: double.infinity, height: 100),
        ],
      ),
    );
  }

  Widget _box({required double height, double? width}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────── Error state ───────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: _muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _textDark),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
