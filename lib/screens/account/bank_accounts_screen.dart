import 'package:flutter/material.dart';
import '../../core/api/campaign_service.dart';
import '../../core/api/user_service.dart';
import '../../core/models/bank_account_model.dart';

/// Màn hình quản lý tài khoản ngân hàng.
class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  final UserService _userService = UserService();
  final CampaignService _campaignService = CampaignService();
  bool _isLoading = true;
  List<BankAccountModel> _accounts = [];

  static const Color _primary = Color(0xFFF84D43);
  static const Color _emerald = Color(0xFF1A685B);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _textGray = Color(0xFF4B5563);
  static const Color _bgGray = Color(0xFFF9FAFB);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _userService.getMyBankAccounts();
      if (response.statusCode == 200 && response.data is List) {
        final list = (response.data as List)
            .where((e) => e is Map<String, dynamic>)
            .map((e) => BankAccountModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;
        setState(() => _accounts = list);

        // Fetch campaign titles cho các account có campaignId
        _fetchCampaignTitles(list);
      }
    } catch (e) {
      debugPrint('Error fetching bank accounts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Lấy tên chiến dịch cho từng bank account có campaignId.
  Future<void> _fetchCampaignTitles(List<BankAccountModel> accounts) async {
    for (final account in accounts) {
      if (account.campaignId == null) continue;
      try {
        final res = await _campaignService.getCampaign(account.campaignId!);
        if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
          final data = res.data as Map<String, dynamic>;
          final title = data['title'] as String?;
          if (title != null && mounted) {
            setState(() {
              account.campaignTitle = title;
            });
          }
        }
      } catch (e) {
        debugPrint(
            'Error fetching campaign ${account.campaignId}: $e');
      }
    }
  }

  void _openAddEditSheet({BankAccountModel? existing}) {
    final bankCodeCtrl =
        TextEditingController(text: existing?.bankCode ?? '');
    final accountNumberCtrl =
        TextEditingController(text: existing?.accountNumber ?? '');
    final holderNameCtrl =
        TextEditingController(text: existing?.accountHolderName ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 16,
              left: 24,
              right: 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    existing != null
                        ? 'Chỉnh sửa tài khoản'
                        : 'Thêm tài khoản ngân hàng',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _textDark),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: bankCodeCtrl,
                    decoration: _inputDec('Tên ngân hàng *',
                        hint: 'VD: MB Bank, Vietcombank'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Không được để trống'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: accountNumberCtrl,
                    decoration: _inputDec('Số tài khoản *',
                        hint: 'Nhập số tài khoản/thẻ'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Không được để trống';
                      }
                      if (!RegExp(r'^[0-9]{6,30}$').hasMatch(v.trim())) {
                        return 'Số tài khoản 6-30 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: holderNameCtrl,
                    decoration: _inputDec('Tên chủ tài khoản *',
                        hint: 'Nhập họ tên'),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Không được để trống'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              try {
                                final data = <String, dynamic>{
                                  'bankCode': bankCodeCtrl.text.trim(),
                                  'accountNumber':
                                      accountNumberCtrl.text.trim(),
                                  'accountHolderName':
                                      holderNameCtrl.text.trim(),
                                };
                                if (existing != null) {
                                  await _userService.updateBankAccount(
                                      existing.id, data);
                                } else {
                                  await _userService.createBankAccount(data);
                                }
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                _fetchAccounts();
                                _snack(existing != null
                                    ? 'Đã cập nhật tài khoản.'
                                    : 'Đã thêm tài khoản mới.');
                              } catch (e) {
                                _snack('Lỗi: $e', isError: true);
                              } finally {
                                if (mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              existing != null ? 'Cập nhật' : 'Thêm mới',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  InputDecoration _inputDec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _bgGray,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _emerald,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text('Tài khoản ngân hàng',
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
          : RefreshIndicator(
              onRefresh: _fetchAccounts,
              child: _accounts.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _accounts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildAccountCard(_accounts[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(),
        backgroundColor: _primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm tài khoản',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                color: Colors.blue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_outlined,
                  size: 64, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            const Text('Chưa có tài khoản nào',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            const SizedBox(height: 8),
            const Text(
              'Nhấn nút "Thêm tài khoản" để liên kết ngân hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textGray, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BankAccountModel account) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance,
                size: 24, color: _emerald),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.bankCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _textDark)),
                const SizedBox(height: 2),
                Text(
                  '${_maskAccountNumber(account.accountNumber)} • ${account.accountHolderName}',
                  style: const TextStyle(fontSize: 12, color: _textGray),
                ),
                // Hiển thị tên chiến dịch liên kết
                if (account.campaignId != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.campaign_outlined,
                          size: 13, color: _primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Chiến dịch: ${account.campaignTitle ?? '#${account.campaignId}'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (account.isVerified) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: _emerald),
                      const SizedBox(width: 4),
                      Text('Đã xác minh',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _emerald)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textGray),
            onSelected: (action) {
              if (action == 'edit') {
                _openAddEditSheet(existing: account);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Chỉnh sửa'),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }

  String _maskAccountNumber(String number) {
    if (number.length <= 4) return number;
    return '${'*' * (number.length - 4)}${number.substring(number.length - 4)}';
  }
}
