import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/expenditure_item_model.dart';
import '../core/models/payment_models.dart';
import '../core/providers/auth_provider.dart';
import 'donation_success_screen.dart';
import 'donation_terms_screen.dart';
import 'donation_webview_screen.dart';

class DonationScreen extends StatefulWidget {
  final CampaignModel campaign;

  const DonationScreen({
    super.key,
    required this.campaign,
  });

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final ApiService _api = ApiService();
  final NumberFormat _fmt = NumberFormat.decimalPattern('vi_VN');
  static const List<int> _presetAmounts = <int>[20000, 50000, 100000, 200000];

  bool _loading = true;
  bool _submitting = false;
  bool _isAnonymous = false;
  bool _isAgreed = false;
  bool _isAmountMode = true;
  bool _donationBlocked = false;
  String _blockedMessage = '';

  List<ExpenditureItemModel> _items = <ExpenditureItemModel>[];
  final Map<int, int> _selectedQuantities = <int, int>{};
  int _manualAmount = 0;

  int _tipPercent = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final bool isItemized =
          (widget.campaign.type ?? '').toUpperCase() == 'ITEMIZED';

      List<dynamic> data = <dynamic>[];
      if (isItemized) {
        // Match web behavior: itemized donation only uses APPROVED items.
        final approvedResponse =
            await _api.getApprovedExpenditureItemsByCampaign(widget.campaign.id);
        data = approvedResponse.data as List<dynamic>;
      } else {
        // General donation can still render even without approved expenditure items.
        final response =
            await _api.getExpenditureItemsByCampaign(widget.campaign.id);
        data = response.data as List<dynamic>;
      }

      _items = data
          .map(
            (dynamic e) =>
                ExpenditureItemModel.fromJson(e as Map<String, dynamic>),
          )
          .where((ExpenditureItemModel e) => e.quantityLeft > 0)
          .toList();

