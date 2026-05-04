import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý notifications (mới — tương đương notificationService trên web).
///
/// Backend: notification-service (port 8088).
class NotificationService extends BaseService {
  /// Lấy notifications của user.
  Future<Response<dynamic>> getByUserId(int userId) async {
    return dio.get('$notificationUrl/notifications/user/$userId');
  }

  /// Lấy notifications mới nhất của user.
  Future<Response<dynamic>> getLatest(int userId) async {
    return dio.get('$notificationUrl/notifications/user/$userId/latest');
  }

  /// Lấy số lượng notification chưa đọc.
  Future<Response<dynamic>> getUnreadCount(int userId) async {
    return dio.get('$notificationUrl/notifications/user/$userId/unread-count');
  }

  /// Đánh dấu notification đã đọc.
  Future<Response<dynamic>> markAsRead(int notificationId) async {
    return dio.put('$notificationUrl/notifications/$notificationId/read');
  }

  /// Đánh dấu tất cả notifications đã đọc.
  Future<Response<dynamic>> markAllAsRead(int userId) async {
    return dio.put('$notificationUrl/notifications/user/$userId/read-all');
  }
}
