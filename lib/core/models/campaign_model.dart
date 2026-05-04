class CampaignModel {
  final int id;
  final String title;
  final String? type;
  final String? description;
  final String? coverImageUrl;
  final String? categoryName;
  final String? categoryIconUrl;
  final int? fundOwnerId;
  final int? assignedStaffId;
  final String? assignedStaffName;
  final String? status;
  final String? rejectionReason;
  final bool kycVerified;
  final double? balance;

  CampaignModel({
    required this.id,
    required this.title,
    this.type,
    this.description,
    this.coverImageUrl,
    this.categoryName,
    this.categoryIconUrl,
    this.fundOwnerId,
    this.assignedStaffId,
    this.assignedStaffName,
    this.status,
    this.rejectionReason,
    this.kycVerified = false,
    this.balance,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      type: json['type'] as String?,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      categoryName: json['categoryName'] as String?,
      categoryIconUrl: json['categoryIconUrl'] as String?,
      fundOwnerId: json['fundOwnerId'] as int?,
      assignedStaffId: json['assignedStaffId'] as int?,
      assignedStaffName: json['assignedStaffName'] as String?,
      status: json['status'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      kycVerified: json['kycVerified'] as bool? ?? false,
      balance: (json['balance'] as num?)?.toDouble(),
    );
  }

  CampaignModel copyWith({
    int? id,
    String? title,
    String? type,
    String? description,
    String? coverImageUrl,
    String? categoryName,
    String? categoryIconUrl,
    int? fundOwnerId,
    int? assignedStaffId,
    String? assignedStaffName,
    String? status,
    String? rejectionReason,
    bool? kycVerified,
    double? balance,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      categoryName: categoryName ?? this.categoryName,
      categoryIconUrl: categoryIconUrl ?? this.categoryIconUrl,
      fundOwnerId: fundOwnerId ?? this.fundOwnerId,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      kycVerified: kycVerified ?? this.kycVerified,
      balance: balance ?? this.balance,
    );
  }
}
