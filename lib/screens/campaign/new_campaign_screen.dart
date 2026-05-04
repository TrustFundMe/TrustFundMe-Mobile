import 'package:flutter/material.dart';
import '../../core/models/new_campaign_state.dart';
import 'steps/step1_eligibility.dart';
import 'steps/step2_campaign_form.dart';
import 'steps/step3_milestones.dart';
import 'steps/step4_terms.dart';
import 'steps/step5_review.dart';

/// Màn hình container quản lý luồng tạo chiến dịch mới 5 bước.
///
/// Sử dụng [PageView] + stepper indicator ở trên,
/// nút "Quay lại" / "Tiếp tục" ở dưới.
class NewCampaignScreen extends StatefulWidget {
  const NewCampaignScreen({super.key});

  @override
  State<NewCampaignScreen> createState() => _NewCampaignScreenState();
}

class _NewCampaignScreenState extends State<NewCampaignScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  /// State chung cho toàn bộ luồng.
  final NewCampaignState _campaignState = NewCampaignState();

  /// Mỗi step có thể set callback này để validate trước khi next.
  bool _canProceed = false;

  /// Step labels cho stepper.
  static const List<String> _stepLabels = [
    'Xác minh',
    'Thông tin',
    'Giải ngân',
    'Điều khoản',
    'Xác nhận',
  ];

  static const List<IconData> _stepIcons = [
    Icons.verified_user_outlined,
    Icons.edit_note_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.gavel_outlined,
    Icons.check_circle_outline,
  ];

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep = step;
      _canProceed = false; // Reset, mỗi step phải re-validate
    });
  }

  void _onNext() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _setCanProceed(bool value) {
    if (_canProceed != value) {
      setState(() => _canProceed = value);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo chiến dịch mới'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context),
        ),
      ),
      body: Column(
        children: [
          // ── Stepper Indicator ──────────────────────────────────────
          _buildStepperIndicator(theme),

          // ── Page Content ───────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                  _canProceed = false;
                });
              },
              children: [
                Step1Eligibility(
                  campaignState: _campaignState,
                  onValidChanged: _setCanProceed,
                ),
                Step2CampaignForm(
                  campaignState: _campaignState,
                  onValidChanged: _setCanProceed,
                ),
                Step3Milestones(
                  campaignState: _campaignState,
                  onValidChanged: _setCanProceed,
                ),
                Step4Terms(
                  campaignState: _campaignState,
                  onValidChanged: _setCanProceed,
                ),
                Step5Review(
                  campaignState: _campaignState,
                  onValidChanged: _setCanProceed,
                ),
              ],
            ),
          ),

          // ── Bottom Navigation ──────────────────────────────────────
          _buildBottomNav(theme),
        ],
      ),
    );
  }

  Widget _buildStepperIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted
                          ? Colors.orange.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                GestureDetector(
                  onTap: isCompleted ? () => _goToStep(index) : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green.shade600
                              : isCurrent
                                  ? Colors.orange.shade600
                                  : Colors.grey.shade300,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : Icon(
                                  _stepIcons[index],
                                  color: isCurrent ? Colors.white : Colors.grey.shade600,
                                  size: 18,
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stepLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? Colors.orange.shade700
                              : isCompleted
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Nút Quay lại
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onBack,
                icon: const Icon(Icons.arrow_back),
                label: Text(_currentStep == 0 ? 'Hủy' : 'Quay lại'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Nút Tiếp tục / Gửi
            if (!isLastStep)
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _canProceed ? _onNext : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Tiếp tục'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy tạo chiến dịch?'),
        content: const Text(
          'Mọi thông tin bạn đã nhập sẽ bị mất. Bạn có chắc muốn thoát?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tiếp tục nhập'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}
