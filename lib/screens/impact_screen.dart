import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/providers/auth_provider.dart';
import 'campaign_detail_screen.dart';
import 'donation_screen.dart';

class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  static const Color _bg = Color(0xFFF9FAFB);
  static const Color _text = Color(0xFF1F2937);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _cardBorder = Color(0xFFE5E7EB);
  /// Dùng pattern số không phụ thuộc `initializeDateFormatting` (tránh LocaleDataException).
  final NumberFormat _moneyFmt = NumberFormat('#,###', 'en_US');
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final int? uid = auth.user?.id;
    if (!auth.isLoggedIn || uid == null) {
      if (!mounted) return;
      setState(() {
        _rows = <Map<String, dynamic>>[];
        _loadError = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loadError = null;
    });
    try {
      final response = await _api.getMyDonations(limit: 50);
      final dynamic data = response.data;
      final List<Map<String, dynamic>> parsed = <Map<String, dynamic>>[];
      if (data is List<dynamic>) {
        for (final dynamic e in data) {
          if (e is Map<String, dynamic>) {
            parsed.add(e);
          }
        }
      }
      parsed.removeWhere((Map<String, dynamic> e) {
        final dynamic status = e['status'];
        final bool isPaid = status == null || status.toString().toUpperCase() == 'PAID';
        final int rowUid = (e['donorId'] as num?)?.toInt() ?? -1;
        return rowUid != uid || !isPaid;
      });
      parsed.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _rows = parsed;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = <Map<String, dynamic>>[];
        _loadError = 'Không tải được lịch sử. Kiểm tra kết nối và thử lại.';
        _loading = false;
      });
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _statusLabel(Map<String, dynamic> row) {
    final dynamic statusRaw = row['status'];
    final String status = statusRaw?.toString().trim().toUpperCase() ?? '';
    if (status.isEmpty) return 'Đã thanh toán';
    if (status == 'PAID') return 'Đã thanh toán';
    return status;
  }

  Future<void> _openDonationDetails(Map<String, dynamic> row) async {
    if (!mounted) return;
    final int campaignId = _toInt(row['campaignId']);
    final String campaignTitle =
        (row['campaignTitle'] as String?)?.trim().isNotEmpty == true
            ? (row['campaignTitle'] as String).trim()
            : 'Chiến dịch #$campaignId';
    final int donationId = _toInt(row['donationId'] ?? row['id'] ?? row['paymentId']);
    final int totalAmount = _toInt(row['totalAmount']);
    final DateTime? at =
        DateTime.tryParse(row['createdAt']?.toString() ?? '');
    final String timeLabel =
        at == null ? '' : DateFormat('HH:mm dd/MM/yyyy').format(at);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext c) {
        return _DonationDetailSheet(
          campaignId: campaignId,
          campaignTitle: campaignTitle,
          donationId: donationId > 0 ? donationId : null,
          totalAmount: totalAmount,
          timeLabel: timeLabel,
          statusLabel: _statusLabel(row),
          onViewCampaign: () {
            Navigator.of(c).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CampaignDetailScreen(
                  campaign: CampaignModel(
                    id: campaignId,
                    title: campaignTitle,
                  ),
                ),
              ),
            );
          },
          onDonateAgain: () {
            Navigator.of(c).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DonationScreen(
                  campaign: CampaignModel(
                    id: campaignId,
                    title: campaignTitle,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = _rows.fold<int>(0, (int s, Map<String, dynamic> e) => s + _toInt(e['totalAmount']));
    final Set<int> campaignIds = _rows
        .map((Map<String, dynamic> e) => _toInt(e['campaignId']))
        .where((int e) => e > 0)
        .toSet();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Tác động của bạn', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _text,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: <Widget>[
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _loadError!,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _SummaryCard(
                    totalAmountLabel: '${_moneyFmt.format(total)} đ',
                    campaignCount: campaignIds.length,
                    donationCount: _rows.length,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Lịch sử ủng hộ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Chưa có khoản ủng hộ nào được ghi nhận.',
                                style: TextStyle(color: _muted),
                              ),
                            ),
                          )
                        else
                          ..._rows.map((Map<String, dynamic> e) {
                            final int campaignId = _toInt(e['campaignId']);
                            final String campaignTitle =
                                (e['campaignTitle'] as String?)?.trim().isNotEmpty == true
                                    ? (e['campaignTitle'] as String).trim()
                                    : 'Chiến dịch #$campaignId';
                            final int totalAmount = _toInt(e['totalAmount']);
                            final DateTime? at =
                                DateTime.tryParse(e['createdAt']?.toString() ?? '');
                            final String timeLabel =
                                at == null ? '' : DateFormat('HH:mm dd/MM/yyyy').format(at);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DonationHistoryTile(
                                campaignTitle: campaignTitle,
                                timeLabel: timeLabel,
                                totalAmount: totalAmount,
                                onTap: () => _openDonationDetails(e),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalAmountLabel,
    required this.campaignCount,
    required this.donationCount,
  });

  final String totalAmountLabel;
  final int campaignCount;
  final int donationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatTile(
              label: 'Tổng đã ủng hộ',
              value: totalAmountLabel,
            ),
          ),
          Expanded(
            child: _StatTile(
              label: 'Chiến dịch',
              value: '$campaignCount',
            ),
          ),
          Expanded(
            child: _StatTile(
              label: 'Lượt ủng hộ',
              value: '$donationCount',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _DonationHistoryTile extends StatelessWidget {
  const _DonationHistoryTile({
    required this.campaignTitle,
    required this.timeLabel,
    required this.totalAmount,
    required this.onTap,
  });

  final String campaignTitle;
  final String timeLabel;
  final int totalAmount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color text = Color(0xFF1F2937);
    const Color muted = Color(0xFF6B7280);
    const Color primary = Color(0xFFF84D43);
    const Color rowBorder = Color(0xFFF1F5F9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rowBorder),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_outline, color: primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      campaignTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Text(
                '${NumberFormat('#,###', 'en_US').format(totalAmount)} đ',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonationDetailSheet extends StatelessWidget {
  const _DonationDetailSheet({
    required this.campaignId,
    required this.campaignTitle,
    required this.totalAmount,
    required this.timeLabel,
    required this.statusLabel,
    required this.onViewCampaign,
    required this.onDonateAgain,
    this.donationId,
  });

  final int campaignId;
  final String campaignTitle;
  final int totalAmount;
  final String timeLabel;
  final String statusLabel;
  final int? donationId;
  final VoidCallback onViewCampaign;
  final VoidCallback onDonateAgain;

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFF9FAFB);
    const Color text = Color(0xFF1F2937);
    const Color muted = Color(0xFF6B7280);
    const Color primary = Color(0xFFF84D43);
    const Color border = Color(0xFFE5E7EB);

    final NumberFormat moneyFmt = NumberFormat('#,###', 'en_US');

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0ED),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_outline, color: primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    campaignTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: text,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${moneyFmt.format(totalAmount)} đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: primary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trạng thái: $statusLabel',
                    style: const TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  if (timeLabel.isNotEmpty)
                    Text(
                      'Thời gian: $timeLabel',
                      style: const TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  if (donationId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Mã giao dịch: $donationId',
                        style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onViewCampaign,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Xem chiến dịch',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDonateAgain,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: border),
                      foregroundColor: text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ủng hộ lại',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
