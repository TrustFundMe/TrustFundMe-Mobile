class FlagModel {
  FlagModel({
    required this.id,
    required this.userId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.postId,
    this.campaignId,
    this.reviewedBy,
  });

  final int id;
  final int? postId;
  final int? campaignId;
  final int userId;
  final String reason;
  /// PENDING | RESOLVED | DISMISSED
  final String status;
  final int? reviewedBy;
  final String createdAt;

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory FlagModel.fromJson(Map<String, dynamic> json) {
    return FlagModel(
      id: _toInt(json['id']) ?? 0,
      postId: _toInt(json['postId']),
      campaignId: _toInt(json['campaignId']),
      userId: _toInt(json['userId']) ?? 0,
      reason: (json['reason'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'PENDING',
      reviewedBy: _toInt(json['reviewedBy']),
      createdAt: (json['createdAt'] as String?)?.trim() ?? '',
    );
  }
}

