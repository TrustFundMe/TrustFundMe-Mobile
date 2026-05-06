import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/campaign_service.dart';
import '../../../core/api/media_service.dart';
import '../../../core/models/campaign_category_model.dart';
import '../../../core/models/new_campaign_state.dart';
import '../../../core/utils/error_handler.dart';

/// Step 2: Thông tin chiến dịch — đồng bộ UI với web.
/// Fields: Tên, Danh mục, Mục tiêu/Mô tả, Lời cảm ơn, Multi-image upload.
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

  // ── Colors giống web ────────────────────────────────────────────────
  static const Color _labelColor = Color(0xFF374151);       // gray-700
  static const Color _borderColor = Color(0xFFD1D5DB);      // gray-300
  static const Color _focusColor = Color(0xFFEA580C);       // orange
  static const Color _sectionHeaderColor = Color(0xFF1E3A5F); // dark blue

  // ── Controllers ─────────────────────────────────────────────────────
  late final TextEditingController _titleCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _thankCtrl;

  // ── Data ────────────────────────────────────────────────────────────
  List<CampaignCategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  String? _error;

  // ── Selections ──────────────────────────────────────────────────────
  CampaignCategoryModel? _selectedCategory;

  // ── Multi-image state ───────────────────────────────────────────────
  static const int _maxImages = 10;

  /// File cục bộ đã chọn, đồng bộ index với _uploadedMediaIds.
  final List<File> _imageFiles = [];

  /// Media IDs đã upload thành công (null = đang upload).
  final List<int?> _uploadedMediaIds = [];

  /// Index ảnh đang upload (-1 = không upload).
  int _uploadingIndex = -1;

  /// Index ảnh được chọn làm cover.
  int _coverIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final core = widget.campaignState.campaignCore;
    _titleCtrl = TextEditingController(text: core.title);
    _objectiveCtrl = TextEditingController(text: core.objective);
    _thankCtrl = TextEditingController(text: core.thankMessage);
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _objectiveCtrl.dispose();
    _thankCtrl.dispose();
    super.dispose();
  }

  // ── Load categories từ API ──────────────────────────────────────────
  Future<void> _loadCategories() async {
    try {
      final response = await _campaignService.getCategories();
      if (response.statusCode == 200 && response.data is List) {
        _categories = (response.data as List)
            .map((e) =>
                CampaignCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Restore selection
        final core = widget.campaignState.campaignCore;
        if (core.categoryId != null) {
          _selectedCategory =
              _categories.cast<CampaignCategoryModel?>().firstWhere(
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

  // ── Sync state ──────────────────────────────────────────────────────
  void _syncToState() {
    final core = widget.campaignState.campaignCore;
    core.title = _titleCtrl.text.trim();
    core.objective = _objectiveCtrl.text.trim();
    core.thankMessage = _thankCtrl.text.trim();
    core.category = _selectedCategory?.name ?? '';
    core.categoryId = _selectedCategory?.id;

    // Set default values cho fields bỏ UI (giữ trong model)
    if (core.region.isEmpty) core.region = 'Toàn quốc';
    if (core.beneficiaryType.isEmpty) core.beneficiaryType = 'Cộng đồng';

    // Multi-image: lưu mediaIds đã upload thành công
    core.mediaIds = _uploadedMediaIds
        .where((id) => id != null)
        .map((id) => id!)
        .toList();

    // Cover media ID
    if (_imageFiles.isNotEmpty &&
        _coverIndex < _uploadedMediaIds.length &&
        _uploadedMediaIds[_coverIndex] != null) {
      core.coverMediaId = _uploadedMediaIds[_coverIndex];
    }
  }

  void _validateAndNotify() {
    _syncToState();
    final errors = widget.campaignState.campaignCore.validate();
    widget.onValidChanged(errors.isEmpty);
  }

  // ── Multi-image picker ──────────────────────────────────────────────
  Future<void> _pickImages() async {
    final int remaining = _maxImages - _imageFiles.length;
    if (remaining <= 0) {
      _showSnack('Đã đạt tối đa $_maxImages ảnh');
      return;
    }

    final List<XFile> picked = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    for (final xFile in toAdd) {
      final file = File(xFile.path);
      final index = _imageFiles.length;
      setState(() {
        _imageFiles.add(file);
        _uploadedMediaIds.add(null); // placeholder
      });
      _uploadSingleImage(file, index);
    }
  }

  Future<void> _uploadSingleImage(File file, int index) async {
    setState(() => _uploadingIndex = index);
    try {
      final response = await _mediaService.uploadMedia(
        file,
        mediaType: 'PHOTO',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final int? mediaId = (data['id'] as num?)?.toInt() ??
            (data['mediaId'] as num?)?.toInt();
        if (mounted && index < _uploadedMediaIds.length) {
          setState(() => _uploadedMediaIds[index] = mediaId);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Upload ảnh thất bại: ${ErrorHandler.handle(e)}');
      }
    }
    if (mounted) {
      setState(() => _uploadingIndex = -1);
      _validateAndNotify();
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      _uploadedMediaIds.removeAt(index);
      // Điều chỉnh coverIndex
      if (_coverIndex >= _imageFiles.length) {
        _coverIndex = _imageFiles.isEmpty ? 0 : _imageFiles.length - 1;
      } else if (_coverIndex > index) {
        _coverIndex--;
      } else if (_coverIndex == index) {
        _coverIndex = 0;
      }
    });
    _validateAndNotify();
  }

  void _setCover(int index) {
    setState(() => _coverIndex = index);
    _validateAndNotify();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header ─────────────────────────────────────────────
          Text(
            'Thông tin chiến dịch',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _sectionHeaderColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Điền đầy đủ thông tin cho chiến dịch gây quỹ của bạn.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // ── 1. Tên chiến dịch ──────────────────────────────────
          _buildSectionLabel('Tên chiến dịch', required: true),
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
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ── 2. Danh mục ────────────────────────────────────────
          _buildSectionLabel('Danh mục', required: true),
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
                  validator: (v) =>
                      v == null ? 'Vui lòng chọn danh mục' : null,
                ),
          const SizedBox(height: 20),

          // ── 3. Mục tiêu / Mô tả ───────────────────────────────
          _buildSectionLabel('Mục tiêu gây quỹ', required: true),
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
              return null;
            },
          ),
          const SizedBox(height: 20),

          // ── 4. Lời cảm ơn (required giống web) ────────────────
          _buildSectionLabel('Lời cảm ơn nhà tài trợ', required: true),
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
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Không được để trống';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── 5. Multi-image upload ──────────────────────────────
          _buildSectionLabel('Ảnh chiến dịch', required: true),
          const SizedBox(height: 4),
          Text(
            'Tải lên tối đa $_maxImages ảnh. Nhấn ★ để chọn ảnh bìa.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          _buildImageGrid(),
          const SizedBox(height: 32),

          // ── Error ──────────────────────────────────────────────
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

  // ══════════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════════════════

  /// Section label giống web (gray-700, semibold).
  Widget _buildSectionLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: _labelColor,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ]
            : null,
      ),
    );
  }

  /// Input decoration giống web color scheme.
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: _labelColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _focusColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  // ── Multi-image grid ────────────────────────────────────────────────
  Widget _buildImageGrid() {
    final children = <Widget>[];

    // Ảnh đã chọn
    for (int i = 0; i < _imageFiles.length; i++) {
      children.add(_buildImageTile(i));
    }

    // Nút thêm ảnh
    if (_imageFiles.length < _maxImages) {
      children.add(_buildAddImageTile());
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: children,
    );
  }

  Widget _buildImageTile(int index) {
    final isCover = index == _coverIndex;
    final isUploading =
        _uploadedMediaIds[index] == null && _uploadingIndex == index;
    final isUploaded = _uploadedMediaIds[index] != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh preview
          Image.file(_imageFiles[index], fit: BoxFit.cover),

          // Overlay khi đang upload
          if (isUploading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Cover badge
          if (isCover && isUploaded)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _focusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'Bìa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons (star + delete)
          Positioned(
            top: 4,
            right: 4,
            child: Column(
              children: [
                // Set as cover
                if (!isCover && isUploaded)
                  _buildCircleButton(
                    icon: Icons.star_border,
                    onTap: () => _setCover(index),
                    color: Colors.white,
                    bgColor: Colors.black54,
                  ),
                const SizedBox(height: 4),
                // Delete
                _buildCircleButton(
                  icon: Icons.close,
                  onTap: () => _removeImage(index),
                  color: Colors.white,
                  bgColor: Colors.red.shade600,
                ),
              ],
            ),
          ),

          // Upload success indicator
          if (isUploaded && !isCover)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),

          // Tap to set cover
          if (!isCover && isUploaded)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _setCover(index),
                ),
              ),
            ),

          // Border highlight for cover
          if (isCover)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _focusColor, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddImageTile() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _borderColor,
            style: BorderStyle.solid,
            width: 1.5,
          ),
          color: Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              'Thêm ảnh',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_imageFiles.length}/$_maxImages',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
