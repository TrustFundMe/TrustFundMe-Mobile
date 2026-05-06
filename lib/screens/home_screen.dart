import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/api/campaign_service.dart';
import '../core/api/donation_service.dart';
import '../core/api/user_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/campaign_category_model.dart';
import '../core/models/payment_models.dart';
import '../core/providers/auth_provider.dart';
import 'campaign_detail_screen.dart';

/// Home Screen với search, categories filter, campaign cards, pagination, FAB.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ─── Constants ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFF84D43);
  static const Color _bgGray = Color(0xFFF9FAFB);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _textGray = Color(0xFF6B7280);

  // ─── Services ──────────────────────────────────────────────────────────────
  final CampaignService _campaignSvc = CampaignService();
  final DonationService _donationSvc = DonationService();
  final UserService _userSvc = UserService();

  // ─── State ─────────────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<CampaignCategoryModel> _categories = <CampaignCategoryModel>[];
  int? _selectedCategoryId; // null = "Tất cả"
  String _searchQuery = '';

  List<CampaignModel> _campaigns = <CampaignModel>[];
  final Map<int, CampaignProgressModel> _progressMap =
      <int, CampaignProgressModel>{};
  /// Maps fundOwnerId → fullName for displaying on campaign cards.
  final Map<int, String> _ownerNameMap = <int, String>{};

  bool _loading = true;
  bool _loadingMore = false;
  bool _categoriesLoading = true;
  int _page = 0;
  bool _hasMore = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadCategories();
    _loadCampaigns(refresh: true);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadCategories() async {
    try {
      final res = await _campaignSvc.getCategories();
      final dynamic data = res.data;
      List<dynamic> list = <dynamic>[];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        list = (data['content'] ?? data['data'] ?? <dynamic>[]) as List<dynamic>;
      }
      if (!mounted) return;
      setState(() {
        _categories = list
            .whereType<Map<String, dynamic>>()
            .map(CampaignCategoryModel.fromJson)
            .toList();
        _categoriesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _loadCampaigns({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      _errorMsg = null;
    }
    if (!_hasMore && !refresh) return;

    if (mounted) {
      setState(() {
        if (refresh) {
          _loading = true;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final res = await _campaignSvc.getCampaignsPaginated(
        page: refresh ? 0 : _page,
        size: 10,
        categoryId: _selectedCategoryId,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: 'APPROVED',
      );

      final dynamic raw = res.data;
      List<dynamic> content = <dynamic>[];
      int totalPages = 1;

      if (raw is List) {
        content = raw;
      } else if (raw is Map<String, dynamic>) {
        // Try multiple response structures
        final dynamic d = raw['data'];
        if (d is List) {
          content = d;
        } else if (d is Map<String, dynamic>) {
          content = (d['content'] as List<dynamic>?) ?? <dynamic>[];
          totalPages = (d['totalPages'] as num?)?.toInt() ?? 1;
        } else if (raw['content'] is List) {
          content = raw['content'] as List<dynamic>;
          totalPages = (raw['totalPages'] as num?)?.toInt() ?? 1;
        }
      }

      final List<CampaignModel> chunk = content
          .whereType<Map<String, dynamic>>()
          .map(CampaignModel.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _campaigns = chunk;
          _progressMap.clear();
          _page = 1;
        } else {
          _campaigns.addAll(chunk);
          _page += 1;
        }
        _hasMore = (refresh ? 1 : _page) < totalPages;
        _loading = false;
        _loadingMore = false;
      });

      // Load progress and owner names in background
      _loadProgressInBackground(chunk);
      _loadOwnerNamesInBackground(chunk);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMsg = 'Không tải được chiến dịch. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _loadProgressInBackground(List<CampaignModel> campaigns) async {
    for (final CampaignModel c in campaigns) {
      if (_progressMap.containsKey(c.id)) continue;
      try {
        final res = await _donationSvc.getCampaignProgress(c.id);
        if (res.data is Map<String, dynamic>) {
          final progress =
              CampaignProgressModel.fromJson(res.data as Map<String, dynamic>);
          if (!mounted) return;
          setState(() => _progressMap[c.id] = progress);
        }
      } catch (_) {
        // Silent fail for background data
      }
    }
  }

  /// Batch-fetch fund owner names for campaign cards.
  Future<void> _loadOwnerNamesInBackground(List<CampaignModel> campaigns) async {
    // Collect unique owner IDs that we haven't fetched yet
    final Set<int> toFetch = <int>{};
    for (final CampaignModel c in campaigns) {
      final int? ownerId = c.fundOwnerId;
      if (ownerId != null && !_ownerNameMap.containsKey(ownerId)) {
        toFetch.add(ownerId);
      }
    }
    if (toFetch.isEmpty) return;

    for (final int ownerId in toFetch) {
      try {
        final res = await _userSvc.getUserById(ownerId);
        final dynamic data = res.data;
        if (data is Map<String, dynamic>) {
          // Backend returns user directly (e.g. {fullName, avatarUrl, ...})
          // or wrapped in {data: {...}}
          final String? name = data.containsKey('fullName')
              ? data['fullName'] as String?
              : (data['data'] is Map<String, dynamic>
                  ? (data['data'] as Map<String, dynamic>)['fullName'] as String?
                  : null);
          if (name != null && name.isNotEmpty && mounted) {
            setState(() => _ownerNameMap[ownerId] = name);
          }
        }
      } catch (_) {
        // Silent fail — card will show fallback text
      }
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      _loadCampaigns();
    }
  }

  void _onCategorySelected(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() => _selectedCategoryId = categoryId);
    _loadCampaigns(refresh: true);
  }

  void _onSearch(String query) {
    _searchQuery = query.trim();
    _loadCampaigns(refresh: true);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _bgGray,
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () async {
          await _loadCategories();
          await _loadCampaigns(refresh: true);
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            // ─── App Bar ──────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: Image.asset(
                'assets/images/black-logo.png',
                height: 32,
                fit: BoxFit.contain,
              ),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.notifications_none,
                      color: _textDark),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/notifications'),
                ),
              ],
            ),

            // ─── Search Bar ───────────────────────────────────────
            SliverToBoxAdapter(child: _buildSearchBar()),

            // ─── Categories ───────────────────────────────────────
            SliverToBoxAdapter(child: _buildCategories()),

            // ─── Campaign List ────────────────────────────────────
            _buildCampaignList(),

            // ─── Loading More ─────────────────────────────────────
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(auth),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onSubmitted: _onSearch,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm chiến dịch...',
          hintStyle: const TextStyle(color: _textGray, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search, color: _textGray, size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (v) => setState(() {}), // update clear icon
      ),
    );
  }

  // ─── Categories ───────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Danh mục',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textGray,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: _categoriesLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: <Widget>[
                      _CategoryChip(
                        label: 'Tất cả',
                        selected: _selectedCategoryId == null,
                        onTap: () => _onCategorySelected(null),
                      ),
                      ..._categories.map(
                        (cat) => _CategoryChip(
                          label: cat.name,
                          selected: _selectedCategoryId == cat.id,
                          onTap: () => _onCategorySelected(cat.id),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Campaign List ────────────────────────────────────────────────────────
  Widget _buildCampaignList() {
    if (_loading && _campaigns.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMsg != null && _campaigns.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(),
      );
    }

    if (_campaigns.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final campaign = _campaigns[index];
            final progress = _progressMap[campaign.id];
            final String? ownerName = campaign.fundOwnerId != null
                ? _ownerNameMap[campaign.fundOwnerId!]
                : null;
            return _CampaignCard(
              campaign: campaign,
              progress: progress,
              ownerName: ownerName,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CampaignDetailScreen(
                      campaign: campaign,
                      initialProgress: progress,
                    ),
                  ),
                );
              },
            );
          },
          childCount: _campaigns.length,
        ),
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Không tìm thấy chiến dịch nào',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Thử tìm kiếm với từ khóa khác'
                  : 'Chưa có chiến dịch nào trong danh mục này',
              style: const TextStyle(fontSize: 14, color: _textGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _errorMsg ?? 'Đã có lỗi xảy ra',
              style: const TextStyle(fontSize: 15, color: _textGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadCampaigns(refresh: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
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

  // ─── FAB ──────────────────────────────────────────────────────────────────
  Widget? _buildFAB(AuthProvider auth) {
    if (!auth.isLoggedIn) return null;
    final user = auth.user;
    if (user == null) return null;

    return FloatingActionButton.extended(
      onPressed: () {
        if (user.kycVerified) {
          Navigator.pushNamed(context, '/new-campaign');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn cần hoàn tất KYC để tạo chiến dịch. Chuyển đến màn xác minh.',
            ),
          ),
        );
        Navigator.pushNamed(context, '/kyc');
      },
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text(
        'Tạo chiến dịch',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Category Chip ────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF18181B)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Campaign Card ────────────────────────────────────────────────────────────
class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    this.progress,
    this.ownerName,
    required this.onTap,
  });

  final CampaignModel campaign;
  final CampaignProgressModel? progress;
  final String? ownerName;
  final VoidCallback onTap;

  static String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  @override
  Widget build(BuildContext context) {
    final double ratio = progress != null
        ? (progress!.progressPercentage / 100).clamp(0.0, 1.0)
        : 0.0;
    final int raised = progress?.raisedAmount ?? 0;
    final int goal = progress?.goalAmount ?? 0;
    final int donors = progress?.donorCount ?? 0;
    final int pct = progress?.progressPercentage ?? 0;

    final String imageUrl = campaign.coverImageUrl ??
        'https://placehold.co/800x400.png?text=${Uri.encodeComponent(campaign.title)}&bg=DBEAFE&color=0F172A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ─── Cover Image ──────────────────────────────────────
            Stack(
              children: <Widget>[
                Image.network(
                  imageUrl,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    color: const Color(0xFFE5E7EB),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFF9CA3AF),
                      size: 36,
                    ),
                  ),
                ),
                // Category badge
                if (campaign.categoryName != null &&
                    campaign.categoryName!.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        campaign.categoryName!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ─── Content ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Title
                  Text(
                    campaign.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Creator + KYC badge
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.person_outline,
                        size: 15,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          ownerName ??
                              'Người tạo #${campaign.fundOwnerId ?? ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (campaign.kycVerified) ...<Widget>[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            size: 15, color: Color(0xFF2563EB)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: _HomeScreenState._primary,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          goal > 0
                              ? '${_formatCurrency(raised)} / ${_formatCurrency(goal)}'
                              : raised > 0
                                  ? _formatCurrency(raised)
                                  : 'Chưa có đóng góp',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$pct% đã đạt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _HomeScreenState._primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Donor count
                  if (donors > 0)
                    Text(
                      '$donors người ủng hộ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
