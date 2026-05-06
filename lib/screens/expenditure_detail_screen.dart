import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/expenditure_service.dart';
import '../core/api/media_service.dart';

// ─────────────────── Color scheme (matching web) ───────────────────
const Color _headerBg = Color(0xFF1E3A5F); // dark blue
const Color _categoryBg = Color(0xFFE0F2FE); // light blue
const Color _actualPrice = Color(0xFFEA580C); // orange
const Color _plannedBg = Color(0xFFF9FAFB); // gray-50
const Color _plannedText = Color(0xFF6B7280); // gray-500
const Color _badgeGreen = Color(0xFF10B981); // green
const Color _overBudget = Color(0xFFEF4444); // red
const Color _text = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);

/// Màn hình chi tiết một đợt chi (expenditure) — redesigned giống web.
///
/// Nhận [expenditure] là Map<String, dynamic> từ API response,
/// [campaignType] xác định loại campaign (ITEMIZED / SIMPLE / AUTHORIZED),
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
  static const Map<String, String> _statusLabels = <String, String>{
    'PENDING': 'Chờ duyệt',
    'PENDING_REVIEW': 'Chờ duyệt',
    'APPROVED': 'Đã duyệt',
    'REJECTED': 'Bị từ chối',
    'DISBURSED': 'Đã giải ngân',
    'COMPLETED': 'Hoàn thành',
    'CLOSED': 'Đã đóng',
    'SUBMITTED': 'Đã nộp MC',
    'ALLOWED_EDIT': 'Yêu cầu chỉnh sửa',
    'WITHDRAWAL_REQUESTED': 'Đã yêu cầu rút tiền',
    'OVERDUE': 'Quá hạn',
  };

  static const Map<String, Color> _statusColors = <String, Color>{
    'PENDING': Colors.amber,
    'PENDING_REVIEW': Colors.amber,
    'APPROVED': Color(0xFF10B981),
    'REJECTED': Color(0xFFEF4444),
    'DISBURSED': Color(0xFF3B82F6),
    'COMPLETED': Color(0xFF10B981),
    'CLOSED': Color(0xFF6B7280),
    'SUBMITTED': Color(0xFF10B981),
    'ALLOWED_EDIT': Colors.amber,
    'WITHDRAWAL_REQUESTED': Color(0xFF3B82F6),
    'OVERDUE': Color(0xFFEF4444),
  };

  late Map<String, dynamic> _exp;
  final ExpenditureService _expenditureSvc = ExpenditureService();
  final MediaService _mediaSvc = MediaService();

  List<Map<String, dynamic>> _categories = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  Map<int, List<Map<String, dynamic>>> _itemMedia = {};
  bool _loadingDetails = true;

  // Collapsible category state
  final Set<dynamic> _collapsedCats = {};

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
      // Load latest expenditure detail
      try {
        final detailRes = await _expenditureSvc.getExpenditureById(expId);
        final dynamic rawDetail = detailRes.data;
        if (rawDetail is Map<String, dynamic>) {
          _exp = <String, dynamic>{..._exp, ...rawDetail};
        }
      } catch (_) {}

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

      // Load evidence media for each item (lazy — just load all item IDs)
      for (final item in _items) {
        final itemId = _parseInt(item['id']);
        if (itemId != null) {
          try {
            final mediaRes = await _mediaSvc.getMediaByExpenditureItem(itemId);
            if (mediaRes.data is List) {
              _itemMedia[itemId] = (mediaRes.data as List)
                  .whereType<Map<String, dynamic>>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loadingDetails = false);
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatCurrency(dynamic v) {
    final double val = _parseDouble(v);
    return NumberFormat('#,###', 'vi_VN').format(val.abs()) + ' đ';
  }

  String _formatDate(dynamic v) {
    if (v == null) return '—';
    DateTime? d;
    if (v is List && v.length >= 3) {
      final int year = _parseInt(v[0]) ?? 0;
      final int month = _parseInt(v[1]) ?? 1;
      final int day = _parseInt(v[2]) ?? 1;
      final int hour = v.length > 3 ? (_parseInt(v[3]) ?? 0) : 0;
      final int minute = v.length > 4 ? (_parseInt(v[4]) ?? 0) : 0;
      final int second = v.length > 5 ? (_parseInt(v[5]) ?? 0) : 0;
      if (year > 0) {
        d = DateTime(year, month, day, hour, minute, second);
      }
    } else {
      d = DateTime.tryParse(v.toString().replaceFirst(' ', 'T'));
    }
    if (d == null) return v.toString();
    return DateFormat('dd/MM/yyyy').format(d);
  }

  /// Group items by catologyId matching categories
  Map<dynamic, _CategoryGroup> _groupItems() {
    final Map<int, Map<String, dynamic>> catMap = {};
    for (final cat in _categories) {
      final id = _parseInt(cat['id']);
      if (id != null) catMap[id] = cat;
    }

    final Map<dynamic, _CategoryGroup> groups = {};

    // Initialize groups from categories
    for (final cat in _categories) {
      final id = _parseInt(cat['id']);
      if (id != null) {
        groups[id] = _CategoryGroup(category: cat, items: []);
      }
    }

    // Assign items to categories
    for (final item in _items) {
      final catId = _parseInt(item['catologyId']);
      if (catId != null && groups.containsKey(catId)) {
        groups[catId]!.items.add(item);
      } else {
        // "other" group for items without matching category
        groups.putIfAbsent('other', () => _CategoryGroup(category: null, items: []));
        groups['other']!.items.add(item);
      }
    }

    return groups;
  }

  bool get _isEvidenceSubmitted {
    final status = ((_exp['evidenceStatus'] ?? _exp['status']) as String? ?? '').toUpperCase();
    return ['SUBMITTED', 'APPROVED', 'ALLOWED_EDIT'].contains(status);
  }

  double get _totalActual {
    double total = 0;
    for (final item in _items) {
      total += _parseDouble(item['actualQuantity']) * _parseDouble(item['actualPrice']);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final String plan = (_exp['plan'] as String?) ?? 'Đợt chi #${_parseInt(_exp['id']) ?? ''}';
    final String status =
        ((_exp['status'] ?? _exp['evidenceStatus']) as String? ?? 'PENDING')
            .toUpperCase();
    final String statusLabel = _statusLabels[status] ?? status;
    final Color statusColor = _statusColors[status] ?? _muted;
    final String createdAt = _formatDate(
      _exp['createdAt'] ?? _exp['updatedAt'] ?? _exp['startDate'],
    );
    final double totalExpected =
        _parseDouble(_exp['totalExpectedAmount'] ?? 0);
    final double totalSpent =
        _parseDouble(_exp['totalAmount'] ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tổng quan đợt chi tiêu',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
        surfaceTintColor: Colors.white,
      ),
      body: _loadingDetails
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _badgeGreen),
                  SizedBox(height: 12),
                  Text(
                    'ĐANG TẢI DỮ LIỆU...',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _text,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: _actualPrice,
              onRefresh: () async {
                setState(() => _loadingDetails = true);
                await _loadDetails();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  // ─── Header card ─────────────────────────────────
                  _buildHeaderCard(
                    plan: plan,
                    statusLabel: statusLabel,
                    statusColor: statusColor,
                    createdAt: createdAt,
                    totalExpected: totalExpected,
                    totalSpent: totalSpent,
                  ),
                  const SizedBox(height: 12),

                  // ─── Categories + Items table ──────────────────
                  if (_categories.isNotEmpty || _items.isNotEmpty) ...[
                    _buildItemsSection(),
                    const SizedBox(height: 12),
                  ],

                  // ─── Footer total bar ──────────────────────────
                  _buildTotalBar(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ██ HEADER CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeaderCard({
    required String plan,
    required String statusLabel,
    required Color statusColor,
    required String createdAt,
    required double totalExpected,
    required double totalSpent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Status badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    plan,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _headerInfoRow(Icons.calendar_today, 'Ngày tạo', createdAt),
                const SizedBox(height: 10),
                _headerInfoRow(
                  Icons.account_balance_wallet_outlined,
                  'Tổng dự kiến',
                  _formatCurrency(totalExpected),
                  valueColor: const Color(0xFF1E3A5F),
                ),
                if (totalSpent > 0 || _isEvidenceSubmitted) ...[
                  const SizedBox(height: 10),
                  _headerInfoRow(
                    Icons.payments_outlined,
                    'Tổng đã chi',
                    _isEvidenceSubmitted
                        ? _formatCurrency(_totalActual)
                        : 'Chưa cập nhật',
                    valueColor: _isEvidenceSubmitted
                        ? (_totalActual > totalExpected && totalExpected > 0
                            ? _overBudget
                            : _badgeGreen)
                        : _muted,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? _text,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ██ ITEMS SECTION — grouped by category
  // ═══════════════════════════════════════════════════════════════
  Widget _buildItemsSection() {
    final groups = _groupItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_cart, size: 16, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 8),
              const Text(
                'DANH SÁCH HẠNG MỤC CHI TIÊU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _text,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Table header row
        _buildTableHeader(),

        // Category groups
        ...groups.entries.map((entry) {
          final catId = entry.key;
          final group = entry.value;
          final isCollapsed = _collapsedCats.contains(catId);
          final catName = group.category != null
              ? (group.category!['name'] as String? ?? 'Danh mục')
              : 'Hạng mục phát sinh';

          return Column(
            children: [
              // Category row (collapsible)
              _buildCategoryRow(catId, catName, isCollapsed, catId == 'other'),

              // Items (if not collapsed)
              if (!isCollapsed)
                ...group.items.map((item) => _buildItemCard(item, catId)),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _headerBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'HẠNG MỤC',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'SL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ĐƠN GIÁ',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'THÀNH TIỀN',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(dynamic catId, String name, bool isCollapsed, bool isOther) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isCollapsed) {
            _collapsedCats.remove(catId);
          } else {
            _collapsedCats.add(catId);
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _categoryBg,
          border: Border(
            bottom: BorderSide(color: _border.withOpacity(0.5)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              size: 18,
              color: const Color(0xFF0369A1),
            ),
            const SizedBox(width: 6),
            if (isOther)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PHÁT SINH',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                'DANH MỤC: ${name.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0C4A6E),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ██ ITEM CARD — 2 rows: actual (top) + planned (bottom)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildItemCard(Map<String, dynamic> item, dynamic catId) {
    final String name = (item['name'] as String?) ?? 'Hạng mục';
    final String brand = (item['actualBrand'] ?? item['purchaseLocation'] ?? '') as String;
    final String expectedBrand = (item['expectedBrand'] ?? '') as String;
    // unit & expectedUnit kept for potential future use (e.g., unit column)
    // ignore: unused_local_variable
    final String unit = (item['actualUnit'] ?? item['unit'] ?? item['expectedUnit'] ?? '') as String;
    // ignore: unused_local_variable
    final String expectedUnit = (item['expectedUnit'] ?? item['unit'] ?? '') as String;

    final double actualQty = _parseDouble(item['actualQuantity']);
    final double actualPriceVal = _parseDouble(item['actualPrice']);
    final double actualSubtotal = actualQty * actualPriceVal;

    final double expectedQty = _parseDouble(item['expectedQuantity'] ?? item['quantity']);
    final double expectedPriceVal = _parseDouble(item['expectedPrice']);
    final double expectedSubtotal = expectedQty * expectedPriceVal;

    final bool isOverBudget = actualPriceVal > expectedPriceVal && expectedPriceVal > 0;

    final int? itemId = _parseInt(item['id']);
    final List<Map<String, dynamic>> media = itemId != null ? (_itemMedia[itemId] ?? []) : [];
    final bool hasMedia = media.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _border.withOpacity(0.5)),
        ),
      ),
      child: Column(
        children: [
          // ── ACTUAL ROW (bold) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Brand
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (brand.isNotEmpty)
                        Text(
                          brand,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Quantity
                Expanded(
                  flex: 1,
                  child: Text(
                    _isEvidenceSubmitted ? '${actualQty.toInt()}' : '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _isEvidenceSubmitted ? _text : _muted,
                    ),
                  ),
                ),
                // Unit Price
                Expanded(
                  flex: 2,
                  child: Text(
                    _isEvidenceSubmitted
                        ? _formatCurrency(actualPriceVal)
                        : '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _isEvidenceSubmitted
                          ? (isOverBudget ? _overBudget : _actualPrice)
                          : _muted,
                    ),
                  ),
                ),
                // Subtotal
                Expanded(
                  flex: 2,
                  child: Text(
                    _isEvidenceSubmitted
                        ? _formatCurrency(actualSubtotal)
                        : '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: _isEvidenceSubmitted
                          ? (isOverBudget ? _overBudget : _actualPrice)
                          : _muted,
                    ),
                  ),
                ),
                // Photo icon
                SizedBox(
                  width: 32,
                  child: GestureDetector(
                    onTap: hasMedia
                        ? () => _showPhotoGallery(name, media)
                        : null,
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: hasMedia
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasMedia
                              ? const Color(0xFF10B981).withOpacity(0.3)
                              : _border,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: hasMedia
                            ? const Color(0xFF10B981)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── PLANNED ROW (smaller, gray) ──
          if (catId != 'other')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: _plannedBg,
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge + Name
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _badgeGreen,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'KẾ HOẠCH',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _plannedText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (expectedBrand.isNotEmpty)
                                Text(
                                  expectedBrand,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _plannedText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quantity
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${expectedQty.toInt()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _plannedText,
                      ),
                    ),
                  ),
                  // Unit Price
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCurrency(expectedPriceVal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _plannedText,
                      ),
                    ),
                  ),
                  // Subtotal
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCurrency(expectedSubtotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _plannedText,
                      ),
                    ),
                  ),
                  // Spacer for photo column
                  const SizedBox(width: 32),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ██ FOOTER TOTAL BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTotalBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _headerBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: _headerBg.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'TỔNG THỰC TẾ TOÀN CHIẾN DỊCH:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            _isEvidenceSubmitted
                ? _formatCurrency(_totalActual)
                : 'Chưa cập nhật',
            style: TextStyle(
              fontSize: _isEvidenceSubmitted ? 16 : 12,
              fontWeight: FontWeight.w900,
              color: _isEvidenceSubmitted
                  ? Colors.white
                  : Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ██ PHOTO GALLERY DIALOG
  // ═══════════════════════════════════════════════════════════════
  void _showPhotoGallery(String itemName, List<Map<String, dynamic>> media) {
    final photos = media
        .where((m) => ((m['url'] as String?) ?? '').isNotEmpty)
        .toList();

    if (photos.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ẢNH MINH CHỨNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _muted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${photos.length} ảnh',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Photos grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (_, i) {
                    final url = (photos[i]['url'] as String?) ?? '';
                    return GestureDetector(
                      onTap: () => _showFullImage(ctx, url, itemName),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF9CA3AF),
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext parentCtx, String url, String title) {
    Navigator.of(parentCtx).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────── Helper class ───────────────────

class _CategoryGroup {
  _CategoryGroup({required this.category, required this.items});
  final Map<String, dynamic>? category;
  final List<Map<String, dynamic>> items;
}
