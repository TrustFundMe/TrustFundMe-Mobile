import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustfundme_mobile/core/api/api_service.dart';
import 'package:trustfundme_mobile/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:trustfundme_mobile/core/utils/error_handler.dart';
import 'package:trustfundme_mobile/core/utils/image_cropper_helper.dart';

class CreateCampaignScreen extends StatefulWidget {
  final bool isEditMode;
  final int? campaignId;

  const CreateCampaignScreen({
    super.key,
    this.isEditMode = false,
    this.campaignId,
  });

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  int _currentStep = 0;
  String _fundType = ''; // 'AUTHORIZED' or 'ITEMIZED'
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thankMessageController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _aiPromptController = TextEditingController();
  
  final _bankCodeController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderNameController = TextEditingController();

  int? _selectedCategoryId;
  final List<XFile> _attachments = [];
  int? _coverIndex;
  final List<Map<String, dynamic>> _expenditureItems = [];
  List<dynamic> _categories = [];
  bool _bankInfoChanged = false;

  // Validation error messages per step
  String? _stepError;

  bool _isGeneratingAI = false;
  bool _isSubmitting = false;

  // Helper: total expenditure amount
  int get _totalExpenditureAmount =>
      _expenditureItems.fold(0, (sum, item) {
        final qty = int.tryParse((item['quantityController'] as TextEditingController?)?.text ?? '0') ?? 0;
        final price = int.tryParse((item['priceController'] as TextEditingController?)?.text ?? '0') ?? 0;
        return sum + qty * price;
      });

  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webTextDark = Color(0xFF1F2937);
  static const Color webEmerald = Color(0xFF1A685B);

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.isEditMode && widget.campaignId != null) {
      _fetchCampaignData();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.bankAccount != null) {
        _bankCodeController.text = authProvider.bankAccount!.bankCode;
        _accountNumberController.text = authProvider.bankAccount!.accountNumber;
        _accountHolderNameController.text = authProvider.bankAccount!.accountHolderName;
      }
      _bankCodeController.addListener(_onBankInfoChanged);
      _accountNumberController.addListener(_onBankInfoChanged);
      _accountHolderNameController.addListener(_onBankInfoChanged);
    });
  }

  Future<void> _fetchCampaignData() async {
    setState(() => _isSubmitting = true); 
    try {
      final response = await _apiService.getCampaign(widget.campaignId!);
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _titleController.text = data['title'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _thankMessageController.text = data['thankMessage'] ?? '';
          _targetAmountController.text = (data['targetAmount'] ?? 0).toString();
          _selectedCategoryId = data['categoryId'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching campaign data: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _onBankInfoChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final existing = authProvider.bankAccount;
    if (existing == null) return;

    final changed = _bankCodeController.text != existing.bankCode ||
        _accountNumberController.text != existing.accountNumber ||
        _accountHolderNameController.text != existing.accountHolderName;

    if (changed != _bankInfoChanged) {
      setState(() => _bankInfoChanged = changed);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thankMessageController.dispose();
    _targetAmountController.dispose();
    _aiPromptController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    _accountHolderNameController.dispose();
    for (var item in _expenditureItems) {
      (item['nameController'] as TextEditingController?)?.dispose();
      (item['quantityController'] as TextEditingController?)?.dispose();
      (item['priceController'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await _apiService.getCategories();
      if (res.statusCode == 200) {
        setState(() => _categories = res.data);
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          "Tạo chiến dịch",
          style: TextStyle(color: webTextDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: webTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          // Error banner shown directly below progress, above content
          if (_stepError != null)
            Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: double.infinity,
                color: webPrimary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: webPrimary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _stepError!,
                        style: const TextStyle(color: webPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _stepError = null),
                      child: const Icon(Icons.close, size: 18, color: webPrimary),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _buildCurrentStep(),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          bool isActive = index <= _currentStep;
          return Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? webPrimary : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (index < 4)
                Container(
                  width: 30,
                  height: 2,
                  color: index < _currentStep ? webPrimary : Colors.grey[200],
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- AI Logic ---
  Future<void> _generateAIDescription() async {
    if (_aiPromptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập ý tưởng để AI hỗ trợ")),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);
    try {
      final response = await _apiService.generateDescription(_aiPromptController.text);
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _titleController.text = response.data['title'] ?? _titleController.text;
          _descriptionController.text = response.data['description'] ?? "";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã tạo tiêu đề và mô tả thành công!")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi AI: ${ErrorHandler.handle(e)}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAI = false);
      }
    }
  }

  // --- Validation ---
  bool _validateStep(int step) {
    String? error;
    switch (step) {
      case 0: // Step 1: Fund type
        if (_fundType.isEmpty) error = "Vui lòng chọn loại quỹ để tiếp tục.";
        break;
      case 1: // Step 2: Basic info
        if (_titleController.text.trim().length < 10) {
          error = "Tiêu đề chiến dịch phải có ít nhất 10 ký tự.";
        } else if (_selectedCategoryId == null) {
          error = "Vui lòng chọn danh mục chiến dịch.";
        } else if (_targetAmountController.text.trim().isEmpty ||
            (int.tryParse(_targetAmountController.text) ?? 0) <= 0) {
          error = "Vui lòng nhập mục tiêu tài chính hợp lệ (> 0).";
        } else if (_descriptionController.text.trim().length < 50) {
          error = "Mô tả hoàn cảnh phải có ít nhất 50 ký tự.";
        }
        break;
      case 2: // Step 3: Financial plan (only for ITEMIZED)
        if (_fundType == 'ITEMIZED') {
          if (_expenditureItems.isEmpty) {
            error = "Quỹ Vật Phẩm cần ít nhất 1 vật phẩm trong danh sách.";
          } else {
            for (int i = 0; i < _expenditureItems.length; i++) {
              final item = _expenditureItems[i];
              final name = (item['nameController'] as TextEditingController).text.trim();
              final price = int.tryParse((item['priceController'] as TextEditingController).text) ?? 0;
              
              if (name.isEmpty) {
                error = "Vật phẩm #${i + 1} chưa có tên. Vui lòng điền đầy đủ.";
                break;
              }
              if (price <= 0) {
                error = "Vật phẩm #${i + 1} cần có đơn giá > 0.";
                break;
              }
            }
          }
          if (error == null) {
            final int target = int.tryParse(_targetAmountController.text) ?? 0;
            if (_totalExpenditureAmount > target) {
              error = "Tổng chi phí đang vượt quá mục tiêu gây quỹ (${_formatCurrency(target)}). Vui lòng điều chỉnh lại.";
            }
          }
        }
        break;
      case 3: // Step 4: Banking
        if (_bankCodeController.text.trim().isEmpty) {
          error = "Vui lòng nhập tên ngân hàng.";
        } else if (_accountNumberController.text.trim().isEmpty) {
          error = "Vui lòng nhập số tài khoản.";
        } else if (_accountHolderNameController.text.trim().isEmpty) {
          error = "Vui lòng nhập tên chủ tài khoản.";
        }
        break;
    }
    setState(() => _stepError = error);
    return error == null;
  }

  // --- Step 3: Financial Plan (Itemized only) ---
  Widget _buildStep3() {
    if (_fundType == 'AUTHORIZED') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: webEmerald),
              const SizedBox(height: 24),
              const Text(
                "Chế độ Quỹ Ủy Quyền",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "Bạn sẽ thực hiện giải ngân và gửi minh chứng từng đợt sau khi nhận quỹ. Không cần lập danh sách vật phẩm ngay bây giờ.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final int totalAmount = _totalExpenditureAmount;
    final int targetAmount = int.tryParse(_targetAmountController.text) ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("DANH SÁCH VẬT PHẨM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _expenditureItems.add({
                      "nameController": TextEditingController(),
                      "unit": "chiếc",
                      "quantityController": TextEditingController(text: "1"),
                      "priceController": TextEditingController(text: "0"),
                    });
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Thêm"),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _expenditureItems.length,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemBuilder: (context, index) {
              final item = _expenditureItems[index];
              final nameController = item['nameController'] as TextEditingController;
              final qtyController = item['quantityController'] as TextEditingController;
              final priceController = item['priceController'] as TextEditingController;
              
              final int qty = int.tryParse(qtyController.text) ?? 0;
              final int price = int.tryParse(priceController.text) ?? 0;
              final int lineTotal = qty * price;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                hintText: "Tên vật phẩm...",
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() {
                              nameController.dispose();
                              qtyController.dispose();
                              priceController.dispose();
                              _expenditureItems.removeAt(index);
                            }),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("SỐ LƯỢNG", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                TextField(
                                  controller: qtyController,
                                  onChanged: (v) => setState(() {}),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(hintText: "1", border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("×", style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Text("ĐƠN GIÁ (đ)", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                TextField(
                                  controller: priceController,
                                  onChanged: (v) => setState(() {}),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(hintText: "0", border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: webPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("THÀNH TIỀN", style: TextStyle(fontSize: 9, color: webPrimary, fontWeight: FontWeight.bold)),
                                Text(
                                  _formatCurrency(lineTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: webPrimary),
                                ),
                              ],
                            ),
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
        // Sticky footer: total vs target
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: totalAmount > targetAmount && targetAmount > 0 ? Colors.orange : webEmerald,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tổng vật phẩm", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _formatCurrency(totalAmount),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: webTextDark),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Mục tiêu đặt ra", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    targetAmount > 0 ? _formatCurrency(targetAmount) : "Chưa đặt",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: targetAmount > 0 ? (totalAmount > targetAmount ? Colors.orange : webEmerald) : Colors.grey,
                    ),
                  ),
                  if (totalAmount > targetAmount && targetAmount > 0)
                    const Text("⚠ Vượt mục tiêu!", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


  // --- Step 4: Banking ---
  Future<void> _handleBankUpdateConfirmation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance, color: webPrimary, size: 22),
            SizedBox(width: 10),
            Text("Cập nhật ngân hàng?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Bạn đã thay đổi thông tin ngân hàng. Bạn có muốn cập nhật lên hệ thống không?",
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Không", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: webPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Cập nhật"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await authProvider.saveBankAccount(
        _bankCodeController.text,
        _accountNumberController.text,
        _accountHolderNameController.text.toUpperCase(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Đã cập nhật thông tin ngân hàng!" : "Cập nhật thất bại. Vui lòng thử lại."),
            backgroundColor: success ? webEmerald : Colors.redAccent,
          ),
        );
        if (success) setState(() => _bankInfoChanged = false);
      }
    }
  }

  Widget _buildStep4() {
    final authProvider = Provider.of<AuthProvider>(context);
    final hasExisting = authProvider.bankAccount != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tài khoản nhận quỹ",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Thông tin ngân hàng để nhận tiền quyên góp"),
          const SizedBox(height: 16),

          // Status banner
          if (hasExisting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _bankInfoChanged ? Colors.orange.withValues(alpha: 0.1) : webEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _bankInfoChanged ? Colors.orange : webEmerald, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    _bankInfoChanged ? Icons.edit_note : Icons.verified_rounded,
                    size: 18,
                    color: _bankInfoChanged ? Colors.orange : webEmerald,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _bankInfoChanged
                          ? "Bạn đã thay đổi thông tin. Nhấn \"Tiếp tục\" để được hỏi cập nhật."
                          : "Đã điền sẵn thông tin ngân hàng của bạn.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _bankInfoChanged ? Colors.orange[800] : webEmerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _buildInputFieldLabel("NGÂN HÀNG"),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _bankCodeController,
              decoration: const InputDecoration(hintText: "VD: MBBank, VCB, Viettin...", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 20),
          _buildInputFieldLabel("SỐ TÀI KHOẢN"),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Nhập số tài khoản...", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 20),
          _buildInputFieldLabel("TÊN CHỦ TÀI KHOẢN"),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _accountHolderNameController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: "Tên không dấu in hoa...", border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 16),
          if (_bankInfoChanged)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleBankUpdateConfirmation,
                icon: const Icon(Icons.sync, color: webPrimary),
                label: const Text("Cập nhật thông tin ngân hàng ngay", style: TextStyle(color: webPrimary, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: webPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Step 5: Review & Logic ---
  Widget _buildStep5() {
    final int totalExpenditure = _totalExpenditureAmount;
    final int targetAmount = int.tryParse(_targetAmountController.text) ?? 0;
    final bool isItemized = _fundType == 'ITEMIZED';
    final double progressPercent = (targetAmount > 0 && isItemized)
        ? (totalExpenditure / targetAmount).clamp(0.0, 1.0)
        : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kiểm tra lại", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Basic info card
          _buildReviewCard("Thông tin cơ bản", Icons.info_outline, [
            _buildReviewItem("Tên chiến dịch", _titleController.text.isNotEmpty ? _titleController.text : "(Chưa nhập)"),
            _buildReviewItem("Loại quỹ", _fundType == 'AUTHORIZED' ? "Quỹ Ủy Quyền" : "Quỹ Vật Phẩm"),
            _buildReviewItem("Danh mục", _categories.firstWhere((c) => c['id'] == _selectedCategoryId, orElse: () => {'name': 'Chưa chọn'})['name']),
            _buildReviewItem("Mục tiêu", "${_formatCurrency(targetAmount)} VNĐ"),
            if (_thankMessageController.text.isNotEmpty)
              _buildReviewItem("Lời cảm ơn", _thankMessageController.text),
          ]),

          const SizedBox(height: 16),

          // Banking card
          _buildReviewCard("Tài khoản nhận quỹ", Icons.account_balance, [
            _buildReviewItem("Ngân hàng", _bankCodeController.text.isNotEmpty ? _bankCodeController.text : "(Chưa nhập)"),
            _buildReviewItem("Số tài khoản", _accountNumberController.text.isNotEmpty ? _accountNumberController.text : "(Chưa nhập)"),
            _buildReviewItem("Chủ tài khoản", _accountHolderNameController.text.isNotEmpty ? _accountHolderNameController.text : "(Chưa nhập)"),
          ]),

          // Expenditure table (only for ITEMIZED)
          if (isItemized && _expenditureItems.isNotEmpty) ...
          [
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 18, color: webTextDark),
                        const SizedBox(width: 8),
                        const Text("Danh sách vật phẩm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Text("${_expenditureItems.length} mục", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text("Vật phẩm", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                        Expanded(child: Text("SL", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                        Expanded(child: Text("Đơn giá", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                        Expanded(child: Text("Thành tiền", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Item rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _expenditureItems.length,
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _expenditureItems[index];
                      final name = (item['nameController'] as TextEditingController).text;
                      final qty = int.tryParse((item['quantityController'] as TextEditingController).text) ?? 0;
                      final price = int.tryParse((item['priceController'] as TextEditingController).text) ?? 0;
                      final lineTotal = qty * price;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(child: Text("$qty", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                            Expanded(child: Text(_formatCurrency(price), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                            Expanded(child: Text(_formatCurrency(lineTotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Total vs Target comparison
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Tổng vật phẩm", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_formatCurrency(totalExpenditure), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 8,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              totalExpenditure > targetAmount ? Colors.orange : webEmerald,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(progressPercent * 100).toStringAsFixed(1)}% so với mục tiêu",
                              style: TextStyle(
                                fontSize: 11,
                                color: totalExpenditure > targetAmount ? Colors.orange : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Mục tiêu: ${_formatCurrency(targetAmount)}",
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (totalExpenditure > targetAmount)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Tổng vật phẩm vượt mục tiêu ${_formatCurrency(totalExpenditure - targetAmount)}. Bạn có thể điều chỉnh lại.",
                                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: webEmerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: webEmerald),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tôi cam kết mọi thông tin cung cấp là sự thật và chịu trách nhiệm trước pháp luật.",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: webEmerald),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: webTextDark),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }


  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCampaign() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      // 1. Nếu thông tin ngân hàng đã thay đổi và chưa lưu, hỏi lại lần cuối
      if (_bankInfoChanged) {
        await _handleBankUpdateConfirmation();
      } else if (authProvider.bankAccount == null) {
        // Chưa có ngân hàng: tạo mới
        await _apiService.createBankAccount({
          "bankCode": _bankCodeController.text,
          "accountNumber": _accountNumberController.text,
          "accountHolderName": _accountHolderNameController.text.toUpperCase(),
        });
      }

      // 2. Upload Media first to get IDs
      List<Map<String, dynamic>> uploadedMedia = [];
      int? coverMediaId;

      for (int i = 0; i < _attachments.length; i++) {
        final res = await _apiService.uploadMedia(File(_attachments[i].path), mediaType: "PHOTO");
        if (res.statusCode == 200 || res.statusCode == 201) {
          final m = res.data;
          uploadedMedia.add({
            "id": m['id'],
            "url": m['url'],
            "type": "PHOTO",
            "name": _attachments[i].name,
          });
          if (_coverIndex == i) coverMediaId = m['id'];
        }
      }

      // 3. Create Campaign with coverImage
      final String nowIso = DateTime.now().toIso8601String().split('.').first; // Remove ms and timezone for LocalDateTime
      final String endIso = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('.').first;

      int campaignId;
      if (widget.isEditMode && widget.campaignId != null) {
        await _apiService.updateCampaign(widget.campaignId!, {
          "title": _titleController.text.trim(),
          "description": _descriptionController.text.trim(),
          "thankMessage": _thankMessageController.text.trim().isNotEmpty ? _thankMessageController.text.trim() : null,
          "categoryId": _selectedCategoryId ?? 1,
          "type": _fundType,
          "coverImage": coverMediaId,
          "status": 'PENDING_APPROVAL',
        });
        campaignId = widget.campaignId!;
      } else {
        final campaignRes = await _apiService.createCampaign({
          "fundOwnerId": user.id,
          "title": _titleController.text.trim(),
          "description": _descriptionController.text.trim(),
          "thankMessage": _thankMessageController.text.trim().isNotEmpty ? _thankMessageController.text.trim() : null,
          "categoryId": _selectedCategoryId ?? 1,
          "type": _fundType,
          "coverImage": coverMediaId,
          "attachments": uploadedMedia.map((m) => {
            "id": m['id'],
            "type": m['type'],
            "url": m['url'],
            "name": m['name'],
          }).toList(),
          "status": 'PENDING_APPROVAL',
          "balance": 0,
          "startDate": nowIso,
          "endDate": endIso,
        });
        campaignId = campaignRes.data['id'];
      }

      // 4. Fundraising Goal
      await _apiService.createGoal({
        "campaignId": campaignId,
        "targetAmount": int.tryParse(_targetAmountController.text) ?? 0,
        "description": "Mục tiêu gây quỹ ban đầu",
      });

      // 5. Expenditure (if Itemized)
      if (_fundType == 'ITEMIZED' && _expenditureItems.isNotEmpty) {
        await _apiService.createExpenditure({
          "campaignId": campaignId,
          "items": _expenditureItems.map((e) => {
            "category": (e['nameController'] as TextEditingController).text,
            "quantity": int.tryParse((e['quantityController'] as TextEditingController).text) ?? 1,
            "price": 0,
            "expectedPrice": int.tryParse((e['priceController'] as TextEditingController).text) ?? 0,
          }).toList(),
          "plan": "Kế hoạch chi tiết từ Mobile",
        });
      }

      // 6. Link media to campaign (Backend usually handles this if sent in attachments, but to be sure)
      for (var m in uploadedMedia) {
        await _apiService.linkMediaToCampaign(m['id'], campaignId);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chiến dịch đã được gửi duyệt thành công!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi gửi duyệt: ${ErrorHandler.handle(e)}")));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            "Chọn Loại Quỹ",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: webTextDark),
          ),
          const SizedBox(height: 8),
          Text(
            "Phân loại hình thức minh bạch của bạn",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          _buildTypeCard(
            type: 'AUTHORIZED',
            title: "Quỹ Ủy Quyền",
            description: "Donor tin tưởng vào uy tín cá nhân. Phù hợp cho cứu trợ khẩn cấp hoặc các quỹ linh hoạt.",
            image: 'assets/images/trust.png', // Assuming image existence or fallback
          ),
          const SizedBox(height: 20),
          _buildTypeCard(
            type: 'ITEMIZED',
            title: "Quỹ Vật Phẩm",
            description: "Minh bạch từng vật phẩm. Phù hợp cho xây trường, ca phẫu thuật hoặc mua sắm nhu yếu phẩm.",
            image: 'assets/images/select.png',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({required String type, required String title, required String description, required String image}) {
    bool isSelected = _fundType == type;
    return GestureDetector(
      onTap: () => setState(() => _fundType = type),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? webPrimary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? webPrimary.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                type == 'AUTHORIZED' 
                  ? "assets/images/campaign/trust.webp"
                  : "assets/images/campaign/select.webp",
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  color: Colors.grey[50],
                  child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isSelected ? webPrimary : webTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: webPrimary, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "ĐÃ CHỌN",
                      style: TextStyle(color: webPrimary, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              hintText: "Tiêu đề chiến dịch...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.black12),
            ),
          ),
          const Divider(height: 32),
          _buildInputFieldLabel("DANH MỤC"),
          _buildCategoryDropdown(),
          const SizedBox(height: 24),
          _buildInputFieldLabel("MỤC TIÊU TÀI CHÍNH"),
          _buildNumericField(_targetAmountController, "VNĐ"),
          const SizedBox(height: 24),
          _buildInputFieldLabel("MÔ TẢ HOÀN CẢNH"),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: "Nêu rõ hoàn cảnh và mục đích sử dụng quỹ...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          _buildAISection(),
          const SizedBox(height: 24),
          _buildInputFieldLabel("LỜI CẢM ƠN (TÙY CHỌN)"),
          TextField(
            controller: _thankMessageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Lời cảm ơn sau khi nhà hảo tâm đóng góp...",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          _buildInputFieldLabel("ĐÍNH KÈM PHƯƠNG TIỆN"),
          _buildMediaManager(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedCategoryId,
          hint: const Text("Chọn danh mục", style: TextStyle(color: Colors.black12, fontWeight: FontWeight.bold)),
          isExpanded: true,
          items: _categories.map<DropdownMenuItem<int>>((cat) {
            return DropdownMenuItem<int>(
              value: cat['id'],
              child: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedCategoryId = val),
        ),
      ),
    );
  }

  Widget _buildAISection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: webPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: webPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: webPrimary, size: 20),
              const SizedBox(width: 8),
              const Text("AI Assistant", style: TextStyle(fontWeight: FontWeight.bold, color: webPrimary)),
              const Spacer(),
              if (_isGeneratingAI)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: webPrimary))
              else
                TextButton(
                  onPressed: _generateAIDescription,
                  child: const Text("Tạo nội dung", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          TextField(
            controller: _aiPromptController,
            decoration: const InputDecoration(
              hintText: "Nhập ý chính (VD: giúp bé bị bệnh...) để AI viết hộ",
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  static const int _maxImages = 5;

  Future<void> _pickAndProcessImages() async {
    final int remaining = _maxImages - _attachments.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tối đa $_maxImages ảnh. Xóa bớt để thêm ảnh mới.")),
      );
      return;
    }

    List<XFile> picked = [];
    try {
      picked = await _picker.pickMultiImage(limit: remaining);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không thể mở thư viện ảnh. Thử lại.")),
      );
      return;
    }

    if (picked.isEmpty) return;

    final List<XFile> processed = <XFile>[];
    for (final XFile file in picked) {
      try {
        final String? croppedPath = await ImageCropperHelper.cropCampaignImage(file.path);
        // If user cancels cropping (croppedPath == null), still add original
        processed.add(XFile(croppedPath ?? file.path));
      } catch (e) {
        debugPrint("Lỗi crop ảnh: $e");
        // On crop error, add original image instead of crashing
        processed.add(file);
      }
    }

    if (!mounted) return;
    setState(() {
      _attachments.addAll(processed);
      _coverIndex ??= 0;
    });
  }

  Widget _buildMediaManager() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAndProcessImages,
          child: Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.image_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text("Tải ảnh lên", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text("${_attachments.length}/$_maxImages ảnh • Nhấn ★ để chọn ảnh bìa", style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
              ],
            ),
          ),
        ),
        if (_attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: List.generate(_attachments.length, (index) {
                bool isCover = _coverIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_attachments[index].path),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => Container(
                            width: 50, height: 50,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_attachments[index].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        icon: Icon(isCover ? Icons.star : Icons.star_border, color: Colors.orange),
                        onPressed: () => setState(() => _coverIndex = index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                        onPressed: () => setState(() {
                          _attachments.removeAt(index);
                          if (_coverIndex == index) {
                            _coverIndex = _attachments.isNotEmpty ? 0 : null;
                          } else if (_coverIndex != null && _coverIndex! > index) {
                            _coverIndex = _coverIndex! - 1;
                          }
                        }),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildInputFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildNumericField(TextEditingController controller, String suffix) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          border: InputBorder.none,
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.black12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount == 0) return '0';
    final parts = <String>[];
    String s = amount.toString();
    for (int i = s.length; i > 0; i -= 3) {
      parts.insert(0, s.substring(i > 3 ? i - 3 : 0, i));
    }
    return parts.join('.');
  }

  Widget _buildBottomNavigation() {
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                    _stepError = null;
                  });
                },
                child: const Text("Quay lại", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 4) {
                  if (_validateStep(_currentStep)) {
                    setState(() => _currentStep++);
                  }
                } else {
                  if (!_isSubmitting) _submitCampaign();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: webPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 4 ? "Gửi duyệt" : "Tiếp tục",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

