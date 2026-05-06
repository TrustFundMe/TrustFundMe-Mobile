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
import '../widgets/flags/flag_reason_sheet.dart';
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
    if (mounted) setState(() { _loading = true; _errorMessage = null; });

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

      if (mounted) setState(() { _loading = false; });

      // Phase 2: Non-blocking — owner details, follow info
      await _loadSecondaryData();
    } catch (e) {
      if (!mounted) return;
      // Luôn tắt loading. Chỉ set errorMessage khi KHÔNG có data nào để hiển thị.
      // Nếu widget.campaign đã có id hợp lệ (đến từ danh sách), render với data sẵn có
      // và chỉ thông báo toast thay vì chặn toàn bộ màn hình.
      debugPrint('[CampaignDetail] _load lỗi id=${_campaign.id}: $e');
      if (_campaign.id > 0) {
        setState(() => _loading = false);
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
          _errorMessage = 'Không tải được chi tiết. Kéo xuống để thử lại.';
        });
      }
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      final ownerId = _campaign.fundOwnerId;
      if (ownerId == null) return;

      final results = await Future.wait<dynamic>([
        _userSvc.getUserById(ownerId).then<dynamic>((r) => r).catchError((_) => null),
        _api.isFollowingCampaign(_campaign.id).then<dynamic>((r) => r).catchError((_) => null),
        _api.getMyFlags(page: 0, size: 100).then<dynamic>((r) => r).catchError((_) => null),
        _trustScoreSvc.getUserScore(ownerId).then<dynamic>((r) => r).catchError((_) => null),
      ]);

      if (!mounted) return;

      // Owner info — backend returns user object directly (e.g. {id, fullName, avatarUrl, ...}).
      // Some responses may wrap it in {data: {...}}, so we check both formats.
      final dynamic s0 = results[0];
      final dynamic uRaw = s0 is Response ? s0.data : null;
      if (uRaw is Map<String, dynamic>) {
        // Try direct fields first (backend returns user at top level)
        if (uRaw.containsKey('fullName')) {
          _creatorName = (uRaw['fullName'] ?? '') as String;
          _creatorAvatar = (uRaw['avatarUrl'] ?? '') as String;
        } else {
          // Fallback: response might be wrapped in {data: {...}}
          final data = uRaw['data'];
          if (data is Map<String, dynamic>) {
            _creatorName = (data['fullName'] ?? '') as String;
            _creatorAvatar = (data['avatarUrl'] ?? '') as String;
          }
        }
      }

      // Follow status
      final dynamic s1 = results[1];
      final dynamic fRaw = s1 is Response ? s1.data : null;
      if (fRaw is bool) {
        _followed = fRaw;
      } else if (fRaw is Map && fRaw['following'] != null) {
        _followed = fRaw['following'] as bool;
      }

      // Flag check
      final dynamic s2 = results[2];
      final dynamic flagRaw = s2 is Response ? s2.data : null;
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

      // Trust score
      final dynamic s3 = results[3];
      final dynamic tsRaw = s3 is Response ? s3.data : null;
      if (tsRaw is Map<String, dynamic>) {
        final totalScore = tsRaw['totalScore'];
        if (totalScore is num && totalScore > 0) {
          _creatorTrustScore = totalScore.toInt();
        }
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
          _followerCount += _followed ? 1 : -1;
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

                        // Milestone Timeline
                        if (_plans.isNotEmpty) _buildMilestoneTimeline(raised),

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
    final name = _creatorName.isNotEmpty
        ? _creatorName
        : 'Người tạo #${_campaign.fundOwnerId ?? ''}';
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE2E8F0),
          backgroundImage: _creatorAvatar.isNotEmpty
              ? NetworkImage(_creatorAvatar)
              : null,
          child: _creatorAvatar.isEmpty
              ? const Icon(Icons.person, color: _muted, size: 22)
              : null,
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
              ? 'Đang theo dõi${_followerCount > 0 ? ' ($_followerCount)' : ''}'
              : 'Theo dõi${_followerCount > 0 ? ' ($_followerCount)' : ''}',
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

  // ─── Donate Card (inline) ───
  Widget _buildDonateCard(int raised, int goal, int pct, int donorCount) {
    final bool hasGoal = goal > 0;
    final int shortage = goal - raised;
    // Vòng tiến độ: đầy khi đạt/vượt mục tiêu; màu xanh khi đã đủ để tránh cảm giác “vẫn chưa xong”.
    final double ringRatio = hasGoal
        ? (raised / goal).clamp(0.0, 1.0)
        : (pct / 100).clamp(0.0, 1.0);
    final int percentLabel = hasGoal
        ? ((raised * 100) ~/ goal).clamp(0, 999)
        : pct.clamp(0, 999);
    final Color ringColor =
        hasGoal && raised >= goal ? _green : _brand;

    String progressSubline() {
      if (!hasGoal) return 'Đang cập nhật số liệu mục tiêu';
      if (raised >= goal) return 'Đã đạt mục tiêu';
      return 'Còn ${_fmtMoney(shortage)} đ';
    }

    String remainingCaption() {
      if (!hasGoal) {
        return 'Mục tiêu chưa được cấu hình — bạn vẫn có thể quyên góp nếu muốn.';
      }
      if (raised < goal) {
        return 'Còn thiếu: ${_fmtMoney(shortage)} VNĐ';
      }
      if (raised == goal) {
        return 'Đã đủ mục tiêu — bạn vẫn có thể tiếp tục quyên góp để đồng hành.';
      }
      return 'Đã vượt mục tiêu (+${_fmtMoney(raised - goal)} đ). Cảm ơn cộng đồng đã ủng hộ thêm so với dự kiến.';
    }

    String ratioLine() {
      if (!hasGoal) return '${_fmtMoney(raised)} VNĐ';
      return '${_fmtMoney(raised)} / ${_fmtMoney(goal)} VNĐ';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1E0F172A)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular progress + label
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1A0F172A)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: ringRatio,
                        strokeWidth: 7,
                        backgroundColor: Colors.black.withOpacity(0.1),
                        color: ringColor,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '$percentLabel%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiến trình gây quỹ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        progressSubline(),
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Goal + stats
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x1A0F172A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MỤC TIÊU CHIẾN DỊCH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtMoney(goal)} VNĐ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ratioLine(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasGoal && raised >= goal ? _green : _brand,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        'Đã quyên góp',
                        '${_fmtMoney(raised)} VNĐ',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statBox(
                          'Lượt ủng hộ', donorCount.toString()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Điều khoản trước CTA — tránh nút xám mà người dùng không hiểu vì sao.
          Divider(color: const Color(0x1A0F172A)),
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
          const SizedBox(height: 10),

          // Quick amounts
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickAmounts.map((v) {
              final selected = _donateAmount == v;
              return InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _donateAmount = v);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: selected
                        ? _brand.withOpacity(0.1)
                        : Colors.white,
                    border: Border.all(
                      color: selected
                          ? _brand.withOpacity(0.4)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '${v ~/ 1000}k',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected
                          ? const Color(0xFFA3471A)
                          : _textDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Amount input + Donate button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _dark,
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
                            final digits =
                                val.replaceAll(RegExp(r'[^0-9]'), '');
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
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    (!_isAgreed || _donateAmount < 10000 || _donateLoading)
                        ? null
                        : _handleDirectDonate,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
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
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            remainingCaption(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasGoal && raised >= goal ? _green : _muted,
              height: 1.35,
            ),
          ),
          if (!_isAgreed && _donateAmount >= 10000)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Vui lòng đánh dấu đồng ý điều khoản phía trên để bật nút quyên góp.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _brand.withOpacity(0.95),
                ),
              ),
            ),

          // Recent donors
          const SizedBox(height: 8),
          Divider(color: const Color(0x1A0F172A)),
          const SizedBox(height: 8),
          const Text(
            'Người vừa ủng hộ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 10),
          if (_donors.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0x1A0F172A),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Text(
                'Chưa có người ủng hộ nào',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ..._donors.map(_buildDonorRow),
        ],
      ),
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
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: d.donorAvatar != null &&
                      d.donorAvatar!.isNotEmpty
                  ? NetworkImage(d.donorAvatar!)
                  : null,
              child: d.donorAvatar == null || d.donorAvatar!.isEmpty
                  ? const Icon(Icons.person, size: 18, color: _muted)
                  : null,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Giai đoạn của chiến dịch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              Text(
                '$completed/${_plans.length} đợt đã hoàn thành',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._plans.asMap().entries.map((entry) {
            return _MilestoneItem(
              plan: entry.value,
              index: entry.key,
              isLast: entry.key == _plans.length - 1,
            );
          }),
        ],
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
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: (p.authorAvatar ?? '')
                                      .isNotEmpty
                                  ? NetworkImage(p.authorAvatar ?? '')
                                  : null,
                              child: (p.authorAvatar ?? '').isEmpty
                                  ? const Icon(Icons.person,
                                      size: 16, color: _muted)
                                  : null,
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
    this.isLast = false,
  });

  final ExpenditurePlanModel plan;
  final int index;
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
    final isCompleted = _state == 'completed';
    final isActive = _state == 'active';
    final isRejected = (widget.plan.status ?? '').toUpperCase() == 'REJECTED';
    final accent = isRejected ? _red : isCompleted ? _green : isActive ? _brand : _muted;
    final bg = isRejected
        ? const Color(0xFFFEF2F2)
        : isCompleted
            ? const Color(0xFFECFDF5)
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.plan.title.toLowerCase().contains('đợt ${widget.index + 1}')
                                      ? widget.plan.title
                                      : 'Đợt ${widget.index + 1}: ${widget.plan.title}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isActive ? _brand : _dark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 10, color: _muted),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.plan.date ?? 'Chưa xác định',
                                      style: const TextStyle(
                                          fontSize: 10, color: _muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_fmtMoney(widget.plan.amount)}đ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _dark,
                                ),
                              ),
                              Text(
                                _statusLabel(widget.plan.status ?? ''),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _expanded ? 'Thu gọn' : 'Xem chi tiết hạng mục',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? _brand : _muted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 14,
                            color: isActive ? _brand : _muted,
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
