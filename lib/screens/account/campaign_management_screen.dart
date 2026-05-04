import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/campaign_service.dart';
import '../../core/api/expenditure_service.dart';
import '../expenditure_detail_screen.dart';
import '../campaign_posts_screen.dart';

/// Màn hình quản lý chiến dịch — Tabs: Chi tiêu | Bài viết | Thống kê.
class CampaignManagementScreen extends StatefulWidget {
  final int campaignId;
  final String campaignTitle;
  final String campaignType;

  const CampaignManagementScreen({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
    required this.campaignType,
  });

  @override
  State<CampaignManagementScreen> createState() =>
      _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CampaignService _campaignService = CampaignService();
  final ExpenditureService _expenditureService = ExpenditureService();

  bool _isLoading = true;
  Map<String, dynamic>? _campaign;
  List<Map<String, dynamic>> _expenditures = [];

  // Stats
  double _balance = 0;
  double _totalExpected = 0;
  int _expenditureCount = 0;

  static const Color _primary = Color(0xFFF84D43);
  static const Color _emerald = Color(0xFF1A685B);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _textGray = Color(0xFF4B5563);
  static const Color _bgGray = Color(0xFFF9FAFB);
  static const Color _border = Color(0xFFE5E7EB);

  final NumberFormat _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final campaignRes =
          await _campaignService.getCampaign(widget.campaignId);
      if (campaignRes.statusCode == 200 && campaignRes.data is Map) {
        _campaign = campaignRes.data as Map<String, dynamic>;
        _balance = (_campaign!['balance'] ?? 0).toDouble();
      }

      final expRes = await _expenditureService
          .getExpendituresByCampaign(widget.campaignId);
      if (expRes.statusCode == 200 && expRes.data is List) {
        _expenditures = (expRes.data as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        _expenditureCount = _expenditures.length;
        _totalExpected = _expenditures.fold(
            0.0, (sum, e) => sum + (e['totalExpectedAmount'] ?? 0).toDouble());
      }
    } catch (e) {
      debugPrint('CampaignManagement load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _statusLabel(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING_REVIEW':
        return 'Chờ duyệt';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'WITHDRAWAL_REQUESTED':
        return 'Chờ giải ngân';
      case 'DISBURSED':
        return 'Đã giải ngân';
      case 'REJECTED':
        return 'Từ chối';
      default:
        return raw ?? '—';
    }
  }

  Color _statusColor(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING_REVIEW':
        return Colors.orange;
      case 'APPROVED':
        return _emerald;
      case 'WITHDRAWAL_REQUESTED':
        return Colors.blue;
      case 'DISBURSED':
        return Colors.purple;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: Text(widget.campaignTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primary,
          unselectedLabelColor: _textGray,
          indicatorColor: _primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Chi tiêu'),
            Tab(text: 'Bài viết'),
            Tab(text: 'Thống kê'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildExpenditureTab(),
                _buildPostsTab(),
                _buildStatsTab(),
              ],
            ),
    );
  }

  // ── Tab 1: Chi tiêu ──
  Widget _buildExpenditureTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _expenditures.isEmpty
          ? _buildEmptyExpenditure()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _expenditures.length,
              itemBuilder: (_, i) => _buildExpenditureCard(_expenditures[i], i + 1),
            ),
    );
  }

  Widget _buildEmptyExpenditure() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Chưa có đợt chi tiêu nào',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textDark)),
            const SizedBox(height: 8),
            const Text('Các đợt chi tiêu sẽ hiển thị ở đây.',
                style: TextStyle(color: _textGray, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenditureCard(Map<String, dynamic> exp, int index) {
    final String status = exp['status'] ?? '';
    final double totalExpected = (exp['totalExpectedAmount'] ?? 0).toDouble();
    final double totalActual = (exp['totalActualAmount'] ?? 0).toDouble();
    final String plan = exp['plan'] ?? '';
    final color = _statusColor(status);
    final String evidenceStatus = (exp['evidenceStatus'] ?? '').toString();
    final String createdAt = exp['createdAt'] != null
        ? _dateFmt.format(DateTime.parse(
            exp['createdAt'].toString().replaceFirst(' ', 'T')))
        : '—';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenditureDetailScreen(
              expenditure: exp,
              campaignType: widget.campaignType,
            ),
          ),
        );
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đợt $index',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _textDark)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (plan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGray, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            // Amounts
            Row(
              children: [
                _miniStat('Dự kiến', _fmt.format(totalExpected)),
                const SizedBox(width: 16),
                if (totalActual > 0)
                  _miniStat('Thực tế', _fmt.format(totalActual)),
              ],
            ),
            const SizedBox(height: 8),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Tạo: $createdAt',
                        style:
                            const TextStyle(fontSize: 11, color: _textGray)),
                    if (evidenceStatus.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _evidenceBadge(evidenceStatus),
                    ],
                  ],
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: _textGray),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: _textGray)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: _textDark)),
      ],
    );
  }

  Widget _evidenceBadge(String status) {
    final upper = status.toUpperCase();
    final bool submitted =
        upper == 'SUBMITTED' || upper == 'APPROVED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: submitted
            ? _emerald.withOpacity(0.1)
            : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        submitted ? 'MC: Đã nộp' : 'MC: Chờ',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: submitted ? _emerald : Colors.amber.shade800,
        ),
      ),
    );
  }

  // ── Tab 2: Bài viết ──
  Widget _buildPostsTab() {
    return CampaignPostsScreen(
      campaignId: widget.campaignId,
      campaignTitle: widget.campaignTitle,
    );
  }

  // ── Tab 3: Thống kê ──
  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Số dư chiến dịch',
              value: _fmt.format(_balance),
              color: _emerald,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.receipt_long_outlined,
              title: 'Tổng đợt chi tiêu',
              value: '$_expenditureCount đợt',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.trending_up,
              title: 'Tổng dự kiến chi tiêu',
              value: _fmt.format(_totalExpected),
              color: _primary,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.category_outlined,
              title: 'Loại chiến dịch',
              value: widget.campaignType == 'ITEMIZED'
                  ? 'Quỹ Hạng mục'
                  : 'Quỹ Ủy quyền',
              color: Colors.purple,
            ),
            if (_campaign != null && _campaign!['status'] != null) ...[
              const SizedBox(height: 12),
              _buildStatCard(
                icon: Icons.flag_outlined,
                title: 'Trạng thái',
                value: (_campaign!['status'] ?? '').toString(),
                color: _statusColor(_campaign!['status']),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 12, color: _textGray)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
