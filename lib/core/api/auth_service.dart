import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'base_service.dart';

/// Service xử lý authentication: login, register, OTP, reset password, v.v.
class AuthService extends BaseService {
  /// Đăng nhập bằng email + password.
  /// Tự động lưu JWT token vào secure storage khi thành công.
  Future<Response<dynamic>> login(String username, String password) async {
    final Response<dynamic> response = await dio.post(
      '$identityUrl${ApiConfig.loginEndpoint}',
      data: <String, dynamic>{
        'email': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final String token = response.data['accessToken'] as String;
      await storage.write(key: 'jwt_token', value: token);
    }
    return response;
  }

  /// Đăng ký tài khoản mới.
  Future<Response<dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    final Response<dynamic> response = await dio.post(
      '$identityUrl${ApiConfig.registerEndpoint}',
      data: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber.trim(),
      },
    );

    if (response.statusCode == 201) {
      final String? token = response.data['accessToken'] as String?;
      if (token != null && token.isNotEmpty) {
        await storage.write(key: 'jwt_token', value: token);
      }
    }
    return response;
  }

  /// Đăng nhập bằng Google ID Token.
  Future<Response<dynamic>> loginWithGoogle(String idToken) async {
    final Response<dynamic> response = await dio.post(
      '$identityUrl${ApiConfig.googleLoginEndpoint}',
      data: <String, dynamic>{'idToken': idToken},
    );

    if (response.statusCode == 200) {
      final String token = response.data['accessToken'] as String;
      await storage.write(key: 'jwt_token', value: token);
    }
    return response;
  }

  /// Gửi OTP reset password đến email.
  Future<Response<dynamic>> sendPasswordResetOtp(String email) async {
    return dio.post(
      '$identityUrl${ApiConfig.sendOtpEndpoint}',
      data: <String, dynamic>{'email': email.trim()},
    );
  }

  /// Xác minh OTP reset password.
  Future<Response<dynamic>> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    return dio.post(
      '$identityUrl${ApiConfig.verifyOtpEndpoint}',
      data: <String, dynamic>{
        'email': email.trim(),
        'otp': otp.trim(),
      },
    );
  }

  /// Đặt lại mật khẩu (sau khi verify OTP).
  Future<Response<dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return dio.post(
      '$identityUrl${ApiConfig.resetPasswordEndpoint}',
      data: <String, dynamic>{
        'token': token,
        'newPassword': newPassword,
      },
    );
  }

  /// Xác minh email qua token (luồng đăng ký).
  Future<Response<dynamic>> verifyEmailWithToken(String token) async {
    return dio.post(
      '$identityUrl${ApiConfig.verifyEmailEndpoint}',
      data: <String, dynamic>{'token': token},
    );
  }

  /// Đăng xuất: xóa JWT token khỏi secure storage.
  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }

  /// Lấy JWT token hiện tại (nếu có).
  Future<String?> getToken() async {
    return storage.read(key: 'jwt_token');
  }
}
