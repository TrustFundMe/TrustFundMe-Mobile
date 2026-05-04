import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api/donation_service.dart';
import '../donation_success_screen.dart';

/// Màn hình VietQR — hiển thị mã QR để user quét thanh toán.
///
/// Flow:
/// 1. Hiển thị QR image từ [qrUrl]
/// 2. Countdown 10 phút
/// 3. Auto-poll status mỗi 5s
/// 4. Khi PAID → navigate success
class VietQRScreen extends StatefulWidget {
  const VietQRScreen({
    super.key,
    required this.qrUrl,
    required this.donationId,
    required this.orderCode,
    required this.amount,
    required this.campaignTitle,
  });

  final String qrUrl;
  final int donationId;
  final String? orderCode;
  final int amount;
  final String campaignTitle;

  @override
  State<VietQRScreen> createState() => _VietQRScreenState();
}

class _VietQRScreenState extends State<VietQRScreen>
    with SingleTickerProviderStateMixin {
  static const int _timeoutSeconds = 600; // 10 phút

  final DonationService _donation = DonationService();
  final NumberFormat _fmt = NumberFormat.decimalPattern('vi_VN');

  int _secondsLeft = _timeoutSeconds;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _verified = false;
  bool _manualChecking = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        _onTimeout();
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _verified) return;
      await _checkStatus(silent: true);
    });
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_verified) return;
    if (!silent && mounted) setState(() => _manualChecking = true);

    try {
      final res = await _donation.getDonation(widget.donationId);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final String status = (data['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID') {
          _verified = true;
          _countdownTimer?.cancel();
          _pollTimer?.cancel();
          // Verify + sync
          try {
            await _donation.verifyDonationPayment(widget.donationId);
          } catch (_) {}
          try {
            await _donation.syncDonationQuantity(widget.donationId);
          } catch (_) {}
          try {
            await _donation.syncDonationBalance(widget.donationId);
          } catch (_) {}
          if (!mounted) return;
          HapticFeedback.heavyImpact();
          _goToSuccess();
          return;
        }
      }
    } catch (_) {
      // ignore poll errors
    }

    if (!silent && mounted) {
      setState(() => _manualChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa nhận được thanh toán. Vui lòng thử lại.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onTimeout() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hết thời gian',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Thời gian thanh toán đã hết. Giao dịch sẽ bị huỷ.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _goToSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => DonationSuccessScreen(
          campaignTitle: widget.campaignTitle,
          totalAmount: widget.amount,
        ),
      ),
    );
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Huỷ giao dịch?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Bạn có chắc muốn huỷ giao dịch này? Nếu đã chuyển khoản, hãy bấm "Đã chuyển khoản" thay vì huỷ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tiếp tục'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _donation.cancelDonation(widget.donationId);
              } catch (_) {}
              if (mounted) Navigator.of(context).pop(false);
            },
            child: const Text('Huỷ giao dịch',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String get _timeDisplay {
    final int m = _secondsLeft ~/ 60;
    final int s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _isUrgent => _secondsLeft <= 60;

  @override
  Widget build(BuildContext context) {
    const Color brand = Color(0xFFFF5E14);
    const Color dark = Color(0xFF0F172A);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleCancel();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: dark,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Thanh toán VietQR',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleCancel,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Dark info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                color: dark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: brand.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield, color: brand, size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Thanh toán bảo mật',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Mã quyên góp
                    Text(
                      'MÃ QUYÊN GÓP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        final content = 'TF ${widget.orderCode ?? widget.donationId}';
                        Clipboard.setData(ClipboardData(text: content));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            'TF ${widget.orderCode ?? widget.donationId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy,
                              color: Colors.white.withOpacity(0.5), size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Số tiền
                    Text(
                      'SỐ TIỀN',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt.format(widget.amount)} ₫',
                      style: const TextStyle(
                        color: brand,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isUrgent
                            ? Colors.red.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isUrgent
                              ? Colors.red.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _secondsLeft > 0
                                ? Icons.timer_outlined
                                : Icons.close,
                            color: _isUrgent ? Colors.red : brand,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _secondsLeft > 0
                                    ? _timeDisplay
                                    : 'Hết thời gian',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: _isUrgent
                                      ? Colors.red
                                      : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _secondsLeft > 0
                                    ? 'Thời gian còn lại'
                                    : 'Giao dịch đã bị huỷ',
                                style: TextStyle(
                                  color: _isUrgent
                                      ? Colors.red.withOpacity(0.7)
                                      : Colors.white.withOpacity(0.4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // QR Code area
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Quét mã VietQR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nội dung và số tiền đã tự động điền',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // QR with decorative corners
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.qrUrl,
                                width: 240,
                                height: 240,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox(
                                    width: 240,
                                    height: 240,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.broken_image,
                                            size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('Không tải được QR',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Steps
                        _buildStep(1, 'Mở ứng dụng ngân hàng → "Quét QR"'),
                        _buildStep(2, 'Quét mã QR ở trên để thanh toán'),
                        _buildStep(3, 'Hệ thống tự xác nhận sau khi chuyển',
                            highlight: true),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom actions
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _manualChecking
                              ? null
                              : () => _checkStatus(silent: false),
                          icon: _manualChecking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            _manualChecking
                                ? 'Đang kiểm tra...'
                                : 'Đã chuyển khoản',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: brand,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _handleCancel,
                        child: Text(
                          'Huỷ giao dịch',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text, {bool highlight = false}) {
    const Color brand = Color(0xFFFF5E14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlight
                  ? brand.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: highlight ? brand : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: highlight ? brand : Colors.grey.shade600,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
