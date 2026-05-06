/// Model đại diện cho notification từ backend.
class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;

  /// Loại notification: KYC_APPROVED, DONATION_RECEIVED, CAMPAIGN_APPROVED, etc.
  final String type;

  final bool isRead;

  /// Metadata bổ sung (VD: campaignId, donationAmount, ...).
  final Map<String, dynamic>? metadata;

  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.metadata,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Backend trả về `content` (field name trong entity Notification.java),
    // nhưng Flutter model dùng `message`. Chấp nhận cả hai.
    final String msg = (json['message'] as String?)
        ?? (json['content'] as String?)
        ?? '';

    // Backend trả về `data` (JSON string), Flutter dùng `metadata`.
    // Cố gắng parse `data` string thành Map nếu cần.
    Map<String, dynamic>? meta;
    if (json['metadata'] is Map<String, dynamic>) {
      meta = json['metadata'] as Map<String, dynamic>;
    } else if (json['data'] is Map<String, dynamic>) {
      meta = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is String && (json['data'] as String).isNotEmpty) {
      try {
        final parsed = Uri.splitQueryString(json['data'] as String);
        meta = parsed.isNotEmpty ? parsed : null;
      } catch (_) {
        meta = null;
      }
    }

    // Backend `createdAt` có thể là ISO string hoặc array [year,month,day,hour,min,sec]
    DateTime parsedCreatedAt = DateTime.now();
    final dynamic rawDate = json['createdAt'];
    if (rawDate is String) {
      parsedCreatedAt = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is List && rawDate.length >= 3) {
      parsedCreatedAt = DateTime(
        rawDate[0] as int,
        rawDate[1] as int,
        rawDate[2] as int,
        rawDate.length > 3 ? rawDate[3] as int : 0,
        rawDate.length > 4 ? rawDate[4] as int : 0,
        rawDate.length > 5 ? rawDate[5] as int : 0,
      );
    }

    return NotificationModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}') ?? 0,
      title: json['title'] as String? ?? '',
      message: msg,
      type: json['type'] as String? ?? 'GENERAL',
      isRead: json['isRead'] == true || json['read'] == true,
      metadata: meta,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
