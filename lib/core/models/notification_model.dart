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
    return NotificationModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}') ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'GENERAL',
      isRead: json['isRead'] == true || json['read'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
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
