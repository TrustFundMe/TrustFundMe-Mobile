import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/payment_models.dart';
import '../core/providers/auth_provider.dart';
import 'campaign_detail_screen.dart';
import 'create_campaign_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _errorMessage;
  List<CampaignModel> _campaigns = <CampaignModel>[];
  final Map<int, CampaignProgressModel> _progressByCampaign =
      <int, CampaignProgressModel>{};
  _CampaignFilter _activeFilter = _CampaignFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  Future<void> _fetchCampaigns() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _api.getCampaigns();
      final dynamic raw = response.data;
      final List<dynamic> data;
      if (raw is List<dynamic>) {
        data = raw;
      } else if (raw is Map<String, dynamic> && raw['data'] is List<dynamic>) {
        data = raw['data'] as List<dynamic>;
      } else {
        data = <dynamic>[];
      }

      final List<CampaignModel> parsed = data
          .map(
            (dynamic e) =>
                CampaignModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      if (!mounted) return;

      setState(() {
        _campaigns = parsed;
        _loading = false;
      });
      _fetchProgressInBackground(parsed);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _campaigns = <CampaignModel>[];
        _loading = false;
        _errorMessage = 'Không tải được danh sách chiến dịch. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _fetchProgressInBackground(List<CampaignModel> campaigns) async {
    for (final CampaignModel c in campaigns) {
      try {
        final progressRes = await _api.getCampaignProgress(c.id);
        final CampaignProgressModel progress = CampaignProgressModel.fromJson(
          progressRes.data as Map<String, dynamic>,
        );
        if (!mounted) return;
        setState(() {
          _progressByCampaign[c.id] = progress;
        });
      } catch (_) {
        // bỏ qua lỗi progress để không chặn danh sách
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color webPrimary = Color(0xFFF84D43);
    const Color webBgGray = Color(0xFFF9FAFB);
    const Color webTextDark = Color(0xFF1F2937);
    final auth = context.watch<AuthProvider>();
    final int? myUserId = auth.user?.id;
    final bool isFundOwner = auth.user?.role.toUpperCase() == 'FUND_OWNER';
    final String keyword = _searchController.text.trim().toLowerCase();

    List<CampaignModel> filtered = _campaigns.where((CampaignModel c) {
      final bool matchesText = keyword.isEmpty ||
          c.title.toLowerCase().contains(keyword) ||
          (c.categoryName ?? '').toLowerCase().contains(keyword);
      if (!matchesText) return false;
      switch (_activeFilter) {
        case _CampaignFilter.all:
          return true;
        case _CampaignFilter.active:
          final double ratio =
              (_progressByCampaign[c.id]?.progressPercentage ?? 0) / 100;
          return ratio < 1;
        case _CampaignFilter.mine:
          return c.fundOwnerId != null && c.fundOwnerId == myUserId;
      }
    }).toList();

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          'Chiến dịch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: webTextDark,
        actions: [
          if (isFundOwner)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateCampaignScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCampaigns,
              child: _errorMessage != null
                  ? ListView(
                      children: <Widget>[
                        const SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: OutlinedButton(
                            onPressed: _fetchCampaigns,
                            child: const Text('Thử lại'),
                          ),
                        ),
                      ],
                    )
                  : _campaigns.isEmpty
                  ? ListView(
                      children: <Widget>[
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Hiện chưa có chiến dịch nào.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Tìm chiến dịch theo tên hoặc danh mục...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('Tất cả', _CampaignFilter.all),
                            _buildFilterChip('Đang diễn ra', _CampaignFilter.active),
                            if (isFundOwner)
                              _buildFilterChip('Của tôi', _CampaignFilter.mine),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                              _activeFilter == _CampaignFilter.mine
                                  ? 'Bạn chưa có chiến dịch nào. Bấm dấu + để tạo mới.'
                                  : 'Không tìm thấy chiến dịch phù hợp.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                          )
                        else
                          ...filtered.map((CampaignModel campaign) {
                            final CampaignProgressModel? progress =
                                _progressByCampaign[campaign.id];
                            final double ratio =
                                (progress?.progressPercentage ?? 0) / 100;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push<bool>(
                                    MaterialPageRoute<bool>(
                                      builder: (_) => CampaignDetailScreen(
                                        campaign: campaign,
                                        initialProgress: progress,
                                      ),
                                    ),
                                  ).then((bool? shouldRefresh) {
                                    if (shouldRefresh == true) {
                                      _fetchCampaigns();
                                    }
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: SizedBox(
                                        height: 176,
                                        width: double.infinity,
                                        child: campaign.coverImageUrl != null &&
                                                campaign.coverImageUrl!.isNotEmpty
                                            ? Image.network(
                                                campaign.coverImageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    _campaignPlaceholder(),
                                              )
                                            : _campaignPlaceholder(),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            campaign.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if ((campaign.categoryName ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                campaign.categoryName!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: ratio.clamp(0, 1),
                                              minHeight: 8,
                                              backgroundColor: const Color(0xFFE5E7EB),
                                              color: webPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Đã đạt: ${(progress?.progressPercentage ?? 0).toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF4B5563),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).push<bool>(
                                                    MaterialPageRoute<bool>(
                                                      builder: (_) => CampaignDetailScreen(
                                                        campaign: campaign,
                                                        initialProgress: progress,
                                                      ),
                                                    ),
                                                  ).then((bool? shouldRefresh) {
                                                    if (shouldRefresh == true) {
                                                      _fetchCampaigns();
                                                    }
                                                  });
                                                },
                                                child: const Text(
                                                  'Quyên góp',
                                                  style: TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Đã quyên góp: ${_fmtInt(progress?.raisedAmount ?? 0)} đ',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                              Text(
                                                'Mục tiêu: ${_fmtInt(progress?.goalAmount ?? 0)} đ',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
            ),
    );
  }

  Widget _buildFilterChip(String label, _CampaignFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _activeFilter == value,
      onSelected: (_) {
        setState(() {
          _activeFilter = value;
        });
      },
      selectedColor: const Color(0xFFFEE2E2),
      labelStyle: TextStyle(
        color: _activeFilter == value ? const Color(0xFFF84D43) : const Color(0xFF4B5563),
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: _activeFilter == value ? const Color(0xFFF84D43) : const Color(0xFFE5E7EB),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _campaignPlaceholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 36,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  String _fmtInt(int value) {
    return NumberFormat.decimalPattern('vi_VN').format(value);
  }
}

enum _CampaignFilter { all, active, mine }
