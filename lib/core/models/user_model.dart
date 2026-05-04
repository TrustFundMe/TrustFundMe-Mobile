class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final bool verified;
  final bool isActive;

  /// KYC status: NOT_SUBMITTED, PENDING, APPROVED, REJECTED
  final String? kycStatus;

  /// Họ tên đầy đủ trên hồ sơ KYC (có thể khác [fullName]).
  final String? kycFullName;

  /// `true` nếu KYC đã được duyệt (kycStatus == APPROVED).
  final bool kycVerified;

  /// Điểm uy tín (0–100).
  final double? trustScore;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    required this.role,
    required this.verified,
    required this.isActive,
    this.kycStatus,
    this.kycFullName,
    this.kycVerified = false,
    this.trustScore,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final int id = rawId is int
        ? rawId
        : (rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0);

    final String? kycStatus = json['kycStatus'] as String?;
    final bool kycVerified =
        json['kycVerified'] == true || kycStatus == 'APPROVED';

    return UserModel(
      id: id,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] ?? 'DONOR',
      verified: json['verified'] ?? false,
      isActive: json['isActive'] ?? true,
      kycStatus: kycStatus,
      kycFullName: json['kycFullName'] as String?,
      kycVerified: kycVerified,
      trustScore: json['trustScore'] != null
          ? (json['trustScore'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'role': role,
      'verified': verified,
      'isActive': isActive,
      'kycStatus': kycStatus,
      'kycFullName': kycFullName,
      'kycVerified': kycVerified,
      'trustScore': trustScore,
    };
  }

  /// Tạo bản copy với các field override.
  UserModel copyWith({
    int? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    String? role,
    bool? verified,
    bool? isActive,
    String? kycStatus,
    String? kycFullName,
    bool? kycVerified,
    double? trustScore,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      verified: verified ?? this.verified,
      isActive: isActive ?? this.isActive,
      kycStatus: kycStatus ?? this.kycStatus,
      kycFullName: kycFullName ?? this.kycFullName,
      kycVerified: kycVerified ?? this.kycVerified,
      trustScore: trustScore ?? this.trustScore,
    );
  }
}
