class CampaignModel {
  final int id;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final String? categoryName;

  CampaignModel({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.categoryName,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      categoryName: json['categoryName'] as String?,
    );
  }
}

