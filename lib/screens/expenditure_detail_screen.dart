import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/expenditure_service.dart';
import '../core/api/media_service.dart';

/// Màn hình chi tiết một đợt chi (expenditure).
///
/// Nhận [expenditure] là Map<String, dynamic> từ API response,
/// [campaignType] xác định loại campaign (ITEMIZED / SIMPLE),
/// [forcePublicView] dùng khi navigate từ feed (ẩn action buttons).
class ExpenditureDetailScreen extends StatefulWidget {
  const ExpenditureDetailScreen({
    super.key,
    required this.expenditure,
    this.campaignType = 'ITEMIZED',
    this.forcePublicView = false,
  });

  final Map<String, dynamic> expenditure;
  final String campaignType;
  final bool forcePublicView;

  @override
  State<ExpenditureDetailScreen> createState() =>
      _ExpenditureDetailScreenState();
}

class _ExpenditureDetailScreenState extends State<ExpenditureDetailScreen> {
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _primary = Color(0xFFF84D43);

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

  late Map<String, dynamic> _exp;
  final ExpenditureService _expenditureSvc = ExpenditureService();
  final MediaService _mediaSvc = MediaService();

  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<String> _evidenceUrls = <String>[];
  bool _loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _exp = Map<String, dynamic>.from(widget.expenditure);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final int? expId = _parseInt(_exp['id']);
    if (expId == null) {
      if (mounted) setState(() => _loadingDetails = false);
      return;
    }

    try {
      // Load categories
      try {
        final catRes = await _expenditureSvc.getExpenditureCategories(expId);
        if (catRes.data is List) {
          _categories = (catRes.data as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      // Load items
      try {
        final itemRes = await _expenditureSvc.getExpenditureItems(expId);
        if (itemRes.data is List) {
          _items = (itemRes.data as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      // Load evidence media
      try {
        final mediaRes = await _mediaSvc.getMediaByExpenditure(expId);
        final dynamic mediaData = mediaRes.data;
        if (mediaData is List) {
          _evidenceUrls = mediaData
              .whereType<Map<String, dynamic>>()
              .where((m) =>
                  (m['mediaType'] as String?)?.toUpperCase() == 'EVIDENCE')
              .map((m) => (m['url'] as String?) ?? '')
              .where((u) => u.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    } catch (_) {}

    if (mounted) setState(() => _loadingDetails = false);
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _formatCurrency(dynamic v) {
    if (v == null) return '—';
    final double val = (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0);
    return NumberFormat('#,###', 'vi_VN').format(val) + 'đ';
  }

  String _formatDate(dynamic v) {
    if (v == null) return '—';
    final DateTime? d = DateTime.tryParse(v.toString().replaceFirst(' ', 'T'));
    if (d == null) return v.toString();
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final String plan = (_exp['plan'] as String?) ?? 'Đợt chi #${_parseInt(_exp['id']) ?? ''}';
    final String status =
        ((_exp['status'] ?? _exp['evidenceStatus']) as String? ?? 'PENDING')
            .toUpperCase();
    final String statusLabel = _statusLabels[status] ?? status;
    final Color statusColor = _statusColors[status] ?? _muted;
    final String createdAt = _formatDate(_exp['createdAt']);
    final double totalExpected =
        ((_exp['totalExpectedAmount'] ?? 0) as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          plan,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
      ),
      body: _loadingDetails
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: _primary,
              onRefresh: _loadDetails,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  // ─── Header card ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          plan,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoRow('Trạng thái', statusLabel,
                            valueColor: statusColor),
                        _infoRow('Ngày tạo', createdAt),
                        if (totalExpected > 0)
                          _infoRow('Tổng dự kiến', _formatCurrency(totalExpected)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Categories + Items ──────────────────────────
                  if (_categories.isNotEmpty || _items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Hạng mục chi tiêu',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_items.isNotEmpty)
                            ..._items.map((item) => _buildItemTile(item)),
                          if (_items.isEmpty && _categories.isNotEmpty)
                            ..._categories.map((cat) => _buildCategoryTile(cat)),
                        ],
                      ),
                    ),

                  // ─── Evidence images ─────────────────────────────
                  if (_evidenceUrls.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Ảnh minh chứng',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._evidenceUrls.map((url) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    url,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      color: const Color(0xFFE5E7EB),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final String name = (item['name'] as String?) ??
        (item['category'] as String?) ??
        'Hạng mục';
    final int qty = _parseInt(item['quantity']) ?? 1;
    final double price = ((item['expectedPrice'] ?? item['price'] ?? 0) as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                if (item['note'] != null &&
                    (item['note'] as String).isNotEmpty)
                  Text(
                    item['note'] as String,
                    style: const TextStyle(fontSize: 12, color: _muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'x$qty',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              Text(
                _formatCurrency(price),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> cat) {
    final String name = (cat['name'] as String?) ??
        (cat['category'] as String?) ??
        'Danh mục';
    final List items = (cat['items'] as List?) ?? <dynamic>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          if (items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            ...items.whereType<Map<String, dynamic>>().map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            (item['name'] as String?) ?? 'Hạng mục',
                            style: const TextStyle(fontSize: 13, color: _text),
                          ),
                        ),
                        Text(
                          'x${_parseInt(item['quantity']) ?? 1}  ${_formatCurrency(item['expectedPrice'] ?? item['price'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
