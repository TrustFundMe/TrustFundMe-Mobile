import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/kyc_service.dart';
import '../../../core/models/new_campaign_state.dart';
import '../../../core/utils/error_handler.dart';

/// Step 1: KYC + Bank Account — chỉ cho phép tiếp tục khi KYC APPROVED
/// và thông tin ngân hàng hợp lệ.
class Step1Eligibility extends StatefulWidget {
  final NewCampaignState campaignState;
  final ValueChanged<bool> onValidChanged;

  const Step1Eligibility({
    super.key,
    required this.campaignState,
    required this.onValidChanged,
  });

  @override
  State<Step1Eligibility> createState() => _Step1EligibilityState();
}

class _Step1EligibilityState extends State<Step1Eligibility>
    with AutomaticKeepAliveClientMixin {
  final KycService _kycService = KycService();
  final _bankFormKey = GlobalKey<FormState>();

  // --- KYC state ---
  bool _isLoading = true;
  String? _error;
  String _kycStatus = 'NOT_SUBMITTED';
  String _kycFullName = '';
  String _kycRejectReason = '';

  // --- Bank form controllers ---
  late final TextEditingController _holderNameCtrl;
  late final TextEditingController _accountNumberCtrl;
  late final TextEditingController _webhookKeyCtrl;

  // --- Bank list from VietQR ---
  List<Map<String, dynamic>> _banks = [];
  bool _isBanksLoading = false;
  Map<String, dynamic>? _selectedBank;

  // --- Warnings ---
  bool _showNameMismatch = false;

  // --- Colors (matching web) ---
  static const _darkBlue = Color(0xFF1E3A5F);
  static const _gray700 = Color(0xFF374151);
  static const _gray300 = Color(0xFFD1D5DB);
  static const _orange = Color(0xFFEA580C);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final bank = widget.campaignState.bankInfo;
    _holderNameCtrl = TextEditingController(text: bank.accountHolderName);
    _accountNumberCtrl = TextEditingController(text: bank.accountNumber);
    _webhookKeyCtrl = TextEditingController(text: bank.webhookKey);

    _holderNameCtrl.addListener(_onBankFieldChanged);
    _accountNumberCtrl.addListener(_onBankFieldChanged);
    _webhookKeyCtrl.addListener(_onBankFieldChanged);

    _loadKycStatus();
    _fetchBanks();
  }

  @override
  void dispose() {
    _holderNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _webhookKeyCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────── KYC ────────────────────────

  Future<void> _loadKycStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _kycService.getMyKyc();
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};

        _kycStatus = data['status'] as String? ?? 'NOT_SUBMITTED';
        _kycFullName = data['fullName'] as String? ?? '';
        _kycRejectReason = data['rejectReason'] as String? ?? '';

        widget.campaignState.kycStatus = _kycStatus;
        widget.campaignState.kycFullName = _kycFullName;
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
      _kycStatus = 'NOT_SUBMITTED';
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _checkNameMismatch();
      _emitValidity();
    }
  }

  // ──────────────────────── Banks ────────────────────────

  Future<void> _fetchBanks() async {
    setState(() => _isBanksLoading = true);
    try {
      final dio = Dio();
      final resp = await dio.get<Map<String, dynamic>>(
        'https://api.vietqr.io/v2/banks',
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final list = (resp.data!['data'] as List<dynamic>?) ?? [];
        _banks = list.cast<Map<String, dynamic>>();

        // Restore selection from state if available
        if (widget.campaignState.bankInfo.bankCode.isNotEmpty) {
          _selectedBank = _banks.firstWhere(
            (b) =>
                b['code'] == widget.campaignState.bankInfo.bankCode,
            orElse: () => <String, dynamic>{},
          );
          if (_selectedBank != null && _selectedBank!.isEmpty) {
            _selectedBank = null;
          }
        }
      }
    } catch (_) {
      // Silently fail — user can retry
    }
    if (mounted) setState(() => _isBanksLoading = false);
  }

  // ──────────────────────── Validation helpers ────────────────────────

  void _onBankFieldChanged() {
    _syncBankToState();
    _checkNameMismatch();
    _emitValidity();
  }

  void _syncBankToState() {
    final bank = widget.campaignState.bankInfo;
    bank.accountHolderName = _holderNameCtrl.text;
    bank.accountNumber = _accountNumberCtrl.text;
    bank.webhookKey = _webhookKeyCtrl.text;
  }

  void _checkNameMismatch() {
    if (_kycFullName.isEmpty || _holderNameCtrl.text.isEmpty) {
      if (_showNameMismatch) setState(() => _showNameMismatch = false);
      return;
    }
    final kycNorm = _normalize(_kycFullName);
    final holderNorm = _normalize(_holderNameCtrl.text);
    final mismatch = kycNorm != holderNorm;
    if (mismatch != _showNameMismatch) {
      setState(() => _showNameMismatch = mismatch);
    }
  }

  String _normalize(String s) =>
      s.toUpperCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  void _emitValidity() {
    final kycOk = _kycStatus == 'APPROVED';
    final bankErrors = widget.campaignState.bankInfo.validate();
    widget.onValidChanged(kycOk && bankErrors.isEmpty);
  }

  // ──────────────────────── Build ────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang kiểm tra hồ sơ xác minh...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKycStatus,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── KYC Section ───
          Icon(
            _kycStatus == 'APPROVED'
                ? Icons.verified_user
                : Icons.shield_outlined,
            size: 64,
            color: _kycStatus == 'APPROVED'
                ? Colors.green.shade600
                : Colors.orange.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Xác minh danh tính (KYC)',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Để đảm bảo an toàn cho nhà tài trợ, bạn cần xác minh danh tính trước khi tạo chiến dịch gây quỹ.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Status Card
          _buildStatusCard(theme),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ─── Bank Account Section (chỉ hiện khi KYC APPROVED) ───
          if (_kycStatus == 'APPROVED') ...[
            const SizedBox(height: 40),
            _buildBankSection(theme),
          ],
        ],
      ),
    );
  }

  // ──────────────────────── KYC Status Cards ────────────────────────

  Widget _buildStatusCard(ThemeData theme) {
    switch (_kycStatus) {
      case 'APPROVED':
        return _buildApprovedCard(theme);
      case 'PENDING':
        return _buildPendingCard(theme);
      case 'REJECTED':
        return _buildRejectedCard(theme);
      default:
        return _buildNotSubmittedCard(theme);
    }
  }

  Widget _buildApprovedCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade700, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Đã xác minh ✓',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Danh tính của bạn đã được xác minh thành công.',
              style: TextStyle(color: Colors.green.shade700),
              textAlign: TextAlign.center,
            ),
            if (_kycFullName.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      _kycFullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top,
                  color: Colors.amber.shade700, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Đang chờ duyệt',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.amber.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hồ sơ KYC của bạn đang được xem xét. Quá trình này thường mất từ 1-3 ngày làm việc.',
              style: TextStyle(color: Colors.amber.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadKycStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.cancel, color: Colors.red.shade700, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Hồ sơ bị từ chối',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hồ sơ KYC của bạn đã bị từ chối. Vui lòng cập nhật và gửi lại.',
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            if (_kycRejectReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lý do từ chối:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kycRejectReason,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/kyc'),
              icon: const Icon(Icons.edit),
              label: const Text('Cập nhật KYC'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotSubmittedCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add,
                  color: Colors.blue.shade700, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa xác minh danh tính',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn cần hoàn tất xác minh danh tính (KYC) trước khi tạo chiến dịch gây quỹ.',
              style: TextStyle(color: Colors.blue.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).pushNamed('/kyc');
                _loadKycStatus();
              },
              icon: const Icon(Icons.verified_user),
              label: const Text('Xác minh ngay'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── Bank Account Section ────────────────────────

  Widget _buildBankSection(ThemeData theme) {
    return Form(
      key: _bankFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(Icons.account_balance, color: _darkBlue, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tài khoản ngân hàng nhận giải ngân',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _darkBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vui lòng cung cấp thông tin tài khoản ngân hàng để nhận tiền giải ngân từ chiến dịch.',
            style: theme.textTheme.bodyMedium?.copyWith(color: _gray700),
          ),
          const SizedBox(height: 24),

          // ── Tên chủ tài khoản ──
          _buildLabel('Tên chủ tài khoản', required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _holderNameCtrl,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [UpperCaseTextFormatter()],
            decoration: _inputDecoration(
              hint: 'VD: NGUYEN VAN A',
              prefixIcon: Icons.person_outline,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Tên chủ tài khoản không được để trống';
              }
              if (v.trim().length < 6) return 'Tối thiểu 6 ký tự';
              if (v.trim().length > 255) return 'Tối đa 255 ký tự';
              return null;
            },
            onChanged: (_) => _bankFormKey.currentState?.validate(),
          ),

          // Name mismatch warning
          if (_showNameMismatch) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // amber-100
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _amber),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tên chủ tài khoản khác với tên KYC ($_kycFullName). '
                      'Vui lòng kiểm tra lại để tránh lỗi giải ngân.',
                      style: const TextStyle(
                        color: Color(0xFF92400E), // amber-800
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Số tài khoản ──
          _buildLabel('Số tài khoản', required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _accountNumberCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(
              hint: 'VD: 0123456789',
              prefixIcon: Icons.credit_card,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Số tài khoản không được để trống';
              }
              if (v.trim().length < 6) return 'Tối thiểu 6 ký tự';
              if (v.trim().length > 50) return 'Tối đa 50 ký tự';
              return null;
            },
            onChanged: (_) => _bankFormKey.currentState?.validate(),
          ),
          const SizedBox(height: 20),

          // ── Chọn ngân hàng ──
          _buildLabel('Ngân hàng', required: true),
          const SizedBox(height: 6),
          _buildBankSelector(theme),
          const SizedBox(height: 20),

          // ── Mã kết nối Casso ──
          _buildLabel('Mã kết nối Casso (Webhook Secret Key)',
              required: true),
          const SizedBox(height: 6),
          TextFormField(
            controller: _webhookKeyCtrl,
            decoration: _inputDecoration(
              hint: 'Nhập Secret Key từ Casso',
              prefixIcon: Icons.vpn_key_outlined,
              suffixIcon: IconButton(
                icon: const Icon(Icons.help_outline, color: _orange),
                onPressed: _showCassoGuide,
                tooltip: 'Hướng dẫn lấy mã Casso',
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Mã kết nối Casso không được để trống';
              }
              return null;
            },
            onChanged: (_) => _bankFormKey.currentState?.validate(),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCassoGuide,
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _orange),
                SizedBox(width: 4),
                Text(
                  'Hướng dẫn lấy mã kết nối Casso',
                  style: TextStyle(
                    color: _orange,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ──────────────────────── Bank Selector ────────────────────────

  Widget _buildBankSelector(ThemeData theme) {
    if (_isBanksLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: _gray300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showBankPicker(theme),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedBank != null ? _orange : _gray300,
            width: _selectedBank != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (_selectedBank != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _selectedBank!['logo'] as String? ?? '',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.account_balance,
                    size: 32,
                    color: _gray700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBank!['shortName'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _gray700,
                      ),
                    ),
                    Text(
                      _selectedBank!['name'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Icon(Icons.account_balance_outlined,
                  color: _gray700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chọn ngân hàng',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
            const Icon(Icons.arrow_drop_down, color: _gray700),
          ],
        ),
      ),
    );
  }

  void _showBankPicker(ThemeData theme) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final query = searchCtrl.text.toLowerCase();
            final filtered = query.isEmpty
                ? _banks
                : _banks.where((b) {
                    final name =
                        (b['name'] as String? ?? '').toLowerCase();
                    final shortName =
                        (b['shortName'] as String? ?? '').toLowerCase();
                    final code =
                        (b['code'] as String? ?? '').toLowerCase();
                    return name.contains(query) ||
                        shortName.contains(query) ||
                        code.contains(query);
                  }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Chọn ngân hàng',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _darkBlue,
                        ),
                      ),
                    ),
                    // Search
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Tìm ngân hàng...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _gray300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _orange, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy ngân hàng',
                                style: TextStyle(
                                    color: Colors.grey.shade500),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final bank = filtered[i];
                                final isSelected = _selectedBank != null &&
                                    _selectedBank!['code'] ==
                                        bank['code'];
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor:
                                      _orange.withOpacity(0.08),
                                  leading: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: Image.network(
                                      bank['logo'] as String? ?? '',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(
                                              Icons.account_balance,
                                              size: 40),
                                    ),
                                  ),
                                  title: Text(
                                    bank['shortName'] as String? ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? _orange
                                          : _gray700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    bank['name'] as String? ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: _orange)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedBank = bank;
                                      widget.campaignState.bankInfo
                                              .bankCode =
                                          bank['code'] as String? ?? '';
                                      widget.campaignState.bankInfo
                                              .bankName =
                                          bank['shortName'] as String? ??
                                              '';
                                    });
                                    _emitValidity();
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ──────────────────────── Casso Guide Modal ────────────────────────

  void _showCassoGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: _orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hướng dẫn lấy mã Casso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideStep('1', 'Truy cập trang web casso.vn và đăng ký tài khoản.'),
            const SizedBox(height: 12),
            _buildGuideStep('2', 'Liên kết tài khoản ngân hàng của bạn với Casso.'),
            const SizedBox(height: 12),
            _buildGuideStep('3', 'Vào mục "Webhook" → Tạo webhook mới.'),
            const SizedBox(height: 12),
            _buildGuideStep('4', 'Sao chép "Secret Key" (Secure Token) và dán vào ô bên trên.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED), // orange-50
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _orange.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Casso giúp hệ thống tự động xác nhận các giao dịch chuyển khoản '
                      'vào tài khoản ngân hàng của chiến dịch.',
                      style: TextStyle(fontSize: 13, color: _gray700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu', style: TextStyle(color: _orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: _orange,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: _gray700)),
        ),
      ],
    );
  }

  // ──────────────────────── Shared UI helpers ────────────────────────

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _gray700,
          ),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: _red, fontSize: 14)),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: _gray700, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gray300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
    );
  }
}

// ──────────────────────── Input Formatter ────────────────────────

/// Tự động chuyển text thành UPPERCASE khi gõ.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
