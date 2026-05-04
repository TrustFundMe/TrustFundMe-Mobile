import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/kyc_service.dart';
import '../../core/models/kyc_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/error_handler.dart';

/// Màn hình xác minh danh tính (KYC).
///
/// - NOT_SUBMITTED / REJECTED → hiển thị form nhập + upload ảnh.
/// - PENDING → thông báo "Đang chờ duyệt".
/// - APPROVED → thông báo "Đã xác minh ✓".
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final KycService _kycService = KycService();

  // Colors matching the design system
  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webEmerald = Color(0xFF1A685B);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webTextDark = Color(0xFF1F2937);
  static const Color webTextGray = Color(0xFF4B5563);
  static const Color webBorderGray = Color(0xFFE5E7EB);
  static const Color webAmber = Color(0xFFF59E0B);

  // Loading & error
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // KYC data
  KycModel? _kycData;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtl = TextEditingController();
  final _dobCtl = TextEditingController();
  final _idNumberCtl = TextEditingController();
  String _gender = 'Nam';

  // Image paths
  String? _frontImagePath;
  String? _backImagePath;
  String? _selfieImagePath;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _dobCtl.dispose();
    _idNumberCtl.dispose();
    super.dispose();
  }

  Future<void> _loadKycStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _kycService.getMyKyc();
      if (response.statusCode == 200 && response.data != null) {
        _kycData = KycModel.fromJson(response.data as Map<String, dynamic>);
        // Pre-fill form nếu đã từng submit (ví dụ bị reject)
        if (_kycData != null &&
            (_kycData!.status == 'REJECTED' ||
                _kycData!.status == 'NOT_SUBMITTED')) {
          _fullNameCtl.text = _kycData!.fullName;
          _dobCtl.text = _kycData!.dateOfBirth;
          _idNumberCtl.text = _kycData!.idNumber;
          if (_kycData!.gender.isNotEmpty) {
            _gender = _kycData!.gender;
          }
        }
      }
    } catch (e) {
      // 404 = chưa submit KYC → coi như NOT_SUBMITTED
      final errorMsg = ErrorHandler.handle(e);
      if (!errorMsg.contains('404')) {
        _error = errorMsg;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String get _currentStatus {
    return _kycData?.status ?? 'NOT_SUBMITTED';
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      switch (type) {
        case 'FRONT':
          _frontImagePath = image.path;
          break;
        case 'BACK':
          _backImagePath = image.path;
          break;
        case 'SELFIE':
          _selfieImagePath = image.path;
          break;
      }
    });
  }

  Future<void> _pickImageFromGallery(String type) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() {
      switch (type) {
        case 'FRONT':
          _frontImagePath = image.path;
          break;
        case 'BACK':
          _backImagePath = image.path;
          break;
        case 'SELFIE':
          _selfieImagePath = image.path;
          break;
      }
    });
  }

  void _showImageSourcePicker(String type, String label) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: webTextDark,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: webPrimary),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: webPrimary),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery(type);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      _dobCtl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frontImagePath == null &&
        (_kycData?.frontImageUrl == null || _kycData!.frontImageUrl!.isEmpty)) {
      _showError('Vui lòng chụp ảnh mặt trước CCCD.');
      return;
    }
    if (_backImagePath == null &&
        (_kycData?.backImageUrl == null || _kycData!.backImageUrl!.isEmpty)) {
      _showError('Vui lòng chụp ảnh mặt sau CCCD.');
      return;
    }
    if (_selfieImagePath == null &&
        (_kycData?.selfieImageUrl == null ||
            _kycData!.selfieImageUrl!.isEmpty)) {
      _showError('Vui lòng chụp ảnh selfie.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // 1. Upload images (if newly picked)
      String? frontUrl = _kycData?.frontImageUrl;
      String? backUrl = _kycData?.backImageUrl;
      String? selfieUrl = _kycData?.selfieImageUrl;

      if (_frontImagePath != null) {
        final res = await _kycService.uploadKycDocument(
          _frontImagePath!,
          docType: 'FRONT_ID',
          userId: user.id,
        );
        frontUrl = res.data['url'] as String? ?? res.data.toString();
      }
      if (_backImagePath != null) {
        final res = await _kycService.uploadKycDocument(
          _backImagePath!,
          docType: 'BACK_ID',
          userId: user.id,
        );
        backUrl = res.data['url'] as String? ?? res.data.toString();
      }
      if (_selfieImagePath != null) {
        final res = await _kycService.uploadKycDocument(
          _selfieImagePath!,
          docType: 'SELFIE',
          userId: user.id,
        );
        selfieUrl = res.data['url'] as String? ?? res.data.toString();
      }

      // 2. Submit/Update KYC
      final payload = {
        'fullName': _fullNameCtl.text.trim(),
        'dateOfBirth': _dobCtl.text.trim(),
        'gender': _gender,
        'idNumber': _idNumberCtl.text.trim(),
        'frontImageUrl': frontUrl,
        'backImageUrl': backUrl,
        'selfieImageUrl': selfieUrl,
      };

      if (_currentStatus == 'REJECTED' && _kycData?.id != null) {
        await _kycService.updateKyc(user.id, payload);
      } else {
        await _kycService.submitKyc(user.id, payload);
      }

      // 3. Reload status
      await _loadKycStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi hồ sơ KYC thành công! Vui lòng chờ duyệt.'),
            backgroundColor: webEmerald,
          ),
        );
      }
    } catch (e) {
      _error = ErrorHandler.handle(e);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          'Xác minh danh tính',
          style: TextStyle(color: webTextDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: webTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentStatus) {
      case 'APPROVED':
        return _buildApprovedView();
      case 'PENDING':
        return _buildPendingView();
      case 'NOT_SUBMITTED':
      case 'REJECTED':
      default:
        return _buildFormView();
    }
  }

  // ─── APPROVED ────────────────────────────────────────────────────────────────
  Widget _buildApprovedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: webEmerald.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user,
                size: 80,
                color: webEmerald,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Đã xác minh ✓',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: webEmerald,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Danh tính của bạn đã được xác minh thành công.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: webTextGray,
              ),
            ),
            if (_kycData != null) ...[
              const SizedBox(height: 32),
              _buildInfoCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── PENDING ─────────────────────────────────────────────────────────────────
  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: webAmber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 80,
                color: webAmber,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Đang chờ duyệt',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: webAmber,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hồ sơ KYC của bạn đang được xem xét.\nVui lòng chờ trong 1–3 ngày làm việc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: webTextGray,
              ),
            ),
            if (_kycData != null) ...[
              const SizedBox(height: 32),
              _buildInfoCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: webBorderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin đã gửi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: webTextDark,
            ),
          ),
          const Divider(),
          _infoRow('Họ tên', _kycData!.fullName),
          _infoRow('Ngày sinh', _kycData!.dateOfBirth),
          _infoRow('Giới tính', _kycData!.gender),
          _infoRow('Số CCCD', _kycData!.idNumber),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: webTextGray),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: webTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FORM (NOT_SUBMITTED / REJECTED) ─────────────────────────────────────────
  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reject notice
            if (_currentStatus == 'REJECTED') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Hồ sơ bị từ chối',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (_kycData?.rejectReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Lý do: ${_kycData!.rejectReason}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Vui lòng cập nhật lại hồ sơ và gửi lại.',
                      style: TextStyle(fontSize: 13, color: webTextGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: webBorderGray),
              ),
              child: const Column(
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 48, color: webPrimary),
                  SizedBox(height: 12),
                  Text(
                    'Xác minh danh tính (KYC)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: webTextDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hoàn tất xác minh để tạo chiến dịch gây quỹ và tăng độ tin cậy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: webTextGray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Error
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),

            // Form fields
            _buildSectionLabel('Thông tin cá nhân'),
            const SizedBox(height: 12),

            _buildFormCard([
              _buildTextField(
                controller: _fullNameCtl,
                label: 'Họ và tên (theo CCCD)',
                icon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
              ),
              const Divider(height: 1),
              GestureDetector(
                onTap: _selectDateOfBirth,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _dobCtl,
                    label: 'Ngày sinh (dd/mm/yyyy)',
                    icon: Icons.calendar_today_outlined,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Vui lòng chọn ngày sinh'
                        : null,
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: webBgGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.wc_outlined, size: 20, color: webTextGray),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Giới tính',
                      style: TextStyle(fontSize: 13, color: webTextGray),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _gender,
                      underline: const SizedBox(),
                      items: ['Nam', 'Nữ', 'Khác']
                          .map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(
                                  g,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: webTextDark,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildTextField(
                controller: _idNumberCtl,
                label: 'Số CCCD/CMND',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập số CCCD';
                  }
                  if (!RegExp(r'^[0-9]{9,12}$').hasMatch(v.trim())) {
                    return 'Số CCCD gồm 9-12 chữ số';
                  }
                  return null;
                },
              ),
            ]),

            const SizedBox(height: 24),
            _buildSectionLabel('Ảnh xác minh'),
            const SizedBox(height: 12),

            _buildImagePicker(
              label: 'Mặt trước CCCD',
              icon: Icons.credit_card,
              path: _frontImagePath,
              existingUrl: _kycData?.frontImageUrl,
              onTap: () => _showImageSourcePicker('FRONT', 'Ảnh mặt trước CCCD'),
            ),
            const SizedBox(height: 12),
            _buildImagePicker(
              label: 'Mặt sau CCCD',
              icon: Icons.credit_card,
              path: _backImagePath,
              existingUrl: _kycData?.backImageUrl,
              onTap: () => _showImageSourcePicker('BACK', 'Ảnh mặt sau CCCD'),
            ),
            const SizedBox(height: 12),
            _buildImagePicker(
              label: 'Ảnh selfie',
              icon: Icons.face,
              path: _selfieImagePath,
              existingUrl: _kycData?.selfieImageUrl,
              onTap: () => _showImageSourcePicker('SELFIE', 'Ảnh selfie xác minh'),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitKyc,
                style: ElevatedButton.styleFrom(
                  backgroundColor: webPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: webPrimary.withOpacity(0.4),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _currentStatus == 'REJECTED'
                            ? 'Gửi lại hồ sơ'
                            : 'Gửi hồ sơ KYC',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF9CA3AF),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: webBorderGray),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: webBgGray,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: webTextGray),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: webTextDark,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 13, color: webTextGray),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required IconData icon,
    required String? path,
    String? existingUrl,
    required VoidCallback onTap,
  }) {
    final bool hasImage = path != null ||
        (existingUrl != null && existingUrl.isNotEmpty);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? webEmerald.withOpacity(0.5) : webBorderGray,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: hasImage
                    ? webEmerald.withOpacity(0.1)
                    : webBgGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: path != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                      ),
                    )
                  : existingUrl != null && existingUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            existingUrl,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                            errorBuilder: (_, __, ___) =>
                                Icon(icon, size: 28, color: webTextGray),
                          ),
                        )
                      : Icon(icon, size: 28, color: webTextGray),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: webTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasImage
                        ? 'Đã chọn ✓ — Nhấn để thay đổi'
                        : 'Nhấn để chụp hoặc chọn ảnh',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasImage ? webEmerald : webTextGray,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasImage ? Icons.check_circle : Icons.add_a_photo_outlined,
              color: hasImage ? webEmerald : webTextGray,
            ),
          ],
        ),
      ),
    );
  }
}
