/// Model đại diện cho danh mục chiến dịch.
class CampaignCategoryModel {
  final int id;
  final String name;
  final String? iconUrl;
  final String? description;

  CampaignCategoryModel({
    required this.id,
    required this.name,
    this.iconUrl,
    this.description,
  });

  factory CampaignCategoryModel.fromJson(Map<String, dynamic> json) {
    return CampaignCategoryModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: json['name'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
      'description': description,
    };
  }
}
