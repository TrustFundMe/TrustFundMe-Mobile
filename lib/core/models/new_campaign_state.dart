/// Trạng thái tổng hợp cho luồng tạo chiến dịch mới (5 bước).
class NewCampaignState {
  String kycStatus;
  String kycFullName;
  CampaignCore campaignCore;
  List<Milestone> milestones;
  BankInfo bankInfo;
  Acknowledgements acknowledgements;

  NewCampaignState({
    this.kycStatus = 'NOT_SUBMITTED',
    this.kycFullName = '',
    CampaignCore? campaignCore,
    List<Milestone>? milestones,
    BankInfo? bankInfo,
    Acknowledgements? acknowledgements,
  })  : campaignCore = campaignCore ?? CampaignCore(),
        milestones = milestones ?? [],
        bankInfo = bankInfo ?? BankInfo(),
        acknowledgements = acknowledgements ?? Acknowledgements();

  /// Tính targetAmount tự động từ tất cả milestone items.
  int get calculatedTargetAmount {
    int total = 0;
    for (final ms in milestones) {
      for (final cat in ms.categories) {
        for (final item in cat.items) {
          total += item.expectedQuantity * item.expectedPrice;
        }
      }
    }
    return total;
  }

  /// Chuyển sang JSON để gửi API tạo campaign.
  Map<String, dynamic> toCreatePayload() {
    return {
      'title': campaignCore.title,
      'objective': campaignCore.objective,
      'targetAmount': calculatedTargetAmount,
      'startDate': campaignCore.startDate,
      'endDate': campaignCore.endDate,
      'category': campaignCore.category,
      'categoryId': campaignCore.categoryId,
      'region': campaignCore.region,
      'beneficiaryType': campaignCore.beneficiaryType,
      'thankMessage': campaignCore.thankMessage,
      'coverImageUrl': campaignCore.coverImageUrl,
      'campaignImages': campaignCore.campaignImages,
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'bankInfo': bankInfo.toJson(),
    };
  }
}

/// Thông tin cốt lõi của chiến dịch (Step 2).
class CampaignCore {
  String title;
  String objective;
  int targetAmount;
  String startDate; // yyyy-MM-dd
  String endDate;
  String category;
  int? categoryId;
  String region;
  String beneficiaryType;
  String thankMessage;
  String? coverImageUrl;
  List<String> campaignImages;

  CampaignCore({
    this.title = '',
    this.objective = '',
    this.targetAmount = 0,
    this.startDate = '',
    this.endDate = '',
    this.category = '',
    this.categoryId,
    this.region = '',
    this.beneficiaryType = '',
    this.thankMessage = '',
    this.coverImageUrl,
    List<String>? campaignImages,
  }) : campaignImages = campaignImages ?? [];

  /// Validate Step 2.
  List<String> validate() {
    final errors = <String>[];
    if (title.trim().isEmpty) errors.add('Tên chiến dịch không được để trống');
    if (title.trim().length < 10) errors.add('Tên chiến dịch tối thiểu 10 ký tự');
    if (objective.trim().isEmpty) errors.add('Mục tiêu gây quỹ không được để trống');
    if (objective.trim().length < 20) errors.add('Mô tả mục tiêu tối thiểu 20 ký tự');
    if (category.isEmpty) errors.add('Vui lòng chọn danh mục');
    if (region.isEmpty) errors.add('Vui lòng chọn khu vực');
    if (beneficiaryType.isEmpty) errors.add('Vui lòng chọn đối tượng thụ hưởng');
    if (startDate.isEmpty) errors.add('Vui lòng chọn ngày bắt đầu');
    if (endDate.isEmpty) errors.add('Vui lòng chọn ngày kết thúc');
    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'objective': objective,
      'targetAmount': targetAmount,
      'startDate': startDate,
      'endDate': endDate,
      'category': category,
      'categoryId': categoryId,
      'region': region,
      'beneficiaryType': beneficiaryType,
      'thankMessage': thankMessage,
      'coverImageUrl': coverImageUrl,
      'campaignImages': campaignImages,
    };
  }
}

/// Một đợt giải ngân (milestone) của chiến dịch.
class Milestone {
  String id;
  String title;
  String description;
  int plannedAmount;
  String startDate;
  String endDate;
  String evidenceDueAt;
  List<MilestoneCategory> categories;

