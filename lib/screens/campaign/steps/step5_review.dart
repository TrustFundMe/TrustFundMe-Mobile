import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/campaign_service.dart';
import '../../../core/models/new_campaign_state.dart';
import '../../../core/utils/error_handler.dart';

/// Step 5: Review & Submit — tóm tắt tất cả thông tin và gửi duyệt.
/// Redesign: thêm bank summary, edit buttons, cập nhật color scheme giống web.
class Step5Review extends StatefulWidget {
  final NewCampaignState campaignState;
  final ValueChanged<bool> onValidChanged;

  /// Callback quay lại step cụ thể (0-indexed).
  final ValueChanged<int>? onGoToStep;

  const Step5Review({
    super.key,
    required this.campaignState,
    required this.onValidChanged,
    this.onGoToStep,
  });

  @override
  State<Step5Review> createState() => _Step5ReviewState();
}

class _Step5ReviewState extends State<Step5Review>
    with AutomaticKeepAliveClientMixin {
  final CampaignService _campaignService = CampaignService();
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');

  bool _isSubmitting = false;
  String? _submitError;
  bool _submitted = false;

  // ── Color scheme ────────────────────────────────────────────────
  static const Color _checkGreen = Color(0xFF16A34A);
  static const Color _errorRed = Color(0xFFEF4444);
  static const Color _editOrange = Color(0xFFEA580C);
  static const Color _headerBlue = Color(0xFF1E3A5F);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Step 5 không cần nút "Tiếp tục" ở bottom nav — submit có nút riêng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onValidChanged(false); // Ẩn nút tiếp tục
    });
  }

  NewCampaignState get _state => widget.campaignState;

  /// Validation checklist tổng hợp.
  List<_CheckItem> get _checklist {
    final core = _state.campaignCore;
    final milestones = _state.milestones;
    final ack = _state.acknowledgements;
    final bank = _state.bankInfo;

    return [
      _CheckItem(
        label: 'KYC đã xác minh',
        passed: _state.kycStatus == 'APPROVED',
      ),
      _CheckItem(
        label: 'Thông tin chiến dịch đầy đủ',
        passed: core.validate().isEmpty,
      ),
      _CheckItem(
        label: 'Có ít nhất 1 đợt giải ngân',
        passed: milestones.isNotEmpty,
      ),
      _CheckItem(
        label: 'Tất cả đợt giải ngân hợp lệ',
        passed: milestones.isNotEmpty &&
            milestones.every((ms) => ms.validate().isEmpty),
      ),
      _CheckItem(
        label: 'Mục tiêu gây quỹ > 0',
        passed: _state.calculatedTargetAmount > 0,
      ),
      _CheckItem(
        label: 'Tài khoản ngân hàng đã nhập',
        passed: bank.validate().isEmpty,
      ),
      _CheckItem(
        label: 'Đã chấp nhận tất cả điều khoản',
        passed: ack.allAccepted,
      ),
    ];
  }

  bool get _allChecksPassed => _checklist.every((c) => c.passed);

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '—';
    final dt = DateTime.tryParse(dateStr);
    return dt != null ? DateFormat('dd/MM/yyyy').format(dt) : dateStr;
  }

  Future<void> _submit() async {
    if (!_allChecksPassed) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final payload = _state.toCreatePayload();
      final response = await _campaignService.createCampaign(payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _submitted = true;
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _submitError = 'Lỗi server: ${response.statusCode}';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _submitError = ErrorHandler.handle(e);
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_submitted) {
      return _buildSuccessView(theme);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Header ────────────────────────────────────────────────
        Text(
          'Xác nhận & Gửi duyệt',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kiểm tra lại thông tin trước khi gửi duyệt hồ sơ.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        // ── Validation Checklist ──────────────────────────────────
        _buildChecklistSection(theme),
        const SizedBox(height: 20),

        // ── Campaign Info Summary ─────────────────────────────────
        _buildInfoSection(theme),
        const SizedBox(height: 16),

        // ── Milestones Summary ────────────────────────────────────
        _buildMilestonesSummary(theme),
        const SizedBox(height: 16),

        // ── Bank Account Summary ──────────────────────────────────
        _buildBankSummary(theme),
        const SizedBox(height: 16),

        // ── Target Amount ─────────────────────────────────────────
        _buildTargetAmountCard(theme),
        const SizedBox(height: 16),

        // ── Terms Summary ─────────────────────────────────────────
        _buildTermsSummary(theme),
        const SizedBox(height: 24),

        // ── Error ─────────────────────────────────────────────────
        if (_submitError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _submitError!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Submit Button ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _allChecksPassed && !_isSubmitting ? _submit : null,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi duyệt hồ sơ'),
            style: FilledButton.styleFrom(
              backgroundColor: _allChecksPassed
                  ? Colors.green.shade600
                  : Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Section header với Edit button ──────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    int? editStepIndex,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _headerBlue,
            ),
          ),
        ),
        if (editStepIndex != null && widget.onGoToStep != null)
          TextButton.icon(
            onPressed: () => widget.onGoToStep!(editStepIndex),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Sửa'),
            style: TextButton.styleFrom(
              foregroundColor: _editOrange,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildChecklistSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              _allChecksPassed ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      color: _allChecksPassed ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _allChecksPassed ? Icons.check_circle : Icons.warning_amber,
                  color: _allChecksPassed
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _allChecksPassed ? 'Sẵn sàng gửi duyệt' : 'Cần hoàn tất',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _allChecksPassed
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._checklist.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        item.passed
                            ? Icons.check_circle
                            : Icons.cancel_outlined,
                        size: 18,
                        color: item.passed ? _checkGreen : _errorRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: item.passed
                                ? Colors.green.shade800
                                : Colors.red.shade700,
                            decoration: item.passed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(ThemeData theme) {
    final core = _state.campaignCore;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.info_outline,
              iconColor: Colors.blue.shade600,
              title: 'Thông tin chiến dịch',
              editStepIndex: 1, // Step 2: Campaign info
            ),
            const Divider(height: 20),
            _infoRow('Tên chiến dịch', core.title),
            _infoRow('Danh mục', core.category),
            _infoRow('Khu vực', core.region),
            _infoRow('Đối tượng thụ hưởng', core.beneficiaryType),
            _infoRow('Ngày bắt đầu', _formatDate(core.startDate)),
            _infoRow('Ngày kết thúc', _formatDate(core.endDate)),
            if (core.objective.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Mục tiêu:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                core.objective,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesSummary(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: Colors.orange.shade600,
              title: 'Đợt giải ngân (${_state.milestones.length})',
              editStepIndex: 2, // Step 3: Milestones
            ),
            const Divider(height: 20),
            ..._state.milestones.asMap().entries.map((entry) {
              final i = entry.key;
              final ms = entry.value;
              final amount = ms.calculatedAmount;
              final catCount = ms.categories.length;
              final itemCount = ms.categories.fold<int>(
                0,
                (sum, cat) => sum + cat.items.length,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.orange.shade100,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ms.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '$catCount danh mục · $itemCount hạng mục',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${_formatDate(ms.startDate)} → ${_formatDate(ms.endDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_currencyFormat.format(amount)} ₫',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Bank Account Summary section — hiển thị thông tin ngân hàng.
  Widget _buildBankSummary(ThemeData theme) {
    final bank = _state.bankInfo;
    final bankErrors = bank.validate();
    final isValid = bankErrors.isEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isValid ? Colors.grey.shade200 : _errorRed.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.account_balance_outlined,
              iconColor: Colors.teal.shade600,
              title: 'Tài khoản ngân hàng',
              editStepIndex: 0, // Step 1: KYC + Bank
            ),
            const Divider(height: 20),
            if (!isValid) ...[
              // Warning khi bank info thiếu
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _errorRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: _errorRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thông tin ngân hàng chưa đầy đủ. Vui lòng quay lại bổ sung.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _infoRow(
              'Ngân hàng',
              bank.bankName.isNotEmpty ? bank.bankName : bank.bankCode,
            ),
            _infoRow('Số tài khoản', bank.accountNumber),
            _infoRow('Tên chủ TK', bank.accountHolderName),
            _infoRow('Mã Casso', bank.webhookKey),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetAmountCard(ThemeData theme) {
    final total = _state.calculatedTargetAmount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade500, Colors.deepOrange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng mục tiêu gây quỹ',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${_currencyFormat.format(total)} ₫',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSummary(ThemeData theme) {
    final ack = _state.acknowledgements;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.gavel_outlined,
              iconColor: Colors.purple.shade600,
              title: 'Điều khoản',
              editStepIndex: 3, // Step 4: Terms
            ),
            const Divider(height: 20),
            _checkRow('Điều khoản sử dụng', ack.termsAccepted),
            _checkRow('Chính sách dư quỹ', ack.overfundPolicyAccepted),
            _checkRow('Cam kết minh bạch', ack.transparencyAccepted),
            _checkRow('Trách nhiệm pháp lý', ack.legalLiabilityAccepted),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gửi duyệt thành công!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hồ sơ chiến dịch của bạn đã được gửi để xem xét. '
              'Quá trình duyệt thường mất từ 1-3 ngày làm việc.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn sẽ nhận được thông báo khi hồ sơ được phê duyệt.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Về trang chủ'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).popAndPushNamed('/my-campaigns');
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Xem chiến dịch của tôi'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkRow(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: checked ? _checkGreen : _errorRed,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: checked ? Colors.green.shade800 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class cho validation checklist.
class _CheckItem {
  final String label;
  final bool passed;

  const _CheckItem({required this.label, required this.passed});
}
