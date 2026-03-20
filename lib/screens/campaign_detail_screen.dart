import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/payment_models.dart';
import 'donation_screen.dart';

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

  CampaignProgressModel? _progress;
  List<RecentDonorModel> _donors = <RecentDonorModel>[];
  bool _loading = true;
  String? _errorMessage;
  bool _refreshCampaignsList = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.getCampaignProgress(widget.campaign.id),
        _api.getRecentDonors(widget.campaign.id, limit: 10),
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

  Future<void> _openDonate() async {
    final bool? shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DonationScreen(campaign: widget.campaign),
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
                        child: widget.campaign.coverImageUrl != null &&
                                widget.campaign.coverImageUrl!.isNotEmpty
                            ? Image.network(
                                widget.campaign.coverImageUrl!,
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
                            widget.campaign.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: webTextDark,
                            ),
                          ),
                          if ((widget.campaign.categoryName ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                widget.campaign.categoryName!,
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
                                                backgroundColor: Colors.black.withValues(alpha: 0.1),
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
                    if (widget.campaign.description?.trim().isNotEmpty == true)
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
                                widget.campaign.description!.trim(),
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
                                                color: Colors.black.withValues(alpha: 0.5),
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
