import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/campaign_service.dart';
import '../../../core/api/media_service.dart';
import '../../../core/models/campaign_category_model.dart';
import '../../../core/models/new_campaign_state.dart';
import '../../../core/utils/error_handler.dart';

/// Step 2: Thông tin chiến dịch — form nhập liệu cốt lõi.
class Step2CampaignForm extends StatefulWidget {
  final NewCampaignState campaignState;
  final ValueChanged<bool> onValidChanged;

  const Step2CampaignForm({
    super.key,
    required this.campaignState,
    required this.onValidChanged,
  });

  @override
  State<Step2CampaignForm> createState() => _Step2CampaignFormState();
}

class _Step2CampaignFormState extends State<Step2CampaignForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final CampaignService _campaignService = CampaignService();
  final MediaService _mediaService = MediaService();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _thankCtrl;

  // Data
  List<CampaignCategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  bool _isUploadingImage = false;
  String? _error;

  // Selections
  CampaignCategoryModel? _selectedCategory;
  String _selectedRegion = '';
  String _selectedBeneficiary = '';
  DateTime? _startDate;
  DateTime? _endDate;
  File? _coverImageFile;

  static const List<String> _regions = [
    'Miền Bắc',
    'Miền Trung',
    'Miền Nam',
    'Tây Nguyên',
    'Toàn quốc',
  ];

  static const List<String> _beneficiaryTypes = [
    'Trẻ em',
    'Người cao tuổi',
    'Người khuyết tật',
    'Gia đình nghèo',
    'Cộng đồng',
    'Môi trường',
    'Giáo dục',
    'Y tế',
    'Khác',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final core = widget.campaignState.campaignCore;
    _titleCtrl = TextEditingController(text: core.title);
    _objectiveCtrl = TextEditingController(text: core.objective);
    _thankCtrl = TextEditingController(text: core.thankMessage);
    _selectedRegion = core.region;
    _selectedBeneficiary = core.beneficiaryType;

    if (core.startDate.isNotEmpty) {
      _startDate = DateTime.tryParse(core.startDate);
    }
    if (core.endDate.isNotEmpty) {
      _endDate = DateTime.tryParse(core.endDate);
    }

    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _objectiveCtrl.dispose();
    _thankCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _campaignService.getCategories();
      if (response.statusCode == 200 && response.data is List) {
        _categories = (response.data as List)
            .map((e) => CampaignCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Restore selection
        final core = widget.campaignState.campaignCore;
        if (core.categoryId != null) {
          _selectedCategory = _categories.cast<CampaignCategoryModel?>().firstWhere(
                (c) => c!.id == core.categoryId,
                orElse: () => null,
              );
        }
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    if (mounted) {
      setState(() => _isLoadingCategories = false);
      _validateAndNotify();
    }
  }

  void _syncToState() {
    final core = widget.campaignState.campaignCore;
    core.title = _titleCtrl.text.trim();
    core.objective = _objectiveCtrl.text.trim();
    core.thankMessage = _thankCtrl.text.trim();
    core.category = _selectedCategory?.name ?? '';
    core.categoryId = _selectedCategory?.id;
    core.region = _selectedRegion;
    core.beneficiaryType = _selectedBeneficiary;
    core.startDate = _startDate != null
        ? DateFormat('yyyy-MM-dd').format(_startDate!)
        : '';
    core.endDate = _endDate != null
        ? DateFormat('yyyy-MM-dd').format(_endDate!)
        : '';
  }

  void _validateAndNotify() {
    _syncToState();
    final errors = widget.campaignState.campaignCore.validate();
    widget.onValidChanged(errors.isEmpty);
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Auto-adjust end date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 30));
        }
      });
      _validateAndNotify();
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final minDate = _startDate ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? minDate.add(const Duration(days: 30)),
      firstDate: minDate,
      lastDate: now.add(const Duration(days: 730)),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _validateAndNotify();
    }
  }

  Future<void> _pickCoverImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _coverImageFile = File(image.path);
      _isUploadingImage = true;
    });

    try {
      final response = await _mediaService.uploadMedia(
        File(image.path),
        mediaType: 'IMAGE',
        description: 'Campaign cover image',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = response.data['url'] as String? ??
            response.data['fileUrl'] as String? ??
            '';
        widget.campaignState.campaignCore.coverImageUrl = url;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload ảnh thất bại: ${ErrorHandler.handle(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isUploadingImage = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chọn ngày';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header ────────────────────────────────────────────────
          Text(
            'Thông tin chiến dịch',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Điền đầy đủ thông tin cho chiến dịch gây quỹ của bạn.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // ── Tên chiến dịch ────────────────────────────────────────
          _buildSectionLabel('Tên chiến dịch *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleCtrl,
            decoration: _inputDecoration(
              hint: 'VD: Xây cầu cho bản làng A...',
              icon: Icons.campaign_outlined,
            ),
            maxLength: 150,
            onChanged: (_) => _validateAndNotify(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Không được để trống';
              if (v.trim().length < 10) return 'Tối thiểu 10 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Mục tiêu / Mô tả ──────────────────────────────────────
          _buildSectionLabel('Mục tiêu gây quỹ *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _objectiveCtrl,
            decoration: _inputDecoration(
              hint: 'Mô tả chi tiết mục đích, kế hoạch sử dụng quỹ...',
              icon: Icons.description_outlined,
            ),
            maxLines: 5,
            maxLength: 2000,
            onChanged: (_) => _validateAndNotify(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Không được để trống';
              if (v.trim().length < 20) return 'Tối thiểu 20 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Danh mục ──────────────────────────────────────────────
          _buildSectionLabel('Danh mục *'),
          const SizedBox(height: 8),
          _isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<CampaignCategoryModel>(
                  value: _selectedCategory,
                  decoration: _inputDecoration(
                    hint: 'Chọn danh mục',
                    icon: Icons.category_outlined,
                  ),
                  items: _categories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.name),
                          ))
                      .toList(),
                  onChanged: (cat) {
                    setState(() => _selectedCategory = cat);
                    _validateAndNotify();
                  },
                  validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                ),
          const SizedBox(height: 16),

          // ── Khu vực ───────────────────────────────────────────────
          _buildSectionLabel('Khu vực *'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRegion.isEmpty ? null : _selectedRegion,
            decoration: _inputDecoration(
              hint: 'Chọn khu vực',
              icon: Icons.location_on_outlined,
            ),
            items: _regions
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedRegion = v ?? '');
              _validateAndNotify();
            },
            validator: (v) => v == null || v.isEmpty ? 'Vui lòng chọn khu vực' : null,
          ),
          const SizedBox(height: 16),

          // ── Đối tượng thụ hưởng ────────────────────────────────────
          _buildSectionLabel('Đối tượng thụ hưởng *'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBeneficiary.isEmpty ? null : _selectedBeneficiary,
            decoration: _inputDecoration(
              hint: 'Chọn đối tượng',
              icon: Icons.people_outline,
            ),
            items: _beneficiaryTypes
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedBeneficiary = v ?? '');
              _validateAndNotify();
            },
            validator: (v) =>
                v == null || v.isEmpty ? 'Vui lòng chọn đối tượng' : null,
          ),
          const SizedBox(height: 16),

          // ── Thời gian ─────────────────────────────────────────────
          _buildSectionLabel('Thời gian chiến dịch *'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Ngày bắt đầu',
                  value: _formatDate(_startDate),
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: 'Ngày kết thúc',
                  value: _formatDate(_endDate),
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Ảnh bìa ───────────────────────────────────────────────
          _buildSectionLabel('Ảnh bìa chiến dịch'),
          const SizedBox(height: 8),
          _buildCoverImagePicker(),
          const SizedBox(height: 24),

          // ── Lời cảm ơn ────────────────────────────────────────────
          _buildSectionLabel('Lời cảm ơn nhà tài trợ'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _thankCtrl,
            decoration: _inputDecoration(
              hint: 'Lời nhắn gửi đến các nhà tài trợ...',
              icon: Icons.favorite_border,
            ),
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => _validateAndNotify(),
          ),
          const SizedBox(height: 32),

          // ── Error ─────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: value == 'Chọn ngày'
                          ? Colors.grey.shade400
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickCoverImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          color: Colors.grey.shade100,
        ),
        child: _isUploadingImage
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Đang tải ảnh lên...'),
                  ],
                ),
              )
            : _coverImageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_coverImageFile!, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                              onPressed: _pickCoverImage,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Nhấn để chọn ảnh bìa',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      Text(
                        'Khuyến nghị: 1920x1080',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
      ),
    );
  }
}
