class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final bool verified;
  final bool isActive;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    required this.role,
    required this.verified,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'],
      phoneNumber: json['phoneNumber'],
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'DONOR',
      verified: json['verified'] ?? false,
      isActive: json['isActive'] ?? true,
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
    };
  }
}
