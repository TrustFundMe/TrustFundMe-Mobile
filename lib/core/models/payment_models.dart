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

class CampaignProgressModel {
  final int campaignId;
  final int raisedAmount;
  final int goalAmount;
  final int progressPercentage;

  CampaignProgressModel({
    required this.campaignId,
    required this.raisedAmount,
    required this.goalAmount,
    required this.progressPercentage,
  });

  factory CampaignProgressModel.fromJson(Map<String, dynamic> json) {
    return CampaignProgressModel(
      campaignId: json['campaignId'] as int,
      raisedAmount: (json['raisedAmount'] as num?)?.toInt() ?? 0,
      goalAmount: (json['goalAmount'] as num?)?.toInt() ?? 0,
      progressPercentage: json['progressPercentage'] as int? ?? 0,
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
    return RecentDonorModel(
      donationId: json['donationId'] as int,
      donorId: json['donorId'] as int?,
      donorName: (json['donorName'] ?? '') as String,
      donorAvatar: json['donorAvatar'] as String?,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] ?? '') as String,
      anonymous: json['anonymous'] as bool? ?? false,
    );
  }
}

