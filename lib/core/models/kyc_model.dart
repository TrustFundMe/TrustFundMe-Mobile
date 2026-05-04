/// Model đại diện cho hồ sơ KYC (Know Your Customer).
class KycModel {
  final int? id;
  final int userId;
  final String fullName;

  /// Ngày sinh, định dạng dd/MM/yyyy.
  final String dateOfBirth;

  /// Giới tính: Nam / Nữ / Khác.
  final String gender;

  /// Số CCCD / CMND.
  final String idNumber;

  final String? frontImageUrl;
  final String? backImageUrl;
  final String? selfieImageUrl;

  /// Trạng thái: NOT_SUBMITTED, PENDING, APPROVED, REJECTED.
  final String status;

  /// Lý do từ chối (nếu status == REJECTED).
  final String? rejectReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  KycModel({
    this.id,
    required this.userId,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.idNumber,
    this.frontImageUrl,
    this.backImageUrl,
    this.selfieImageUrl,
    this.status = 'NOT_SUBMITTED',
    this.rejectReason,
    this.createdAt,
    this.updatedAt,
  });

  factory KycModel.fromJson(Map<String, dynamic> json) {
    return KycModel(
      id: json['id'] as int?,
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId']}') ?? 0,
      fullName: json['fullName'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      idNumber: json['idNumber'] as String? ?? '',
      frontImageUrl: json['frontImageUrl'] as String?,
      backImageUrl: json['backImageUrl'] as String?,
      selfieImageUrl: json['selfieImageUrl'] as String?,
      status: json['status'] as String? ?? 'NOT_SUBMITTED',
      rejectReason: json['rejectReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'idNumber': idNumber,
      'frontImageUrl': frontImageUrl,
      'backImageUrl': backImageUrl,
      'selfieImageUrl': selfieImageUrl,
      'status': status,
      'rejectReason': rejectReason,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
