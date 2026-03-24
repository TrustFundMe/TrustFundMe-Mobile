
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../core/utils/image_cropper_helper.dart';
import '../core/providers/auth_provider.dart';
import 'email_verification_screen.dart';
import 'feature_hub_placeholder_screen.dart';
import 'login_screen.dart';
import 'my_campaigns_screen.dart';
import 'chat_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Bank controllers
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  // Colors matching the design system
  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webEmerald = Color(0xFF1A685B);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webTextDark = Color(0xFF1F2937);
  static const Color webTextGray = Color(0xFF4B5563);
  static const Color webBorderGray = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phoneNumber ?? "";
    }
    
    // Fetch bank account if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await authProvider.fetchBankAccount();
      final bank = authProvider.bankAccount;
      if (bank != null) {
        _bankNameController.text = bank.bankCode;
        _accountNumberController.text = bank.accountNumber;
        _accountHolderController.text = bank.accountHolderName;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final String uploadPath =
          await ImageCropperHelper.cropAvatar(image.path) ?? image.path;
      final success = await authProvider.updateAvatar(uploadPath);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã cập nhật ảnh đại diện.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final bank = authProvider.bankAccount;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          "Hồ sơ của tôi",
          style: TextStyle(color: webTextDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.of(context).canPop() 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: webTextDark),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                // Cancel
                setState(() {
                  _isEditing = false;
                  _nameController.text = user.fullName;
                  _phoneController.text = user.phoneNumber ?? "";
                  if (bank != null) {
                    _bankNameController.text = bank.bankCode;
                    _accountNumberController.text = bank.accountNumber;
                    _accountHolderController.text = bank.accountHolderName;
                  }
                });
              } else {
                // Toggle Edit
                setState(() => _isEditing = true);
              }
            },
            child: Text(
              _isEditing ? "Hủy" : "Chỉnh sửa",
              style: const TextStyle(color: webPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: webPrimary.withOpacity(0.2), width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: user.avatarUrl != null 
                              ? NetworkImage(user.avatarUrl!) 
                              : null,
                          child: user.avatarUrl == null
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (authProvider.isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                      if (!authProvider.isLoading)
                        GestureDetector(
                          onTap: _pickImage,
                          child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: webPrimary,
                            child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: webTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: webEmerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: const TextStyle(
                        color: webEmerald,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Profile Information Section
            _buildSectionTitle("THÔNG TIN CÁ NHÂN"),
            _buildProfileSection([
              _buildEditableRow(
                icon: Icons.person_outline,
                label: "Họ và tên",
                controller: _nameController,
                isEditing: _isEditing,
              ),
              _buildEditableRow(
                icon: Icons.phone_android_outlined,
                label: "Số điện thoại",
                controller: _phoneController,
                isEditing: _isEditing,
                keyboardType: TextInputType.phone,
              ),
              _buildEmailRow(
                email: user.email,
                emailVerified: user.verified,
              ),
            ]),

            const SizedBox(height: 16),

            // Bank Details Section
            _buildSectionTitle("THIẾT LẬP TÀI CHÍNH"),
            _buildProfileSection([
              _buildEditableRow(
                icon: Icons.account_balance_outlined,
                label: "Ngân hàng liên kết",
                controller: _bankNameController,
                isEditing: _isEditing,
                hintText: "Nhập tên ngân hàng (VD: MB Bank)",
              ),
              _buildEditableRow(
                icon: Icons.account_circle_outlined,
                label: "Tên chủ tài khoản",
                controller: _accountHolderController,
                isEditing: _isEditing,
                hintText: "Nhập họ và tên",
              ),
              _buildEditableRow(
                icon: Icons.numbers,
                label: "Số tài khoản",
                controller: _accountNumberController,
                isEditing: _isEditing,
                keyboardType: TextInputType.number,
                hintText: "Nhập số tài khoản/thẻ",
              ),
            ]),

            const SizedBox(height: 24),

            // Save changes button (only visible when editing)
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    if (authProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          authProvider.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: authProvider.isLoading ? null : () async {
                        final String fullName = _nameController.text.trim();
                        final String phone = _phoneController.text.trim();
                        final String bankName = _bankNameController.text.trim();
                        final String accountNumber = _accountNumberController.text.trim();
                        final String accountHolder = _accountHolderController.text.trim();

                        if (fullName.isEmpty) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Họ và tên không được để trống.")),
                          );
                          return;
                        }

                        final bool hasAnyBankField = bankName.isNotEmpty ||
                            accountNumber.isNotEmpty ||
                            accountHolder.isNotEmpty;
                        final bool hasAllBankFields = bankName.isNotEmpty &&
                            accountNumber.isNotEmpty &&
                            accountHolder.isNotEmpty;

                        if (hasAnyBankField && !hasAllBankFields) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Vui lòng nhập đầy đủ 3 trường thông tin ngân hàng."),
                            ),
                          );
                          return;
                        }

                        if (accountNumber.isNotEmpty &&
                            !RegExp(r'^[0-9]{6,30}$').hasMatch(accountNumber)) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Số tài khoản chỉ gồm chữ số (6-30 ký tự)."),
                            ),
                          );
                          return;
                        }

                        // 1. Update Profile info
                        final profileSuccess = await authProvider.updateProfile(
                          fullName,
                          phone,
                        );
                        
                        // 2. Update Bank info
                        bool bankSuccess = true;
                        if (hasAllBankFields) {
                          bankSuccess = await authProvider.saveBankAccount(
                            bankName,
                            accountNumber,
                            accountHolder,
                          );
                        }

                        if (profileSuccess && bankSuccess) {
                          if (!context.mounted) return;
                          setState(() => _isEditing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Đã cập nhật hồ sơ và thông tin ngân hàng!"),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: webPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: webPrimary.withOpacity(0.4),
                      ),
                      child: authProvider.isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Lưu thay đổi",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Quick Access Section
            _buildSectionTitle("TRUY CẬP NHANH"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildQuickAction(
                    icon: Icons.favorite_outline,
                    title: "Impact",
                    onTap: () => _openFeaturePlaceholder(
                      title: "Impact",
                      description: "Tính năng Impact sẽ sớm ra mắt để bạn theo dõi tác động của mình.",
                      icon: Icons.favorite_outline,
                    ),
                  ),
                  _buildQuickAction(
                    icon: Icons.chat_bubble_outline,
                    title: "Chat",
                    onTap: () {
                      debugPrint("ProfileScreen: Chat button tapped!");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Đang mở hộp thoại tin nhắn..."), duration: Duration(seconds: 1),),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatListScreen()),
                      );
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.folder_open_outlined,
                    title: "Chiến dịch của tôi",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyCampaignsScreen()),
                      );
                    },
                  ),
                  _buildQuickAction(
                    icon: Icons.calendar_month_outlined,
                    title: "Lịch hẹn",
                    onTap: () => _openFeaturePlaceholder(
                      title: "Lịch hẹn",
                      description: "Lịch hẹn tư vấn và theo dõi chiến dịch sẽ có trong bản mobile kế tiếp.",
                      icon: Icons.calendar_month_outlined,
                    ),
                  ),
                  _buildQuickAction(
                    icon: Icons.flag_outlined,
                    title: "Báo cáo",
                    onTap: () => _openFeaturePlaceholder(
                      title: "Báo cáo",
                      description: "Báo cáo bài viết và nội dung cộng đồng sẽ được tối ưu cho mobile.",
                      icon: Icons.flag_outlined,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Log Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton.icon(
                onPressed: () {
                  authProvider.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  "Đăng xuất",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 12, top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9CA3AF),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: webBorderGray),
      ),
      child: Column(children: children),
    );
  }

  /// Email + trạng thái xác thực (cùng cờ `verified` từ BE sau verify-email).
  Widget _buildEmailRow({
    required String email,
    required bool emailVerified,
  }) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: webBgGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.email_outlined, size: 20, color: webTextGray),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Email',
                  style: TextStyle(fontSize: 12, color: webTextGray),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: webTextDark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: emailVerified
                            ? webEmerald.withValues(alpha: 0.12)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: emailVerified
                              ? webEmerald.withValues(alpha: 0.35)
                              : const Color(0xFFFDBA74),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            emailVerified
                                ? Icons.mark_email_read_outlined
                                : Icons.mark_email_unread_outlined,
                            size: 16,
                            color: emailVerified ? webEmerald : const Color(0xFFC2410C),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            emailVerified
                                ? 'Đã xác thực email'
                                : 'Chưa xác thực email',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: emailVerified ? webEmerald : const Color(0xFF9A3412),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!emailVerified)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final bool? ok = await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => EmailVerificationScreen(
                                email: email,
                                replaceAppOnSuccess: false,
                              ),
                            ),
                          );
                          if (!mounted) return;
                          if (ok == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã xác thực email.'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Xác thực ngay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: webPrimary,
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
    );
  }

  Widget _buildStaticRow({required IconData icon, required String label, required String value, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: webBgGray, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: webTextGray),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: webTextGray)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? webTextDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: webBgGray, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: isEditing ? webPrimary : webTextGray),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: webTextGray)),
                const SizedBox(height: 2),
                if (isEditing)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: webTextDark),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                      hintText: hintText ?? "Nhập thông tin",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.normal),
                    ),
                  )
                else
                  Text(
                    controller.text.isEmpty ? "Chưa cập nhật" : controller.text,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: webTextDark),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFeaturePlaceholder({
    required String title,
    required String description,
    required IconData icon,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeatureHubPlaceholderScreen(
          title: title,
          description: description,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: webBorderGray),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: webPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: webTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

