import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api/api_service.dart';
import '../core/providers/auth_provider.dart';
import '../core/utils/error_handler.dart';
import 'package:intl/intl.dart';

class EditCampaignScreen extends StatefulWidget {
  final int campaignId;
  const EditCampaignScreen({super.key, required this.campaignId});

  @override
  State<EditCampaignScreen> createState() => _EditCampaignScreenState();
}

class _EditCampaignScreenState extends State<EditCampaignScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thankMessageController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _aiPromptController = TextEditingController();
  final _bankCodeController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newAttachments = [];
  int? _coverIndex;
  bool _isGeneratingAI = false;
  bool _removeExistingCover = false;
  
  int? _selectedCategoryId;
  List<dynamic> _categories = [];
  String? _status;
  String? _rejectionReason;
  String? _coverImageUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getCategories(),
        _apiService.getCampaign(widget.campaignId),
      ]);

      if (results[0].statusCode == 200) {
        _categories = results[0].data;
      }

      if (results[1].statusCode == 200) {
        final data = results[1].data;
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _thankMessageController.text = data['thankMessage'] ?? '';
        _targetAmountController.text = (data['targetAmount'] ?? 0).toString();
        _selectedCategoryId = data['categoryId'];
        _status = data['status'];
        _rejectionReason = data['rejectionReason'];
        _coverImageUrl = data['coverImageUrl'];

        // Load Bank info from AuthProvider as default
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.bankAccount != null) {
          _bankCodeController.text = authProvider.bankAccount!.bankCode;
          _accountNumberController.text = authProvider.bankAccount!.accountNumber;
          _accountHolderNameController.text = authProvider.bankAccount!.accountHolderName;
        }
      }
    } catch (e) {
      debugPrint("Error loading campaign data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tiêu đề chiến dịch")));
      return false;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn danh mục")));
      return false;
    }
    final target = int.tryParse(_targetAmountController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mục tiêu huy động phải là số lớn hơn 0")));
      return false;
    }
    if (_descriptionController.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mô tả chi tiết phải có ít nhất 50 ký tự để người dùng tin tưởng")));
      return false;
    }
    if (_accountNumberController.text.trim().isEmpty || _bankCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng cung cấp đầy đủ thông tin tài khoản ngân hàng")));
      return false;
    }
    return true;
  }

  Future<void> _generateAIDescription() async {
    if (_aiPromptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập ý chính để AI viết hộ")));
      return;
    }

    setState(() => _isGeneratingAI = true);
    try {
      final response = await _apiService.generateDescription(_aiPromptController.text);
      if (response.statusCode == 200) {
        setState(() {
          _descriptionController.text = response.data['description'] ?? '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi AI: ${ErrorHandler.handle(e)}")));
    } finally {
      setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_validateForm()) return;
    setState(() => _isSaving = true);
    try {
      // 1. Upload new media if any
      List<Map<String, dynamic>> uploadedMedia = [];
      int? newCoverId;

      for (int i = 0; i < _newAttachments.length; i++) {
        final res = await _apiService.uploadMedia(File(_newAttachments[i].path), mediaType: "PHOTO", campaignId: widget.campaignId);
        if (res.statusCode == 200 || res.statusCode == 201) {
          final m = res.data;
          uploadedMedia.add(m);
          if (_coverIndex == i) newCoverId = m['id'];
        }
      }

      // 2. Update campaign details
      final response = await _apiService.updateCampaign(widget.campaignId, {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "thankMessage": _thankMessageController.text.trim().isNotEmpty ? _thankMessageController.text.trim() : null,
        "categoryId": _selectedCategoryId,
        "targetAmount": int.tryParse(_targetAmountController.text) ?? 0,
        if (newCoverId != null) "coverImage": newCoverId,
      });

      // 3. Update Bank Account if changed
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (_bankCodeController.text.trim() != authProvider.bankAccount?.bankCode ||
          _accountNumberController.text.trim() != authProvider.bankAccount?.accountNumber) {
        await authProvider.saveBankAccount(
          _bankCodeController.text.trim(),
          _accountNumberController.text.trim(),
          _accountHolderNameController.text.trim(),
        );
        await authProvider.fetchBankAccount(); // Refresh local bank info
      }

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu thay đổi thành công!")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi lưu thay đổi: ${ErrorHandler.handle(e)}")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("Chỉnh sửa chiến dịch", style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF84D43),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Lưu thay đổi", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status == 'REJECTED' && _rejectionReason != null)
              _buildRejectedBanner(),
            
            _buildSectionHeader("THÔNG TIN CƠ BẢN"),
            _buildCard([
              _buildTextField("Tiêu đề chiến dịch", _titleController),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildNumericField("Mục tiêu huy động (VNĐ)", _targetAmountController),
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader("MÔ TẢ CHI TIẾT"),
            _buildCard([
              _buildTextArea("Câu chuyện chiến dịch", _descriptionController, maxLines: 6),
              const SizedBox(height: 12),
              _buildAISection(),
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader("LỜI CẢM ƠN"),
            _buildCard([
              _buildTextArea("Tin nhắn gửi sau khi quyên góp", _thankMessageController, maxLines: 3),
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader("HÌNH ẢNH"),
            _buildCard([
               if (_coverImageUrl != null && !_removeExistingCover && _newAttachments.isEmpty)
                 Stack(
                   children: [
                     ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: Image.network(_coverImageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                     ),
                     Positioned(
                       top: 8,
                       right: 8,
                       child: GestureDetector(
                         onTap: () => setState(() => _removeExistingCover = true),
                         child: Container(
                           padding: const EdgeInsets.all(4),
                           decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                           child: const Icon(Icons.close, size: 18, color: Colors.white),
                         ),
                       ),
                     ),
                   ],
                 ),
               if (_coverImageUrl == null || _removeExistingCover || _newAttachments.isNotEmpty)
                 _buildMediaManager(),
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader("THÔNG TIN TÀI KHOẢN NHẬN QUỸ"),
            _buildCard([
              _buildTextField("Mã ngân hàng", _bankCodeController),
              const SizedBox(height: 12),
              _buildTextField("Số tài khoản", _accountNumberController),
              const SizedBox(height: 12),
              _buildTextField("Tên chủ tài khoản", _accountHolderNameController),
              const SizedBox(height: 12),
              const Text("Lưu ý: Bạn nên sử dụng tài khoản ngân hàng chính chủ để quá trình xác minh diễn ra nhanh hơn.", 
                style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
            ]),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text("Chiến dịch bị từ chối", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_rejectionReason!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6B7280), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildNumericField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, {int maxLines = 4}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Danh mục", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedCategoryId,
              isExpanded: true,
              items: _categories.map<DropdownMenuItem<int>>((cat) {
                return DropdownMenuItem<int>(
                  value: cat['id'],
                  child: Text(cat['name']),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAISection() {
    const Color webPrimary = Color(0xFFF84D43);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: webPrimary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: webPrimary.withAlpha(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: webPrimary, size: 20),
              const SizedBox(width: 8),
              const Text("AI Assistant", style: TextStyle(fontWeight: FontWeight.bold, color: webPrimary, fontSize: 13)),
              const Spacer(),
              if (_isGeneratingAI)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: webPrimary))
              else
                TextButton(
                  onPressed: _generateAIDescription,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: const Text("Tạo nội dung", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ],
          ),
          TextField(
            controller: _aiPromptController,
            decoration: const InputDecoration(
              hintText: "Nhập ý chính (VD: giúp bé bị bệnh...) để AI viết hộ",
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaManager() {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final List<XFile> picked = await _picker.pickMultiImage();
            if (picked.isNotEmpty) {
              setState(() {
                _newAttachments.addAll(picked);
                _coverIndex ??= 0;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.grey[400]),
                const SizedBox(height: 8),
                const Text("Tải ảnh hoặc video mới", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                const Text("Nhấn sao để chọn làm ảnh bìa mới", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ),
        if (_newAttachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: List.generate(_newAttachments.length, (index) {
                bool isCover = _coverIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(_newAttachments[index].path), width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_newAttachments[index].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      ),
                      IconButton(
                        icon: Icon(isCover ? Icons.star : Icons.star_border, color: Colors.orange, size: 20),
                        onPressed: () => setState(() => _coverIndex = index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                        onPressed: () => setState(() {
                          _newAttachments.removeAt(index);
                          if (_coverIndex == index) {
                            _coverIndex = _newAttachments.isNotEmpty ? 0 : null;
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
}
