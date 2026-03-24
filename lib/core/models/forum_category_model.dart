class ForumCategoryModel {
  ForumCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.iconUrl,
    this.color,
    this.displayOrder = 0,
    this.postCount = 0,
  });

  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? iconUrl;
  final String? color;
  final int displayOrder;
  final int postCount;

  static int _int(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  factory ForumCategoryModel.fromJson(Map<String, dynamic> json) {
    return ForumCategoryModel(
      id: _int(json['id']),
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      color: json['color'] as String?,
      displayOrder: _int(json['displayOrder']),
      postCount: _int(json['postCount']),
    );
  }
}