  Milestone({
    String? id,
    this.title = '',
    this.description = '',
    this.plannedAmount = 0,
    this.startDate = '',
    this.endDate = '',
    this.evidenceDueAt = '',
    List<MilestoneCategory>? categories,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        categories = categories ?? [];

  /// Tổng tiền tính từ tất cả items trong milestone.
  int get calculatedAmount {
    int total = 0;
    for (final cat in categories) {
      for (final item in cat.items) {
        total += item.expectedQuantity * item.expectedPrice;
      }
    }
    return total;
  }

  /// Validate milestone.
  List<String> validate() {
    final errors = <String>[];
    if (title.trim().isEmpty) errors.add('Tên đợt giải ngân không được để trống');
    if (startDate.isEmpty) errors.add('Vui lòng chọn ngày bắt đầu đợt');
    if (endDate.isEmpty) errors.add('Vui lòng chọn ngày kết thúc đợt');
    if (evidenceDueAt.isEmpty) errors.add('Vui lòng chọn hạn nộp minh chứng');
    if (categories.isEmpty) errors.add('Cần ít nhất 1 danh mục chi tiêu');
    for (int i = 0; i < categories.length; i++) {
      final catErrors = categories[i].validate();
      for (final e in catErrors) {
        errors.add('Danh mục ${i + 1}: $e');
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'plannedAmount': calculatedAmount,
      'startDate': startDate,
      'endDate': endDate,
      'evidenceDueAt': evidenceDueAt,
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }
}

/// Danh mục chi tiêu trong một milestone.
class MilestoneCategory {
  String id;
  String name;
  String description;
  List<MilestoneCategoryItem> items;

  MilestoneCategory({
    String? id,
    this.name = '',
    this.description = '',
    List<MilestoneCategoryItem>? items,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        items = items ?? [];

  /// Tổng tiền danh mục.
  int get totalAmount {
    int total = 0;
    for (final item in items) {
      total += item.expectedQuantity * item.expectedPrice;
    }
    return total;
  }

  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('Tên danh mục không được để trống');
    if (items.isEmpty) errors.add('Cần ít nhất 1 hạng mục');
    for (int i = 0; i < items.length; i++) {
      final itemErrors = items[i].validate();
      for (final e in itemErrors) {
        errors.add('Hạng mục ${i + 1}: $e');
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

/// Một hạng mục chi tiêu cụ thể.
class MilestoneCategoryItem {
  String id;
  String name;
  int expectedQuantity;
  int expectedPrice;
  String expectedUnit;
  String expectedBrand;
  String expectedPurchaseLocation;
  String expectedPurchaseLink;
  String expectedNote;

  MilestoneCategoryItem({
    String? id,
    this.name = '',
    this.expectedQuantity = 0,
    this.expectedPrice = 0,
    this.expectedUnit = '',
    this.expectedBrand = '',
    this.expectedPurchaseLocation = '',
    this.expectedPurchaseLink = '',
    this.expectedNote = '',
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  /// Thành tiền.
  int get subtotal => expectedQuantity * expectedPrice;

  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('Tên hạng mục không được để trống');
    if (expectedQuantity <= 0) errors.add('Số lượng phải lớn hơn 0');
    if (expectedPrice <= 0) errors.add('Đơn giá phải lớn hơn 0');
    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'expectedQuantity': expectedQuantity,
      'expectedPrice': expectedPrice,
      'expectedUnit': expectedUnit,
      'expectedBrand': expectedBrand,
      'expectedPurchaseLocation': expectedPurchaseLocation,
      'expectedPurchaseLink': expectedPurchaseLink,
      'expectedNote': expectedNote,
    };
  }
}

/// Thông tin ngân hàng nhận giải ngân.
class BankInfo {
  String bankCode;
  String accountHolderName;
  String accountNumber;
  String bankName;
  String branch;

  BankInfo({
    this.bankCode = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.bankName = '',
    this.branch = '',
  });

  List<String> validate() {
    final errors = <String>[];
    if (bankCode.isEmpty) errors.add('Vui lòng chọn ngân hàng');
    if (accountNumber.isEmpty) errors.add('Số tài khoản không được để trống');
    if (accountHolderName.isEmpty) errors.add('Tên chủ tài khoản không được để trống');
    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'bankCode': bankCode,
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'branch': branch,
    };
  }
}

/// Các checkbox xác nhận điều khoản (Step 4).
class Acknowledgements {
  bool termsAccepted;
  bool overfundPolicyAccepted;
  bool transparencyAccepted;
  bool legalLiabilityAccepted;

  Acknowledgements({
    this.termsAccepted = false,
    this.overfundPolicyAccepted = false,
    this.transparencyAccepted = false,
    this.legalLiabilityAccepted = false,
  });

  bool get allAccepted =>
      termsAccepted &&
      overfundPolicyAccepted &&
      transparencyAccepted &&
      legalLiabilityAccepted;

  List<String> validate() {
    final errors = <String>[];
    if (!termsAccepted) errors.add('Vui lòng chấp nhận điều khoản sử dụng');
    if (!overfundPolicyAccepted) errors.add('Vui lòng chấp nhận chính sách dư quỹ');
    if (!transparencyAccepted) errors.add('Vui lòng chấp nhận cam kết minh bạch');
    if (!legalLiabilityAccepted) errors.add('Vui lòng chấp nhận trách nhiệm pháp lý');
    return errors;
  }

  Map<String, dynamic> toJson() {
    return {
      'termsAccepted': termsAccepted,
      'overfundPolicyAccepted': overfundPolicyAccepted,
      'transparencyAccepted': transparencyAccepted,
      'legalLiabilityAccepted': legalLiabilityAccepted,
    };
  }
}
