class BankAccountModel {
  final int id;
  final int userId;
  final String bankCode;
  final String accountNumber;
  final String accountHolderName;
  final bool isVerified;
  final String status;
  final int? campaignId;
  String? campaignTitle;

  BankAccountModel({
    required this.id,
    required this.userId,
    required this.bankCode,
    required this.accountNumber,
    required this.accountHolderName,
    required this.isVerified,
    required this.status,
    this.campaignId,
    this.campaignTitle,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'],
      userId: json['userId'],
      bankCode: json['bankCode'],
      accountNumber: json['accountNumber'],
      accountHolderName: json['accountHolderName'],
      isVerified: json['isVerified'] ?? false,
      status: json['status'] ?? 'PENDING',
      campaignId: json['campaignId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bankCode': bankCode,
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'isVerified': isVerified,
      'status': status,
      'campaignId': campaignId,
    };
  }
}
