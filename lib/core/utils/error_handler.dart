import 'package:dio/dio.dart';

/// Xử lý lỗi Dio + chuyển message tiếng Anh từ Identity BE sang tiếng Việt.
class ErrorHandler {
  static String handle(dynamic e) {
    if (e is DioException) {
      if (e.response != null) {
        final dynamic data = e.response!.data;
        if (data is Map) {
          final dynamic errs = data['errors'];
          if (errs is Map && errs.isNotEmpty) {
            final Iterable<String> parts = errs.values.map(
              (dynamic v) => localizeBackendMessage(v.toString()),
            );
            return parts.join(' ');
          }
          if (data.containsKey('message') && data['message'] != null) {
            return localizeBackendMessage(data['message'].toString());
          }
          if (data.containsKey('error') && data['error'] != null) {
            final String errStr = data['error'].toString();
            if (!_isGenericHttpLabel(errStr)) {
              return localizeBackendMessage(errStr);
            }
          }
        }

        switch (e.response!.statusCode) {
          case 400:
            return 'Dữ liệu yêu cầu không hợp lệ. Vui lòng kiểm tra lại.';
          case 401:
            return 'Email hoặc mật khẩu không chính xác.';
          case 403:
            return 'Bạn không có quyền truy cập chức năng này.';
          case 404:
            return 'Không tìm thấy nội dung yêu cầu.';
          case 500:
            return 'Lỗi máy chủ hệ thống. Vui lòng thử lại sau.';
          default:
            return 'Có lỗi xảy ra (Mã lỗi: ${e.response!.statusCode}). Vui lòng thử lại.';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Kết nối mạng quá hạn. Vui lòng kiểm tra lại kết nối.';
      } else if (e.type == DioExceptionType.cancel) {
        return 'Yêu cầu đã bị hủy.';
      } else {
        return 'Lỗi kết nối. Vui lòng kiểm tra lại mạng của bạn.';
      }
    }
    return localizeBackendMessage(e?.toString() ?? 'Có lỗi không xác định xảy ra.');
  }

  static bool _isGenericHttpLabel(String s) {
    const Set<String> generic = <String>{
      'Bad Request',
      'Unauthorized',
      'Not Found',
      'Validation Failed',
      'Internal Server Error',
    };
    return generic.contains(s) || s.startsWith('Internal Server Error (');
  }

  /// Map message từ BE (AuthServiceImpl, Jakarta validation, …) sang tiếng Việt.
  static String localizeBackendMessage(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) return raw;

    final String lower = t.toLowerCase();

    const Map<String, String> exact = <String, String>{
      'Email already exists': 'Email này đã được đăng ký.',
      'Invalid email or password': 'Email hoặc mật khẩu không đúng.',
      'Invalid refresh token': 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      'Email not found': 'Không tìm thấy email này trên hệ thống.',
      'Account is deactivated': 'Tài khoản đã bị vô hiệu hoá.',
      'Invalid or expired OTP': 'Mã OTP không đúng hoặc đã hết hạn.',
      'OTP has expired': 'Mã OTP đã hết hạn.',
      'Reset token has expired': 'Liên kết đặt lại mật khẩu đã hết hạn.',
      'Invalid reset token': 'Token đặt lại mật khẩu không hợp lệ.',
      'Invalid or expired reset token': 'Token đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.',
      'User not found': 'Không tìm thấy người dùng.',
      'Verification token has expired': 'Mã xác minh đã hết hạn.',
      'Invalid verification token': 'Mã xác minh không hợp lệ.',
      'Invalid or expired verification token':
          'Mã xác minh không hợp lệ hoặc đã hết hạn.',
      'Invalid Google ID Token': 'Google không hợp lệ. Vui lòng thử lại.',
      'Invalid input data': 'Dữ liệu nhập vào không hợp lệ.',
      'OTP has been sent to your email': 'Mã OTP đã được gửi đến email của bạn.',
      'OTP verified successfully. You can now reset your password.':
          'Xác minh OTP thành công.',
      'Password reset successfully': 'Đặt lại mật khẩu thành công.',
      'Email verified successfully': 'Xác minh email thành công.',
      'Email is required': 'Vui lòng nhập email.',
      'Email should be valid': 'Email không hợp lệ.',
      'Password is required': 'Vui lòng nhập mật khẩu.',
      'Password must be at least 6 characters': 'Mật khẩu tối thiểu 6 ký tự.',
      'Full name is required': 'Vui lòng nhập họ và tên.',
      'OTP is required': 'Vui lòng nhập mã OTP.',
      'OTP must be 6 digits': 'Mã OTP phải gồm 6 chữ số.',
      'Token is required': 'Thiếu token xác thực.',
      'New password is required': 'Vui lòng nhập mật khẩu mới.',
    };

    if (exact.containsKey(t)) return exact[t]!;

    for (final MapEntry<String, String> e in exact.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }

    if (lower.startsWith('google login failed:')) {
      return 'Đăng nhập Google thất bại. Vui lòng thử lại.';
    }

    return t;
  }
}