      if (isItemized && _items.isEmpty) {
        _donationBlocked = true;
        _blockedMessage =
            'Chiến dịch đang trong quá trình giải ngân, chưa thể nhận quyên góp.';
      } else {
        _donationBlocked = false;
        _blockedMessage = '';
      }
    } catch (_) {
      _items = <ExpenditureItemModel>[];
      final bool isItemized =
          (widget.campaign.type ?? '').toUpperCase() == 'ITEMIZED';
      if (isItemized) {
        _donationBlocked = true;
        _blockedMessage =
            'Chiến dịch đang trong quá trình giải ngân, chưa thể nhận quyên góp.';
      } else {
        _donationBlocked = false;
        _blockedMessage = '';
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int get _donationAmount {
    if (_selectedQuantities.isEmpty) {
      return _manualAmount;
    }

    int total = 0;
    _selectedQuantities.forEach((int id, int qty) {
      final ExpenditureItemModel item =
          _items.firstWhere((ExpenditureItemModel e) => e.id == id,
              orElse: () => ExpenditureItemModel(
                    id: id,
                    category: '',
                    quantityLeft: 0,
                    expectedPrice: 0,
                  ));
      total += item.expectedPrice * qty;
    });
    return total;
  }

  int get _tipAmount =>
      (_donationAmount * _tipPercent / 100).round();

  void _setManualAmount(int value) {
    setState(() {
      _manualAmount = value < 0 ? 0 : value;
      if (_manualAmount > 0) {
        _isAmountMode = true;
        _selectedQuantities.clear();
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_donationBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _blockedMessage.isNotEmpty
                ? _blockedMessage
                : 'Chiến dịch chưa thể nhận quyên góp.',
          ),
        ),
      );
      return;
    }

    if (_donationAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hoặc chọn hạng mục để quyên góp'),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      final int? donorId = auth.user?.id;

      final List<DonationItemRequest> itemsPayload =
          _selectedQuantities.entries.map((MapEntry<int, int> entry) {
        final ExpenditureItemModel item = _items
            .firstWhere((ExpenditureItemModel e) => e.id == entry.key);
        return DonationItemRequest(
          expenditureItemId: item.id,
          quantity: entry.value,
          amount: item.expectedPrice,
        );
      }).toList();

      // Pre-check limit giống FE-web
      if (!_isAmountMode) {
        for (final DonationItemRequest item in itemsPayload) {
          final response = await _api.checkExpenditureItemLimit(
            item.expenditureItemId,
            item.quantity,
          );
          final Map<String, dynamic> data =
              response.data as Map<String, dynamic>;
          final bool canDonateMore = data['canDonateMore'] as bool? ?? true;
          if (!canDonateMore) {
            final String message =
                (data['message'] ?? 'Số lượng vượt quá giới hạn') as String;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
            setState(() {
              _submitting = false;
            });
            return;
          }
        }
      }

      final String userIdStr = donorId?.toString() ?? 'GUEST';
      final String description =
          'USER${userIdStr}CAMPAIGN${widget.campaign.id}';

      final CreatePaymentRequestModel payload =
          CreatePaymentRequestModel(
        donorId: donorId,
        campaignId: widget.campaign.id,
        donationAmount: _donationAmount,
        tipAmount: _tipAmount,
        description: description,
        isAnonymous: _isAnonymous || donorId == null,
        items: _isAmountMode ? <DonationItemRequest>[] : itemsPayload,
      );

      final response =
          await _api.createPayment(payload.toJson());
      final Map<String, dynamic> data =
          response.data as Map<String, dynamic>;
      final String? paymentUrl = data['paymentUrl'] as String?;
      final int? donationId = (data['donationId'] as num?)?.toInt();

      if (paymentUrl != null && mounted) {
        final dynamic webViewResult = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (BuildContext context) =>
                DonationWebViewScreen(
              paymentUrl: paymentUrl,
              donationId: donationId,
            ),
          ),
        );

        if (!mounted) return;

        final Map<String, dynamic>? result =
            webViewResult is Map<String, dynamic> ? webViewResult : null;
        final bool isSuccess = result?['success'] == true;
        final int? completedDonationId =
            (result?['donationId'] as num?)?.toInt() ?? donationId;

        if (isSuccess && completedDonationId != null) {
          try {
            await _api.verifyDonationPayment(completedDonationId);
          } catch (_) {}
          // Match web flow: sync item quantities + campaign balance
          // after payment verification, but do not block success screen.
          try {
            await _api.syncDonationQuantity(completedDonationId);
          } catch (_) {}
          try {
            await _api.syncDonationBalance(completedDonationId);
          } catch (_) {}
          if (!mounted) return;
          final bool? goBackWithRefresh = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => DonationSuccessScreen(
                campaignTitle: widget.campaign.title,
                totalAmount: _donationAmount + _tipAmount,
              ),
            ),
          );
          if (!mounted) return;
          if (goBackWithRefresh == true) {
            Navigator.of(context).pop(true);
          }
        } else if (result != null && result['success'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn đã hủy thanh toán')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Không nhận được liên kết thanh toán từ máy chủ'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Có lỗi xảy ra khi khởi tạo thanh toán: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    const Color webPrimary = Color(0xFFF84D43);
    const Color webBgGray = Color(0xFFF9FAFB);
    const Color webTextDark = Color(0xFF1F2937);
    const Color webTextGray = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          'Quyên góp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: webTextDark,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      if (_donationBlocked)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            _blockedMessage.isNotEmpty
                                ? _blockedMessage
                                : 'Chiến dịch chưa thể nhận quyên góp.',
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 160,
                              width: double.infinity,
                              child: widget.campaign.coverImageUrl != null &&
                                      widget.campaign.coverImageUrl!.isNotEmpty
                                  ? Image.network(
                                      widget.campaign.coverImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _campaignPlaceholder(),
                                    )
                                  : _campaignPlaceholder(),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.campaign.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: webTextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.campaign.description?.trim().isNotEmpty == true
                                        ? widget.campaign.description!
                                        : 'Chọn hạng mục bên dưới để quyên góp đúng mục tiêu.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: webTextGray,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _isAmountMode = true;
                                    _selectedQuantities.clear();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isAmountMode ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: _isAmountMode
                                        ? Border.all(color: const Color(0xFFE5E7EB))
                                        : null,
                                  ),
                                  child: Text(
                                    'Theo số tiền',
                                    style: TextStyle(
                                      color: _isAmountMode ? webTextDark : webTextGray,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _isAmountMode = false;
                                    _manualAmount = 0;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: !_isAmountMode ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: !_isAmountMode
                                        ? Border.all(color: const Color(0xFFE5E7EB))
                                        : null,
                                  ),
                                  child: Text(
                                    'Theo hạng mục',
                                    style: TextStyle(
                                      color: !_isAmountMode ? webTextDark : webTextGray,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Số tiền quyên góp',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: webTextDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: _presetAmounts
                                  .map(
                                    (int amount) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: OutlinedButton(
                                          onPressed: () => _setManualAmount(amount),
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: _manualAmount == amount
                                                ? webPrimary
                                                : Colors.white,
                                            foregroundColor: _manualAmount == amount
                                                ? Colors.white
                                                : webTextDark,
                                            side: BorderSide(
                                              color: _manualAmount == amount
                                                  ? webPrimary
                                                  : const Color(0xFFE5E7EB),
                                            ),
                                            minimumSize: const Size(0, 38),
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Text(
                                            '${(amount / 1000).toInt()}K',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Nhập số tiền tùy chỉnh',
                                hintText: 'Ví dụ: 150000',
                                prefixText: 'đ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                isDense: true,
                              ),
                              onChanged: (String value) {
                                final String digits =
                                    value.replaceAll(RegExp(r'[^0-9]'), '');
                                _setManualAmount(int.tryParse(digits) ?? 0);
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!_isAmountMode) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Hạng mục quyên góp',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: webTextDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Text(
                              'Chưa có hạng mục chi tiêu nào có thể quyên góp.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._items.map((ExpenditureItemModel item) {
                            final int currentQty = _selectedQuantities[item.id] ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: webTextDark,
                                    ),
                                  ),
                                  if (item.note != null && item.note!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.note!,
                                      style: const TextStyle(
                                        color: webTextGray,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_fmt.format(item.expectedPrice)} đ / suất',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: webTextDark,
                                        ),
                                      ),
                                      Text(
                                        'Còn lại: ${item.quantityLeft}',
                                        style: const TextStyle(
                                          color: webTextGray,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _stepButton(
                                        icon: Icons.remove,
                                        enabled: currentQty > 0,
                                        onTap: () {
                                          setState(() {
                                            _manualAmount = 0;
                                            final int next = currentQty - 1;
                                            if (next <= 0) {
                                              _selectedQuantities.remove(item.id);
                                            } else {
                                              _selectedQuantities[item.id] = next;
                                            }
                                          });
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          '$currentQty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      _stepButton(
                                        icon: Icons.add,
                                        enabled: currentQty < item.quantityLeft,
                                        onTap: () {
                                          setState(() {
                                            _manualAmount = 0;
                                            _selectedQuantities[item.id] = currentQty + 1;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tiền tip nền tảng',
                                  style: TextStyle(
                                    color: webTextDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_tipPercent}%',
                                  style: const TextStyle(
                                    color: webTextDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _tipPercent.toDouble(),
                              min: 0,
                              max: 30,
                              divisions: 6,
                              activeColor: webPrimary,
                              label: '$_tipPercent%',
                              onChanged: (double value) {
                                setState(() {
                                  _tipPercent = value.round();
                                });
                              },
                            ),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Nhập tip (%)',
                                hintText: '0 - 30',
                                suffixText: '%',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                isDense: true,
                              ),
                              onChanged: (String value) {
                                final int next = int.tryParse(value) ?? _tipPercent;
                                setState(() {
                                  _tipPercent = next.clamp(0, 30);
                                });
                              },
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isAnonymous,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _isAnonymous = value ?? false;
                                    });
                                  },
                                ),
                                const Expanded(
                                  child: Text('Quyên góp ẩn danh'),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isAgreed,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _isAgreed = value ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const DonationTermsScreen(),
                                        ),
                                      );
                                    },
                                    child: RichText(
                                      text: const TextSpan(
                                        style: TextStyle(
                                          color: webTextGray,
                                          fontSize: 14,
                                        ),
                                        children: [
                                          TextSpan(text: 'Tôi đồng ý '),
                                          TextSpan(
                                            text: 'điều khoản quyên góp',
                                            style: TextStyle(
                                              color: webPrimary,
                                              fontWeight: FontWeight.w700,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tiền quyên góp', style: TextStyle(color: webTextGray)),
                            Text(
                              '${_fmt.format(_donationAmount)} đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: webTextDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tiền tip', style: TextStyle(color: webTextGray)),
                            Text(
                              '${_fmt.format(_tipAmount)} đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: webTextDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tổng thanh toán',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: webTextDark,
                              ),
                            ),
                            Text(
                              '${_fmt.format(_donationAmount + _tipAmount)} đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: webPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (_submitting ||
                                        !_isAgreed ||
                                        _donationAmount <= 0 ||
                                        _donationBlocked)
                                    ? null
                                    : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: webPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Quyên góp ngay',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _campaignPlaceholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 34,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

