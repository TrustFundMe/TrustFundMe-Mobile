import 'package:flutter/material.dart';
import '../../../core/api/kyc_service.dart';
import '../../../core/models/new_campaign_state.dart';
import '../../../core/utils/error_handler.dart';

/// Step 1: Kiểm tra KYC — chỉ cho phép tạo chiến dịch khi KYC đã APPROVED.
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

  bool _isLoading = true;
  String? _error;
  String _kycStatus = 'NOT_SUBMITTED';
  String _kycFullName = '';
  String _kycRejectReason = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

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
      // Nếu 404 → chưa submit KYC
      _kycStatus = 'NOT_SUBMITTED';
    }

    if (mounted) {
      setState(() => _isLoading = false);
      widget.onValidChanged(_kycStatus == 'APPROVED');
    }
  }

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
          // Header
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
        ],
      ),
    );
  }

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
              child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 40),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            const SizedBox(height: 16),
            Text(
              'Bạn có thể tiếp tục tạo chiến dịch. Nhấn "Tiếp tục" để sang bước tiếp theo.',
              style: TextStyle(color: Colors.green.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
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
              child: Icon(Icons.hourglass_top, color: Colors.amber.shade700, size: 40),
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
              child: Icon(Icons.cancel, color: Colors.red.shade700, size: 40),
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
              child: Icon(Icons.person_add, color: Colors.blue.shade700, size: 40),
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
                // Reload khi quay lại từ KYC
                _loadKycStatus();
              },
              icon: const Icon(Icons.verified_user),
              label: const Text('Xác minh ngay'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
