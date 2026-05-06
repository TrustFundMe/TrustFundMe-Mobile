import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// Đổi mật khẩu (user đã đăng nhập).
  Future<Response<dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return dio.put(
      '$identityUrl/users/change-password',
      data: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  /// Đăng xuất: xóa JWT token và user data khỏi secure storage.
  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'user_data');
  }

  /// Lấy JWT token hiện tại (nếu có).
  Future<String?> getToken() async {
    return storage.read(key: 'jwt_token');
  }

  // ─── Persistent user data ──────────────────────────────────────────────────

  /// Lưu user data dưới dạng JSON string vào secure storage.
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await storage.write(key: 'user_data', value: jsonEncode(userData));
  }

  /// Đọc user data từ secure storage.
  Future<Map<String, dynamic>?> readUserData() async {
    final String? raw = await storage.read(key: 'user_data');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AuthService] readUserData parse error: $e');
      return null;
    }
  }

  /// Xác minh token bằng cách gọi GET /users/{userId}.
  /// Trả về user data mới nhất nếu token hợp lệ, null nếu không.
  Future<Map<String, dynamic>?> verifyTokenAndGetUser(int userId) async {
    try {
      final Response<dynamic> response =
          await dio.get('$identityUrl/users/$userId');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      debugPrint('[AuthService] verifyTokenAndGetUser failed: ${e.response?.statusCode}');
    } catch (e) {
      debugPrint('[AuthService] verifyTokenAndGetUser error: $e');
    }
    return null;
  }
}
