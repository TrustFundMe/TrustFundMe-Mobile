import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/utils/image_cropper_helper.dart';
import '../appointment_schedule_screen.dart';
import '../chat_list_screen.dart';
import '../kyc/kyc_screen.dart';
import '../login_screen.dart';
import '../my_campaigns_screen.dart';
import '../my_feed_screen.dart';
import '../my_flags_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile_screen.dart';
import 'bank_accounts_screen.dart';
import 'change_password_screen.dart';
import 'donation_history_screen.dart';

/// Màn hình "Tài khoản" — menu chính cho các chức năng cá nhân.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const Color _primary = Color(0xFFF84D43);
  static const Color _emerald = Color(0xFF1A685B);
  static const Color _bgGray = Color(0xFFF9FAFB);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _textGray = Color(0xFF4B5563);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: _bgGray,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined,
                  size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Vui lòng đăng nhập',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                ),
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
                child:
                    const Text('Đăng nhập', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgGray,
      appBar: AppBar(
        title: const Text('Tài khoản',
            style: TextStyle(fontWeight: FontWeight.bold, color: _textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: _textDark),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── User Info Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  // Avatar + đổi ảnh (cùng luồng Supabase + updateProfile như web / ProfileScreen)
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _primary.withOpacity(0.2), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 48, color: Colors.grey)
                              : null,
                        ),
                      ),
                      if (auth.isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!auth.isLoading)
                        GestureDetector(
                          onTap: () => _pickAccountAvatar(context),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primary,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(user.fullName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textDark)),
                  const SizedBox(height: 4),
                  Text(user.email,
                      style: const TextStyle(fontSize: 13, color: _textGray)),
                  const SizedBox(height: 10),
                  // Badges row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(user.kycVerified ? 'Đã xác minh' : 'Chưa KYC',
                          user.kycVerified ? _emerald : Colors.grey,
                          icon: user.kycVerified
                              ? Icons.verified
                              : Icons.shield_outlined),
                      if (user.trustScore != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(
                          'Uy tín: ${user.trustScore!.toStringAsFixed(0)}',
                          user.trustScore! >= 80
                              ? _emerald
                              : user.trustScore! >= 50
                                  ? _amber
                                  : Colors.red,
                          icon: Icons.star_rounded,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Menu Items ──
            _buildSectionLabel('QUẢN LÝ'),
            _buildMenuGroup(context, [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Hồ sơ của tôi',
                subtitle: 'Tên, số điện thoại, ngân hàng trong hồ sơ',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.folder_open_outlined,
                title: 'Chiến dịch của tôi',
                subtitle: 'Quản lý chiến dịch gây quỹ',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyCampaignsScreen())),
              ),
              _MenuItem(
                icon: Icons.article_outlined,
                title: 'Bài viết của tôi',
                subtitle: 'Tạo, sửa và xóa bài viết',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyFeedScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.history,
                title: 'Lịch sử quyên góp',
                subtitle: 'Xem các khoản đã đóng góp',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DonationHistoryScreen())),
              ),
              _MenuItem(
                icon: Icons.calendar_month_outlined,
                title: 'Lịch hẹn',
                subtitle: 'Lịch hẹn với nhân viên / chiến dịch',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AppointmentScheduleScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.chat_bubble_outline,
                title: 'Trò chuyện',
                subtitle: 'Tin nhắn hỗ trợ theo chiến dịch',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.flag_outlined,
                title: 'Tố cáo của tôi',
                subtitle: 'Các báo cáo bạn đã gửi',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyFlagsScreen()),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            _buildSectionLabel('TÀI CHÍNH & BẢO MẬT'),
            _buildMenuGroup(context, [
              _MenuItem(
                icon: Icons.account_balance_outlined,
                title: 'Tài khoản ngân hàng',
                subtitle: 'Quản lý tài khoản liên kết',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BankAccountsScreen())),
              ),
              _MenuItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                subtitle: 'Cập nhật mật khẩu đăng nhập',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen())),
              ),
              if (!user.kycVerified)
                _MenuItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Xác minh KYC',
                  subtitle: 'Hoàn tất xác minh danh tính',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KycScreen())),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Chưa KYC',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _amber)),
                  ),
                ),
            ]),

            const SizedBox(height: 24),

            // ── Logout ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Đăng xuất'),
                        content: const Text(
                            'Bạn có chắc chắn muốn đăng xuất?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Hủy')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              auth.logout();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (r) => false,
                              );
                            },
                            child: const Text('Đăng xuất',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Đăng xuất',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

  // ── Helpers ──

  Widget _buildBadge(String label, Color color, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 8, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9CA3AF),
                letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildMenuGroup(BuildContext context, List<_MenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _bgGray,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 20, color: _primary),
                ),
                title: Text(item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _textDark)),
                subtitle: Text(item.subtitle,
                    style: const TextStyle(fontSize: 12, color: _textGray)),
                trailing: item.trailing ??
                    Icon(Icons.chevron_right,
                        size: 20, color: _textGray.withOpacity(0.5)),
                onTap: item.onTap,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              if (idx < items.length - 1)
                Divider(
                    height: 1,
                    indent: 60,
                    endIndent: 16,
                    color: _border.withOpacity(0.5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
}

Future<void> _pickAccountAvatar(BuildContext context) async {
  final AuthProvider auth = Provider.of<AuthProvider>(context, listen: false);
  if (auth.isLoading) return;
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  if (image == null || !context.mounted) return;
  final String uploadPath =
      await ImageCropperHelper.cropAvatar(image.path) ?? image.path;
  final bool success = await auth.updateAvatar(uploadPath);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? 'Đã cập nhật ảnh đại diện.'
            : (auth.error ?? 'Không cập nhật được ảnh đại diện.'),
      ),
    ),
  );
}
