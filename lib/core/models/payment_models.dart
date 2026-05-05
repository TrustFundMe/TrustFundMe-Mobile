class DonationItemRequest {
  final int expenditureItemId;
  final int quantity;
  final int amount;

  DonationItemRequest({
    required this.expenditureItemId,
    required this.quantity,
    required this.amount,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'expenditureItemId': expenditureItemId,
        'quantity': quantity,
        'amount': amount,
      };
}

class CreatePaymentRequestModel {
  final int? donorId;
  final int campaignId;
  final int donationAmount;
  final int tipAmount;
  final String description;
  final bool isAnonymous;
  final List<DonationItemRequest> items;

  CreatePaymentRequestModel({
    required this.donorId,
    required this.campaignId,
    required this.donationAmount,
    required this.tipAmount,
    required this.description,
    required this.isAnonymous,
    required this.items,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'donorId': donorId,
        'campaignId': campaignId,
        'donationAmount': donationAmount,
        'tipAmount': tipAmount,
        'description': description,
        'isAnonymous': isAnonymous,
        'items': items.map((DonationItemRequest e) => e.toJson()).toList(),
      };
}

class PaymentResponseModel {
  final String? paymentUrl;
  final String? qrCode;
  final String? paymentLinkId;
  final int? donationId;
  final int? campaignId;
  final double? donationAmount;
  final double? totalAmount;
  final String? status;

  PaymentResponseModel({
    this.paymentUrl,
    this.qrCode,
    this.paymentLinkId,
    this.donationId,
    this.campaignId,
    this.donationAmount,
    this.totalAmount,
    this.status,
  });

  factory PaymentResponseModel.fromJson(Map<String, dynamic> json) {
    return PaymentResponseModel(
      paymentUrl: json['paymentUrl'] as String?,
      qrCode: json['qrCode'] as String?,
      paymentLinkId: json['paymentLinkId'] as String?,
      donationId: (json['donationId'] as num?)?.toInt(),
      campaignId: (json['campaignId'] as num?)?.toInt(),
      donationAmount: (json['donationAmount'] as num?)?.toDouble(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      status: json['status'] as String?,
    );
  }
}

class CampaignProgressModel {
  final int campaignId;
  final int raisedAmount;
  final int goalAmount;
  final int progressPercentage;
  final int donorCount;

  CampaignProgressModel({
    required this.campaignId,
    required this.raisedAmount,
    required this.goalAmount,
    required this.progressPercentage,
    this.donorCount = 0,
  });

  factory CampaignProgressModel.fromJson(Map<String, dynamic> json) {
    return CampaignProgressModel(
      campaignId: (json['campaignId'] as num?)?.toInt() ?? 0,
      raisedAmount: (json['raisedAmount'] as num?)?.toInt() ?? 0,
      goalAmount: (json['goalAmount'] as num?)?.toInt() ?? 0,
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? 0,
      donorCount: (json['donorCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecentDonorModel {
  final int donationId;
  final int? donorId;
  final String donorName;
  final String? donorAvatar;
  final int amount;
  final String createdAt;
  final bool anonymous;

  RecentDonorModel({
    required this.donationId,
    required this.donorId,
    required this.donorName,
    required this.donorAvatar,
    required this.amount,
    required this.createdAt,
    required this.anonymous,
  });

  factory RecentDonorModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['donationId'];
    final int donationId = rawId is int
        ? rawId
        : (rawId is num ? rawId.toInt() : 0);
    final dynamic rawDonorId = json['donorId'];
    final int? donorId = rawDonorId == null
        ? null
        : (rawDonorId is int ? rawDonorId : (rawDonorId as num).toInt());
    final dynamic rawAmount = json['amount'];
    final int amount = rawAmount is int
        ? rawAmount
        : (rawAmount is num ? rawAmount.round() : 0);
    final dynamic rawCreated = json['createdAt'];
    String createdAt = '';
    if (rawCreated is String) {
      createdAt = rawCreated;
    } else if (rawCreated is List && rawCreated.length >= 3) {
      createdAt = rawCreated.toString();
    }
    return RecentDonorModel(
      donationId: donationId,
      donorId: donorId,
      donorName: (json['donorName'] ?? '') as String,
      donorAvatar: json['donorAvatar'] as String?,
      amount: amount,
      createdAt: createdAt,
      anonymous: json['anonymous'] as bool? ?? false,
    );
  }
}

/// Model cho expenditure (đợt chi tiêu / milestone)
class ExpenditurePlanModel {
  final int id;
  final String title;
  final int amount;
  final String? description;
  final String? date;
  final String? status;
  final String? startDate;
  final String? endDate;
  final int totalItems;
  final List<ExpenditureCategoryModel> categories;

  ExpenditurePlanModel({
    required this.id,
    required this.title,
    required this.amount,
    this.description,
    this.date,
    this.status,
    this.startDate,
    this.endDate,
    this.totalItems = 0,
    this.categories = const [],
  });
}

class ExpenditureCategoryModel {
  final int? id;
  final String name;
  final String? description;
  final int expectedAmount;
  final int actualAmount;
  final List<ExpenditureCategoryItemModel> items;

  ExpenditureCategoryModel({
    this.id,
    required this.name,
    this.description,
    this.expectedAmount = 0,
    this.actualAmount = 0,
    this.items = const [],
  });
}

class ExpenditureCategoryItemModel {
  final int? id;
  final String name;
  final int expectedQuantity;
  final int expectedPrice;
  final int actualQuantity;
  final int price;
  final String? note;

  ExpenditureCategoryItemModel({
    this.id,
    required this.name,
    this.expectedQuantity = 0,
    this.expectedPrice = 0,
    this.actualQuantity = 0,
    this.price = 0,
    this.note,
  });
}
