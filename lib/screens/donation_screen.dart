import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api/api_service.dart';
import '../core/models/campaign_model.dart';
import '../core/models/expenditure_item_model.dart';
import '../core/models/payment_models.dart';
import '../core/providers/auth_provider.dart';
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

  bool _loading = true;
  bool _submitting = false;
  bool _isAnonymous = false;

  List<ExpenditureItemModel> _items = <ExpenditureItemModel>[];
  final Map<int, int> _selectedQuantities = <int, int>{};

  int _tipPercent = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response =
          await _api.getExpenditureItemsByCampaign(widget.campaign.id);
      final List<dynamic> data = response.data as List<dynamic>;
      _items = data
          .map(
            (dynamic e) =>
                ExpenditureItemModel.fromJson(e as Map<String, dynamic>),
          )
          .where((ExpenditureItemModel e) => e.quantityLeft > 0)
          .toList();
    } catch (_) {
      _items = <ExpenditureItemModel>[];
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int get _donationAmount {
    int total = 0;
    _selectedQuantities.forEach((int id, int qty) {
      final ExpenditureItemModel? item =
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

  Future<void> _handleSubmit() async {
    if (_selectedQuantities.isEmpty || _donationAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một hạng mục để quyên góp'),
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

      final String userIdStr = donorId?.toString() ?? 'GUEST';
      final String description =
          'USER$userIdStrCAMPAIGN${widget.campaign.id}';

      final CreatePaymentRequestModel payload =
          CreatePaymentRequestModel(
        donorId: donorId,
        campaignId: widget.campaign.id,
        donationAmount: _donationAmount,
        tipAmount: _tipAmount,
        description: description,
        isAnonymous: _isAnonymous || donorId == null,
        items: itemsPayload,
      );

      final response =
          await _api.createPayment(payload.toJson());
      final Map<String, dynamic> data =
          response.data as Map<String, dynamic>;
      final String? paymentUrl = data['paymentUrl'] as String?;

      if (paymentUrl != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                DonationWebViewScreen(paymentUrl: paymentUrl),
          ),
        );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaign.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Chọn hạng mục để quyên góp',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có hạng mục chi tiêu nào có thể quyên góp',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (BuildContext context, int index) {
                              final ExpenditureItemModel item =
                                  _items[index];
                              final int currentQty =
                                  _selectedQuantities[item.id] ?? 0;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        item.category,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (item.note != null &&
                                          item.note!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            item.note!,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: <Widget>[
                                          Text(
                                            '${_fmt.format(item.expectedPrice)} đ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Còn lại: ${item.quantityLeft}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: <Widget>[
                                          IconButton(
                                            onPressed: currentQty > 0
                                                ? () {
                                                    setState(() {
                                                      final int next =
                                                          currentQty - 1;
                                                      if (next <= 0) {
                                                        _selectedQuantities
                                                            .remove(
                                                                item.id);
                                                      } else {
                                                        _selectedQuantities[
                                                                item.id] =
                                                            next;
                                                      }
                                                    });
                                                  }
                                                : null,
                                            icon: const Icon(Icons.remove),
                                          ),
                                          Text('$currentQty'),
                                          IconButton(
                                            onPressed: currentQty <
                                                    item.quantityLeft
                                                ? () {
                                                    setState(() {
                                                      _selectedQuantities[
                                                              item.id] =
                                                          currentQty + 1;
                                                    });
                                                  }
                                                : null,
                                            icon: const Icon(Icons.add),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Tiền tip (%)'),
                      DropdownButton<int>(
                        value: _tipPercent,
                        items: <int>[0, 5, 10, 15]
                            .map(
                              (int v) => DropdownMenuItem<int>(
                                value: v,
                                child: Text('$v%'),
                              ),
                            )
                            .toList(),
                        onChanged: (int? v) {
                          if (v == null) return;
                          setState(() {
                            _tipPercent = v;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
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
                  const SizedBox(height: 8),
                  Text(
                    'Tiền quyên góp: ${_fmt.format(_donationAmount)} đ',
                  ),
                  Text(
                    'Tiền tip: ${_fmt.format(_tipAmount)} đ',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tổng thanh toán: ${_fmt.format(_donationAmount + _tipAmount)} đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSubmit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Quyên góp ngay'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

