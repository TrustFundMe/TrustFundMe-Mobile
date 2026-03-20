class ExpenditureItemModel {
  final int id;
  final String category;
  final int quantityLeft;
  final int expectedPrice;
  final String? note;

  ExpenditureItemModel({
    required this.id,
    required this.category,
    required this.quantityLeft,
    required this.expectedPrice,
    this.note,
  });

  factory ExpenditureItemModel.fromJson(Map<String, dynamic> json) {
    return ExpenditureItemModel(
      id: json['id'] as int,
      category: (json['category'] ?? '') as String,
      quantityLeft: (json['quantityLeft'] ?? 0) as int,
      expectedPrice:
          (json['expectedPrice'] ?? json['price'] ?? 0) as int,
      note: json['note'] as String?,
    );
  }
}

