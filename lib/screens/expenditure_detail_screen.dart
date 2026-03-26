import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api/api_service.dart';

class ExpenditureDetailScreen extends StatefulWidget {
  final Map<String, dynamic> expenditure;
  final String campaignType;

  const ExpenditureDetailScreen({
    Key? key,
    required this.expenditure,
    required this.campaignType,
  }) : super(key: key);

  @override
  State<ExpenditureDetailScreen> createState() =>
      _ExpenditureDetailScreenState();
}

class _ExpenditureDetailScreenState extends State<ExpenditureDetailScreen> {
  final ApiService _api = ApiService();
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  bool _isLoading = true;
  bool _isSubmitting = false;
  late Map<String, dynamic> _expenditure;
  List<dynamic> _items = [];

  static const _stepLabels = [
    'Lập\nkế hoạch',
    'Chờ\nxét duyệt',
    'Yêu cầu\nrút tiền',
    'Chờ\ngiải ngân',
    'Hoàn\ntất',
  ];

  @override
  void initState() {
    super.initState();
    _expenditure = widget.expenditure;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final r = await _api.getExpenditureItemsByCampaign(
        _expenditure['campaignId'] as int,
      );
      if (r.statusCode == 200) {
        // Filter items belonging to this expenditure
        final all = r.data as List<dynamic>;
        setState(() => _items = all
            .where((it) => it['expenditureId'] == _expenditure['id'])
            .toList());
      }
    } catch (e) {
      debugPrint('Load items error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshExpenditure() async {
    try {
      final r = await _api
          .getExpendituresByCampaign(_expenditure['campaignId'] as int);
      if (r.statusCode == 200 && r.data is List) {
        final list = r.data as List<dynamic>;
        final updated = list.firstWhere(
          (e) => e['id'] == _expenditure['id'],
          orElse: () => _expenditure,
        );
        setState(() => _expenditure = updated);
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  int get _currentStep {
    final status =
        (_expenditure['status'] ?? '').toString().toUpperCase();
    switch (status) {
      case 'PENDING_REVIEW':
        return 1;
      case 'APPROVED':
        return 2;
      case 'WITHDRAWAL_REQUESTED':
        return 3;
      case 'DISBURSED':
        return 4;
      default:
        return 1;
    }
  }

  Future<void> _requestWithdrawal() async {
    final confirmed = await _confirm(
      'Xác nhận yêu cầu rút tiền?',
      'Hệ thống sẽ ghi nhận và thông báo đến Admin để chuyển khoản.',
    );
    if (!confirmed) return;
    setState(() => _isSubmitting = true);
    try {
      final r = await _api.requestWithdrawal(_expenditure['id'] as int);
      if (r.statusCode == 200) {
        _snack('Đã gửi yêu cầu rút tiền thành công!');
        await _refreshExpenditure();
        await _loadItems();
      } else {
        _snack('Gửi yêu cầu thất bại (${r.statusCode})', isError: true);
      }
    } catch (e) {
      _snack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Huỷ')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF84D43)),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xác nhận',
                        style: TextStyle(color: Colors.white))),
              ],
            ),
          ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Đợt chi tiêu #${_expenditure['id']}',
          style: const TextStyle(
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _refreshExpenditure();
                await _loadItems();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepBar(),
                    const SizedBox(height: 24),
                    _buildStepContent(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Step bar ──────────────────────────────────────────
  Widget _buildStepBar() {
    final step = _currentStep;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_stepLabels.length, (i) {
        final isDone = i < step;
        final isActive = i == step;
        final dotColor = (isDone || isActive)
            ? const Color(0xFFF84D43)
            : Colors.grey.shade300;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i == 0
                          ? Colors.transparent
                          : i <= step
                              ? const Color(0xFFF84D43)
                              : Colors.grey.shade300,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: (isDone || isActive)
                          ? const Color(0xFFF84D43)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: dotColor, width: 2),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 14)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i == _stepLabels.length - 1
                          ? Colors.transparent
                          : isDone
                              ? const Color(0xFFF84D43)
                              : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _stepLabels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? const Color(0xFFF84D43)
                      : isDone
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step content ──────────────────────────────────────
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _stepCard(
          title: 'Đang chờ Staff xét duyệt',
          subtitle:
              'Kế hoạch đã được gửi. Nhân viên TrustFundMe sẽ xem xét và phê duyệt sớm nhất.',
          isActive: false,
          extra: [_planCard(), const SizedBox(height: 16), _itemsCard()],
        );
      case 2:
        return Column(children: [
          _stepCard(
            title: 'Kế hoạch đã được phê duyệt',
            subtitle:
                'Bạn có thể gửi yêu cầu rút tiền để nhận khoản giải ngân từ hệ thống.',
            isActive: true,
          ),
          const SizedBox(height: 16),
          _planCard(),
          const SizedBox(height: 16),
          _itemsCard(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _requestWithdrawal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF84D43),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Yêu cầu rút tiền giải ngân',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
            ),
          ),
          const SizedBox(height: 32),
        ]);
      case 3:
        return _stepCard(
          title: 'Đang chờ Admin giải ngân',
          subtitle:
              'Yêu cầu đã được ghi nhận. Admin sẽ chuyển khoản và xác nhận trong hệ thống.',
          isActive: false,
          extra: [_planCard(), const SizedBox(height: 16), _itemsCard()],
        );
      case 4:
        return Column(children: [
          _stepCard(
            title: 'Đã nhận tiền giải ngân',
            subtitle:
                'Tiền đã được chuyển vào tài khoản. Vui lòng mua sắm đúng kế hoạch và nộp hóa đơn trước hạn.',
            isActive: true,
          ),
          const SizedBox(height: 16),
          _planCard(),
          const SizedBox(height: 16),
          _itemsCard(),
          const SizedBox(height: 16),
          if (_expenditure['evidenceDueAt'] != null)
            _infoBox(
              'Hạn nộp hóa đơn: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_expenditure['evidenceDueAt']))}',
            ),
          const SizedBox(height: 32),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _stepCard({
    required String title,
    required String subtitle,
    required bool isActive,
    List<Widget>? extra,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFF84D43).withOpacity(0.06)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFF84D43).withOpacity(0.25)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isActive
                        ? const Color(0xFFF84D43)
                        : const Color(0xFF374151),
                  )),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 13)),
            ],
          ),
        ),
        if (extra != null) ...[
          const SizedBox(height: 16),
          ...extra,
        ]
      ],
    );
  }

  Widget _planCard() {
    final plan = _expenditure['plan'] ?? 'Không có mô tả';
    final total =
        (_expenditure['totalExpectedAmount'] ?? 0).toDouble();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nội dung kế hoạch',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(plan,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 14)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng dự kiến:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_fmt.format(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFFF84D43))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hạng mục chi tiêu (${_items.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Center(
              child: Text('Không có hạng mục.',
                  style:
                      TextStyle(color: Colors.grey.shade500)),
            )
          else
            ...List.generate(_items.length, (idx) {
              final it = _items[idx];
              final ep = (it['expectedPrice'] ?? 0).toDouble();
              final qty = (it['quantity'] ?? 1) as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it['category'] ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF1F2937))),
                          const SizedBox(height: 2),
                          Text('SL: $qty  ×  ${_fmt.format(ep)}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_fmt.format(ep * qty),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1F2937))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _infoBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(msg,
          style: const TextStyle(
              color: Color(0xFF6B7280), fontSize: 13)),
    );
  }
}
