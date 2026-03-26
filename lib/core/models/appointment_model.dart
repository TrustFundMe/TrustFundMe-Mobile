class AppointmentModel {
  final int id;
  final int? donorId;
  final String? donorName;
  final int? staffId;
  final String? staffName;
  final DateTime? startTime;
  final DateTime? endTime;
  final String status;
  final String? location;
  final String? purpose;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.id,
    this.donorId,
    this.donorName,
    this.staffId,
    this.staffName,
    this.startTime,
    this.endTime,
    required this.status,
    this.location,
    this.purpose,
    this.createdAt,
    this.updatedAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? 0,
      donorId: json['donorId'],
      donorName: json['donorName'],
      staffId: json['staffId'],
      staffName: json['staffName'],
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: json['status'] ?? 'PENDING',
      location: json['location'],
      purpose: json['purpose'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }
}
