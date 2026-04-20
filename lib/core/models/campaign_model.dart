class CampaignModel {
  final int id;
  final String title;
  final String? type;
  final String? description;
  final String? coverImageUrl;
  final String? categoryName;
  final int? fundOwnerId;
  final int? assignedStaffId;
  final String? assignedStaffName;

  CampaignModel({
    required this.id,
    required this.title,
    this.type,
    this.description,
    this.coverImageUrl,
    this.categoryName,
    this.fundOwnerId,
    this.assignedStaffId,
    this.assignedStaffName,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      type: json['type'] as String?,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      categoryName: json['categoryName'] as String?,
      fundOwnerId: json['fundOwnerId'] as int?,
      assignedStaffId: json['assignedStaffId'] as int?,
      assignedStaffName: json['assignedStaffName'] as String?,
    );
  }
}

