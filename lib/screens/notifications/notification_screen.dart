import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/notification_service.dart';
import '../../core/models/notification_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/error_handler.dart';

/// Màn hình hiển thị danh sách thông báo.
///
/// - Pull to refresh
/// - Mark as read khi tap
/// - Icon theo loại notification
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notifService = NotificationService();

  // Colors matching the design system
  static const Color webPrimary = Color(0xFFF84D43);
  static const Color webEmerald = Color(0xFF1A685B);
  static const Color webBgGray = Color(0xFFF9FAFB);
  static const Color webTextDark = Color(0xFF1F2937);
  static const Color webTextGray = Color(0xFF4B5563);
  static const Color webBorderGray = Color(0xFFE5E7EB);

  bool _isLoading = true;
  String? _error;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      debugPrint('[NotificationScreen] user is null — skipping load');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[NotificationScreen] Loading notifications for userId=${user.id}');
      final response = await _notifService.getByUserId(user.id);
      debugPrint('[NotificationScreen] Response status=${response.statusCode}');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> rawList = response.data is List
            ? response.data as List<dynamic>
            : (response.data['content'] as List<dynamic>? ?? []);
        debugPrint('[NotificationScreen] Loaded ${rawList.length} notifications');
        _notifications = rawList
            .map((e) =>
                NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[NotificationScreen] Error loading notifications: $e');
      _error = ErrorHandler.handle(e);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(NotificationModel notif) async {
    if (notif.isRead) return;

    try {
      await _notifService.markAsRead(notif.id);
      // Cập nhật local state
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx >= 0) {
          _notifications[idx] = NotificationModel(
            id: notif.id,
            userId: notif.userId,
            title: notif.title,
            message: notif.message,
            type: notif.type,
            isRead: true,
            metadata: notif.metadata,
            createdAt: notif.createdAt,
          );
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    try {
      await _notifService.markAllAsRead(user.id);
      setState(() {
        _notifications = _notifications
            .map((n) => NotificationModel(
                  id: n.id,
                  userId: n.userId,
                  title: n.title,
                  message: n.message,
                  type: n.type,
                  isRead: true,
                  metadata: n.metadata,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả là đã đọc'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Icon & màu sắc theo loại notification.
  _NotifStyle _styleForType(String type) {
    switch (type) {
      case 'KYC_APPROVED':
        return _NotifStyle(Icons.verified_user, webEmerald);
      case 'KYC_REJECTED':
        return _NotifStyle(Icons.gpp_bad, Colors.red);
      case 'KYC_PENDING':
        return _NotifStyle(Icons.hourglass_top, Colors.orange);
      case 'DONATION_RECEIVED':
        return _NotifStyle(Icons.volunteer_activism, Colors.pink);
      case 'CAMPAIGN_APPROVED':
        return _NotifStyle(Icons.campaign, webEmerald);
      case 'CAMPAIGN_REJECTED':
        return _NotifStyle(Icons.block, Colors.red);
      case 'FLAG_RESOLVED':
        return _NotifStyle(Icons.flag, Colors.blue);
      case 'CHAT_MESSAGE':
        return _NotifStyle(Icons.chat_bubble, Colors.indigo);
      default:
        return _NotifStyle(Icons.notifications, webPrimary);
    }
  }

  /// Tính "time ago" đơn giản.
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365} năm trước';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30} tháng trước';
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: webBgGray,
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(color: webTextDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: webTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(
                  color: webPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _notifications.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: webTextGray),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadNotifications,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 80, color: webTextGray.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'Chưa có thông báo nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: webTextDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thông báo mới sẽ xuất hiện ở đây.',
              style: TextStyle(color: webTextGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: webPrimary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _buildNotifItem(notif);
        },
      ),
    );
  }

  Widget _buildNotifItem(NotificationModel notif) {
    final style = _styleForType(notif.type);

    return InkWell(
      onTap: () => _markAsRead(notif),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : Colors.blue.shade50,
          border: Border(
            bottom: BorderSide(color: webBorderGray.withOpacity(0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                notif.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: webTextDark,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: webPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: webTextGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(notif.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: webTextGray.withOpacity(0.7),
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
}

/// Helper class cho style notification icon.
class _NotifStyle {
  final IconData icon;
  final Color color;
  const _NotifStyle(this.icon, this.color);
}
