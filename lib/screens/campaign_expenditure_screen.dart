import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api/api_service.dart';
import 'expenditure_detail_screen.dart';

// ── Item form model ─────────────────────────────────────
class _ItemModel {
  final TextEditingController category = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController expectedPrice = TextEditingController();
  final TextEditingController note = TextEditingController();

  void dispose() {
    category.dispose();
    quantity.dispose();
    expectedPrice.dispose();
    note.dispose();
  }
}

// ── Main screen ─────────────────────────────────────────
class CampaignExpenditureScreen extends StatefulWidget {
  final int campaignId;
  final String campaignTitle;
  final String campaignType;

  const CampaignExpenditureScreen({
    Key? key,
    required this.campaignId,
    required this.campaignTitle,
    required this.campaignType,
  }) : super(key: key);

  @override
  State<CampaignExpenditureScreen> createState() =>
      _CampaignExpenditureScreenState();
}

class _CampaignExpenditureScreenState
    extends State<CampaignExpenditureScreen> {
  final ApiService _api = ApiService();
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  bool _isLoading = true;
  List<dynamic> _expenditures = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final r =
          await _api.getExpendituresByCampaign(widget.campaignId);
      if (r.statusCode == 200 && r.data is List) {
        setState(() => _expenditures = r.data as List<dynamic>);
      }
    } catch (e) {
      debugPrint('Load expenditures error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Status helpers ─────────────────────────────────────
  String _statusLabel(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING_REVIEW':
        return 'Chờ xét duyệt';
      case 'APPROVED':
        return 'Đã phê duyệt';
      case 'WITHDRAWAL_REQUESTED':
        return 'Chờ giải ngân';
      case 'DISBURSED':
        return 'Đã giải ngân';
      default:
        return raw ?? '—';
    }
  }

  Color _statusColor(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING_REVIEW':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'WITHDRAWAL_REQUESTED':
        return Colors.blue;
      case 'DISBURSED':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // ── Create sheet ───────────────────────────────────────
  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateExpenditureSheet(
        campaignId: widget.campaignId,
        campaignType: widget.campaignType,
        api: _api,
        onCreated: _load,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Kế hoạch chi tiêu',
          style: TextStyle(
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campaign info strip
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.campaignType == 'ITEMIZED'
                            ? 'Quỹ Hạng mục'
                            : 'Quỹ Ủy quyền',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.campaignTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1F2937)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_expenditures.length} đợt',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _expenditures.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _expenditures.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _buildCard(_expenditures[i], i + 1),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: const Color(0xFFF84D43),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tạo đợt mới',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Chưa có đợt chi tiêu nào',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF374151)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhấn "+ Tạo đợt mới" để lập kế hoạch chi tiêu đầu tiên.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> exp, int index) {
    final status = exp['status'] as String?;
    final total = (exp['totalExpectedAmount'] ?? 0).toDouble();
    final createdAt = exp['createdAt'] != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(exp['createdAt']))
        : '—';
    final color = _statusColor(status);

    return InkWell(
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
        _load(); // refresh after returning
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đợt $index',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1F2937)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Plan preview
            if (exp['plan'] != null && (exp['plan'] as String).isNotEmpty)
              Text(
                exp['plan'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13),
              ),
            const SizedBox(height: 12),

            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tạo ngày $createdAt',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12),
                ),
                Row(
                  children: [
                    Text(
                      _fmt.format(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFF84D43)),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Bottom Sheet – Tạo đợt chi tiêu mới
// ══════════════════════════════════════════════════════════
class _CreateExpenditureSheet extends StatefulWidget {
  final int campaignId;
  final String campaignType;
  final ApiService api;
  final VoidCallback onCreated;

  const _CreateExpenditureSheet({
    required this.campaignId,
    required this.campaignType,
    required this.api,
    required this.onCreated,
  });

  @override
  State<_CreateExpenditureSheet> createState() =>
      _CreateExpenditureSheetState();
}

class _CreateExpenditureSheetState
    extends State<_CreateExpenditureSheet> {
  final _formKey = GlobalKey<FormState>();
  final _planCtrl = TextEditingController();
  DateTime? _evidenceDueAt;
  bool _isSubmitting = false;
  final List<_ItemModel> _items = [_ItemModel()];
  final NumberFormat _fmt =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  void dispose() {
    _planCtrl.dispose();
    for (final it in _items) it.dispose();
    super.dispose();
  }

  double get _previewTotal => _items.fold(0.0, (sum, m) {
        final qty = int.tryParse(m.quantity.text) ?? 0;
        final price = double.tryParse(m.expectedPrice.text) ?? 0;
        return sum + qty * price;
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_evidenceDueAt == null) {
      _snack('Vui lòng chọn hạn chót nộp minh chứng!', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final body = {
        'campaignId': widget.campaignId,
        'evidenceDueAt': _evidenceDueAt!.toIso8601String(),
        'evidenceStatus': 'PENDING',
        'plan': _planCtrl.text.trim(),
        'items': _items
            .map((m) => {
                  'category': m.category.text.trim(),
                  'quantity': int.tryParse(m.quantity.text.trim()) ?? 1,
                  'price': 0.0,
                  'expectedPrice':
                      double.tryParse(m.expectedPrice.text.trim()) ?? 0.0,
                  'note': m.note.text.trim(),
                })
            .toList(),
      };
      final r = await widget.api.createExpenditure(body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        Navigator.pop(context);
        widget.onCreated();
        _snack(
          widget.campaignType == 'ITEMIZED'
              ? 'Tạo thành công! Đã tự động phê duyệt.'
              : 'Đã gửi kế hoạch! Đang chờ Staff xét duyệt.',
        );
      } else {
        _snack('Tạo thất bại (${r.statusCode})', isError: true);
      }
    } catch (e) {
      _snack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tạo đợt chi tiêu mới',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Color(0xFF1F2937)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (widget.campaignType == 'ITEMIZED')
                      _infoBox(
                        'Quỹ Hạng mục: Kế hoạch sẽ tự động được phê duyệt ngay khi tạo.',
                      )
                    else
                      _infoBox(
                        'Quỹ Ủy quyền: Kế hoạch sẽ được gửi cho Staff xét duyệt.',
                      ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _planCtrl,
                      maxLines: 3,
                      decoration: _dec(
                        'Nội dung kế hoạch chi tiêu *',
                        hint: 'Mô tả ngắn gọn mục đích chi tiêu...',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Không được để trống'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now()
                              .add(const Duration(days: 7)),
                          firstDate: DateTime.now()
                              .add(const Duration(days: 1)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _evidenceDueAt = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          border: Border.all(
                              color: _evidenceDueAt == null
                                  ? Colors.grey.shade400
                                  : const Color(0xFFF84D43)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event,
                                size: 20,
                                color: _evidenceDueAt == null
                                    ? Colors.grey
                                    : const Color(0xFFF84D43)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _evidenceDueAt == null
                                    ? 'Chọn hạn chót nộp hóa đơn *'
                                    : 'Hạn: ${DateFormat('dd/MM/yyyy').format(_evidenceDueAt!)}',
                                style: TextStyle(
                                    color: _evidenceDueAt == null
                                        ? Colors.grey.shade600
                                        : const Color(0xFF1F2937),
                                    fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Danh sách hạng mục',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1F2937))),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _items.add(_ItemModel())),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm'),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFF84D43)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...List.generate(_items.length, (i) {
                      final m = _items[i];
                      return StatefulBuilder(
                        builder: (_, setLocal) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Hạng mục ${i + 1}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color:
                                                Color(0xFF374151))),
                                    if (_items.length > 1)
                                      InkWell(
                                        onTap: () => setState(
                                            () => _items.removeAt(i)),
                                        child: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 20,
                                            color: Colors.red),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: m.category,
                                  decoration: _dec('Tên vật phẩm *',
                                      hint: 'VD: Áo phao, Mì tôm...'),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Bắt buộc'
                                          : null,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: m.quantity,
                                        keyboardType:
                                            TextInputType.number,
                                        onChanged: (_) =>
                                            setState(() {}),
                                        decoration: _dec('Số lượng *'),
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Bắt buộc';
                                          if ((int.tryParse(v) ?? 0) <=
                                              0) return '> 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 4,
                                      child: TextFormField(
                                        controller: m.expectedPrice,
                                        keyboardType:
                                            TextInputType.number,
                                        onChanged: (_) =>
                                            setState(() {}),
                                        decoration: _dec(
                                            'Đơn giá dự kiến (VNĐ) *',
                                            hint: '40000'),
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Bắt buộc';
                                          if ((double.tryParse(v) ??
                                                  -1) <
                                              0) return '≥ 0';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Preview total
                    if (_previewTotal > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tổng dự kiến:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(_fmt.format(_previewTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFFF84D43))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
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
                            : const Text('Tạo đợt chi tiêu',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String msg) {
    return Container(
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
