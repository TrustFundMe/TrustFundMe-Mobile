import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/donation_service.dart';

/// Màn hình "Lịch sử quyên góp" — hiển thị các khoản donation đã thực hiện.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  final DonationService _donationService = DonationService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _donations = [];
  String? _error;

  static const Color _primary = Color(0xFFF84D43);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _textGray = Color(0xFF4B5563);
  static const Color _bgGray = Color(0xFFF9FAFB);
  static const Color _border = Color(0xFFE5E7EB);

  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchDonations();
  }

  Future<void> _fetchDonations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _donationService.getMyDonations(limit: 100);
      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (!mounted) return;
        setState(() => _donations = list);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không thể tải lịch sử quyên góp.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
        return const Color(0xFF059669);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'CANCELLED':
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
        return 'Thành công';
      case 'PENDING':
        return 'Đang chờ';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'FAILED':
        return 'Thất bại';
      default:
        return status ?? '—';
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    if (raw is String) {
      final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (dt != null) return _dateFmt.format(dt);
    }
    if (raw is List && raw.length >= 3) {
      try {
        final dt = DateTime(
          raw[0] as int,
          raw[1] as int,
          raw[2] as int,
          raw.length > 3 ? raw[3] as int : 0,
          raw.length > 4 ? raw[4] as int : 0,
        );
        return _dateFmt.format(dt);
      } catch (_) {}
    }
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text('Lịch sử quyên góp',
            style: TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: _textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _fetchDonations,
                  child: _donations.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _donations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _buildDonationCard(_donations[i]),
                        ),
                ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.history, size: 64, color: _primary),
            ),
            const SizedBox(height: 16),
            const Text('Chưa có quyên góp nào',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            const SizedBox(height: 8),
            const Text(
              'Các khoản quyên góp của bạn sẽ hiển thị ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGray, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchDonations,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationCard(Map<String, dynamic> donation) {
    final String campaignTitle =
        donation['campaignTitle'] ?? donation['description'] ?? 'Chiến dịch';
    final double amount =
        (donation['donationAmount'] ?? donation['amount'] ?? 0).toDouble();
    final String status = donation['status'] ?? 'PENDING';
    final dynamic createdAt = donation['createdAt'];
    final Color color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.volunteer_activism, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campaignTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _textDark)),
                    const SizedBox(height: 2),
                    Text(_formatDate(createdAt),
                        style:
                            const TextStyle(fontSize: 12, color: _textGray)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currencyFmt.format(amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _primary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_statusLabel(status),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
