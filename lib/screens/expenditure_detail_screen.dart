import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api/api_service.dart';
import '../core/models/feed_post_media_model.dart';
import '../core/providers/auth_provider.dart';
import 'feed_post_detail_screen.dart';

class ExpenditureDetailScreen extends StatefulWidget {
  final Map<String, dynamic> expenditure;
  final String campaignType;
  final bool forcePublicView;

  const ExpenditureDetailScreen({
    Key? key,
    required this.expenditure,
    required this.campaignType,
    this.forcePublicView = false,
  }) : super(key: key);

  @override
  State<ExpenditureDetailScreen> createState() =>
      _ExpenditureDetailScreenState();
}

class _ExpenditureDetailScreenState extends State<ExpenditureDetailScreen> {
  final ApiService _api = ApiService();
  final NumberFormat _fmt = NumberFormat('#,###', 'en_US');
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSubmittingEvidence = false;
  late Map<String, dynamic> _expenditure;
  List<dynamic> _items = [];
  List<String> _evidencePreviewUrls = <String>[];
  int? _evidencePostId;
  bool _hasEvidencePost = false;
  String? _evidencePostedAt;
  int? _campaignOwnerId;
  final List<XFile> _evidenceImages = <XFile>[];
  final TextEditingController _evidenceNoteCtrl = TextEditingController();

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
    _loadCampaignOwner();
    _loadEvidencePreview();
  }

  @override
  void dispose() {
    _evidenceNoteCtrl.dispose();
    super.dispose();
  }

  String _vnd(num value) => '${_fmt.format(value)} ₫';

  String _expenditureTitle() {
    final String rawPlan = (_expenditure['plan'] ?? '').toString().trim();
    if (rawPlan.isNotEmpty) {
      return rawPlan;
    }
    return 'Chi tiêu đợt #${_expenditure['id']}';
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

  bool get _canManageEvidence {
    final int? me = context.read<AuthProvider>().user?.id;
    return me != null && _campaignOwnerId != null && me == _campaignOwnerId;
  }

  Future<void> _loadCampaignOwner() async {
    try {
      final int campaignId = _expenditure['campaignId'] as int;
      final Response<dynamic> r = await _api.getCampaign(campaignId);
      final dynamic data = r.data;
      if (data is! Map<String, dynamic>) return;
      final dynamic rawOwner = data['fundOwnerId'];
      final int? ownerId = rawOwner is int
          ? rawOwner
          : int.tryParse(rawOwner?.toString() ?? '');
      if (!mounted) return;
      setState(() => _campaignOwnerId = ownerId);
    } catch (_) {}
  }

  Future<void> _loadEvidencePreview() async {
    try {
      final int campaignId = _expenditure['campaignId'] as int;
      final int expenditureId = _expenditure['id'] as int;
      final Response<dynamic> postsRes = await _api.getFeedPosts(
        page: 0,
        size: 20,
        campaignId: campaignId,
      );
      final dynamic payload = postsRes.data;
      if (payload is! Map<String, dynamic>) return;
      final List<dynamic> rows =
          payload['content'] as List<dynamic>? ?? <dynamic>[];
      final List<Map<String, dynamic>> matches = rows
          .whereType<Map<String, dynamic>>()
          .where((Map<String, dynamic> p) {
            final String tt = (p['targetType'] ?? '').toString().toUpperCase();
            final int? tid = (p['targetId'] as num?)?.toInt();
            return tt == 'EXPENDITURE' && tid == expenditureId;
          })
          .toList();
      if (matches.isEmpty) {
        if (!mounted) return;
        setState(() {
          _evidencePreviewUrls = <String>[];
          _evidencePostId = null;
          _hasEvidencePost = false;
          _evidencePostedAt = null;
        });
        return;
      }
      Map<String, dynamic>? evidencePost;
      for (final Map<String, dynamic> p in matches) {
        final String targetName = (p['targetName'] ?? '').toString().trim().toLowerCase();
        if (targetName.startsWith('evidence')) {
          evidencePost = p;
          break;
        }
      }
      evidencePost ??= matches.first;
      final int postId = (evidencePost['id'] as num).toInt();
      final Response<dynamic> mediaRes = await _api.getMediaByPostId(postId);
      final List<FeedPostMediaItem> media = parseFeedPostMediaResponse(mediaRes.data);
      final List<String> urls = media
          .where((FeedPostMediaItem m) => m.isPhoto && m.url.isNotEmpty)
          .map((FeedPostMediaItem m) => m.url)
          .toList();
      if (!mounted) return;
      setState(() {
        _evidencePreviewUrls = urls;
        _evidencePostId = postId;
        _hasEvidencePost = true;
        _evidencePostedAt = evidencePost!['createdAt']?.toString();
      });
    } catch (_) {}
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

  Future<void> _pickEvidenceImages() async {
    final List<XFile> files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _evidenceImages.addAll(files));
  }

  Future<void> _submitEvidence() async {
    final int expenditureId = _expenditure['id'] as int;
    final int campaignId = _expenditure['campaignId'] as int;
    if (_evidenceImages.isEmpty) {
      _snack('Vui lòng chọn ít nhất một ảnh minh chứng.', isError: true);
      return;
    }

    setState(() => _isSubmittingEvidence = true);
    try {
      final String note = _evidenceNoteCtrl.text.trim();
      final Response<dynamic> postRes = await _api.createFeedPost(<String, dynamic>{
        'type': 'UPDATE',
        'visibility': 'PUBLIC',
        'title': 'Cập nhật minh chứng chi tiêu',
        'content': note.isEmpty
            ? 'Tôi vừa cập nhật minh chứng cho hoạt động chi tiêu. Mời mọi người cùng theo dõi.'
            : note,
        'status': 'PUBLISHED',
        'targetId': expenditureId,
        'targetType': 'EXPENDITURE',
      });
      final dynamic postData = postRes.data;
      final int? postId = postData is Map<String, dynamic>
          ? (postData['id'] as num?)?.toInt()
          : null;

      int failUploads = 0;
      for (final XFile x in _evidenceImages) {
        try {
          await _api.uploadMedia(
            File(x.path),
            postId: postId,
            campaignId: campaignId,
            expenditureId: expenditureId,
            mediaType: 'PHOTO',
            description: note.isEmpty
                ? 'Minh chứng chi tiêu cho khoản chi #$expenditureId'
                : note,
          );
        } catch (_) {
          failUploads++;
        }
      }

      await _api.updateEvidenceStatus(expenditureId, 'SUBMITTED');
      await _refreshExpenditure();
      await _loadEvidencePreview();

      if (!mounted) return;
      setState(() {
        _evidenceImages.clear();
        _evidenceNoteCtrl.clear();
      });

      _snack(
        failUploads > 0
            ? 'Đã nộp minh chứng. $failUploads ảnh tải lên lỗi.'
            : 'Đã nộp minh chứng và đăng bài cập nhật.',
      );
    } catch (e) {
      _snack('Nộp minh chứng thất bại: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingEvidence = false);
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
    final bool isOwnerView = !widget.forcePublicView && _canManageEvidence;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          _expenditureTitle(),
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
                    if (isOwnerView) _buildStepBar(),
                    if (isOwnerView) const SizedBox(height: 24),
                    if (!isOwnerView) _buildPublicHint(),
                    const SizedBox(height: 24),
                    isOwnerView ? _buildStepContent() : _buildPublicReadOnlyContent(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPublicHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: const Text(
        'Thông tin đợt chi đang hiển thị ở chế độ công khai.',
        style: TextStyle(
          color: Color(0xFF3730A3),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPublicReadOnlyContent() {
    return Column(
      children: <Widget>[
        _buildWebLikeTopCards(),
        const SizedBox(height: 12),
        _buildWebLikeItemsTable(),
        const SizedBox(height: 16),
        if (_evidencePreviewUrls.isNotEmpty) ...<Widget>[
          _buildEvidenceGallery(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildWebLikeTopCards() {
    final String title = _expenditureTitle();
    final String dueAt = _expenditure['evidenceDueAt']?.toString() ?? '';
    final DateTime? dueDate = dueAt.isNotEmpty ? DateTime.tryParse(dueAt.replaceFirst(' ', 'T')) : null;
    final double totalExpected = (_expenditure['totalExpectedAmount'] ?? 0).toDouble();
    final double disbursed = (_expenditure['disbursedAmount'] ?? 0).toDouble();
    final double spent = (_expenditure['spentAmount'] ?? 0).toDouble();
    final double remaining = (disbursed - spent).clamp(0, double.infinity);
    final double progress = disbursed > 0 ? (spent / disbursed).clamp(0, 1) : 0;
    final String status = (_expenditure['status'] ?? '').toString().toUpperCase();
    final bool hasEvidence = _hasEvidencePost && _evidencePostId != null;

    return Column(
      children: <Widget>[
        _card(
          child: Row(
            children: <Widget>[
              const Icon(Icons.assignment_outlined, color: Color(0xFF1F2937), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hạn nộp: ${dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate) : 'Chưa có'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 154,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _metricCard('Dự kiến', _vnd(totalExpected), width: 148),
              _metricCard('Giải ngân', _vnd(disbursed), width: 148),
              _metricCard('Đã chi', _vnd(spent), width: 148),
              _metricCard('Số dư', _vnd(remaining), width: 148),
              Container(
                width: 210,
                margin: const EdgeInsets.only(right: 10),
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status == 'DISBURSED' ? 'Đã giải ngân' : status,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% tiến độ sử dụng',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 240,
                margin: const EdgeInsets.only(right: 4),
                child: _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text('Minh chứng', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasEvidence ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              hasEvidence ? 'Đã nộp' : 'Chưa nộp',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: hasEvidence ? const Color(0xFF166534) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nộp lúc: ${_evidencePostedAt != null ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(_evidencePostedAt!.replaceFirst(' ', 'T')) ?? DateTime.now()) : '---'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: hasEvidence
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => FeedPostDetailScreen(postId: _evidencePostId!),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.open_in_new, size: 15),
                          label: const Text('Xem bài đăng minh chứng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, {double width = 140}) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebLikeItemsTable() {
    final double totalExpected = (_expenditure['totalExpectedAmount'] ?? 0).toDouble();
    final double disbursed = (_expenditure['disbursedAmount'] ?? 0).toDouble();
    final double spent = (_expenditure['spentAmount'] ?? 0).toDouble();
    final double progress = disbursed > 0 ? (spent / disbursed).clamp(0, 1) : 0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.table_rows_outlined, size: 16, color: Color(0xFF374151)),
              const SizedBox(width: 6),
              Text(
                'Danh sách hạng mục chi tiêu (${_items.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 48,
              horizontalMargin: 8,
              columnSpacing: 18,
              columns: const <DataColumn>[
                DataColumn(label: Text('STT')),
                DataColumn(label: Text('Hạng mục')),
                DataColumn(label: Text('Kế hoạch')),
                DataColumn(label: Text('Đã chi')),
                DataColumn(label: Text('Tiến độ')),
              ],
              rows: _items.asMap().entries.map((entry) {
                final int idx = entry.key;
                final dynamic it = entry.value;
                final double expectedPrice = (it['expectedPrice'] ?? 0).toDouble();
                final int quantity = (it['quantity'] ?? 1) as int;
                final double planned = expectedPrice * quantity;
                final double actualUnit = (it['actualPrice'] ?? expectedPrice).toDouble();
                final double actual = actualUnit * quantity;
                final double ratio = planned > 0 ? (actual / planned).clamp(0, 1) : 0;
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text('${idx + 1}')),
                    DataCell(SizedBox(
                      width: 122,
                      child: Text(
                        (it['category'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    DataCell(Text(_vnd(planned))),
                    DataCell(Text(_vnd(actual))),
                    DataCell(SizedBox(
                      width: 92,
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF065F46)),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(child: Text('Dự kiến: ${_vnd(totalExpected)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(child: Text('Đã chi: ${_vnd(spent)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(
                  child: Text(
                    'Tiến độ: ${(progress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          const SizedBox(height: 16),
          _buildEvidenceStatusCard(),
          const SizedBox(height: 16),
          if (_evidencePreviewUrls.isNotEmpty) ...<Widget>[
            _buildEvidenceGallery(),
            const SizedBox(height: 16),
          ],
          if (_canManageEvidence)
            _buildEvidenceComposer()
          else
            _infoBox('Bạn chỉ có quyền xem minh chứng. Chỉ chủ chiến dịch mới được nộp.'),
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
              Text(_vnd(total),
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
                          Text('SL: $qty  ×  ${_vnd(ep)}',
                              style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_vnd(ep * qty),
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

  Widget _buildEvidenceStatusCard() {
    final bool hasEvidence = _hasEvidencePost && _evidencePostId != null;
    String submittedAtLabel = '';
    if (_evidencePostedAt != null && _evidencePostedAt!.trim().isNotEmpty) {
      final DateTime? d = DateTime.tryParse(_evidencePostedAt!.replaceFirst(' ', 'T'));
      if (d != null) {
        submittedAtLabel =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.verified_outlined, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              const Text(
                'Minh chứng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasEvidence ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasEvidence ? 'Đã nộp' : 'Chưa nộp',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasEvidence ? const Color(0xFF166534) : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          if (submittedAtLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Nộp lúc: $submittedAtLabel',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          if (hasEvidence) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FeedPostDetailScreen(postId: _evidencePostId!),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Xem bài đăng minh chứng'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceComposer() {
    final bool canSubmit = _evidenceImages.isNotEmpty && !_isSubmittingEvidence;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Nộp minh chứng chi tiêu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ảnh minh chứng sẽ được tải lên và hệ thống tự động đăng bài cập nhật.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSubmittingEvidence ? null : _pickEvidenceImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('Chọn ảnh (${_evidenceImages.length})'),
          ),
          if (_evidenceImages.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _evidenceImages.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (_, int i) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_evidenceImages[i].path),
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black87,
                            padding: const EdgeInsets.all(2),
                            minimumSize: const Size(24, 24),
                          ),
                          icon: const Icon(Icons.close, color: Colors.white, size: 14),
                          onPressed: _isSubmittingEvidence
                              ? null
                              : () => setState(() => _evidenceImages.removeAt(i)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _evidenceNoteCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Mô tả / lời cảm ơn (tuỳ chọn)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSubmit ? _submitEvidence : null,
              icon: _isSubmittingEvidence
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isSubmittingEvidence ? 'Đang gửi...' : 'Gửi minh chứng & đăng bài'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceGallery() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Ảnh minh chứng',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _evidencePreviewUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, int i) {
                return GestureDetector(
                  onTap: () => _openEvidenceViewer(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _evidencePreviewUrls[i],
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 110,
                        height: 110,
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
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
  }

  void _openEvidenceViewer(int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext dialogContext) {
        final PageController pageController = PageController(initialPage: initialIndex);
        int currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                title: Text(
                  '${currentIndex + 1}/${_evidencePreviewUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                centerTitle: true,
              ),
              body: PageView.builder(
                controller: pageController,
                itemCount: _evidencePreviewUrls.length,
                onPageChanged: (int index) {
                  setModalState(() => currentIndex = index);
                },
                itemBuilder: (_, int index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        _evidencePreviewUrls[index],
                        fit: BoxFit.contain,
                        loadingBuilder: (_, Widget child, ImageChunkEvent? progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
