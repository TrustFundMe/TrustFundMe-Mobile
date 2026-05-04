import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý KYC (Know Your Customer) verification.
///
/// Tương đương [kycService] trên web app (danbox).
class KycService extends BaseService {
  /// Gửi yêu cầu KYC cho user.
  Future<Response<dynamic>> submitKyc(
    int userId,
    Map<String, dynamic> payload,
  ) async {
    return dio.post('$identityUrl/kyc/users/$userId', data: payload);
  }

  /// Cập nhật KYC (re-submit sau khi bị reject).
  Future<Response<dynamic>> updateKyc(
    int userId,
    Map<String, dynamic> payload,
  ) async {
    return dio.put('$identityUrl/kyc/users/$userId', data: payload);
  }

  /// Lấy KYC status của user hiện tại (authenticated).
  Future<Response<dynamic>> getMyKyc() async {
    return dio.get('$identityUrl/kyc/me');
  }

  /// Lấy KYC theo userId (admin hoặc chính user).
  Future<Response<dynamic>> getKycByUserId(int userId) async {
    return dio.get('$identityUrl/kyc/user/$userId');
  }

  /// Upload tài liệu KYC (dùng media service).
  /// [filePath]: đường dẫn file trên device
  /// [docType]: loại tài liệu (e.g. 'FRONT_ID', 'BACK_ID', 'SELFIE')
  Future<Response<dynamic>> uploadKycDocument(
    String filePath, {
    required String docType,
    required int userId,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
      'docType': docType,
      'userId': userId,
    });

    return dio.post(
      '$identityUrl/kyc/upload',
      data: formData,
      options: Options(
        headers: <String, String>{
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }
}
