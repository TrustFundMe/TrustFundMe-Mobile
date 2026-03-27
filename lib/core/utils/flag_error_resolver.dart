import 'package:dio/dio.dart';

String resolveFlagSubmitError(Object error) {
  if (error is DioException) {
    final int? status = error.response?.statusCode;
    final dynamic data = error.response?.data;

    String? serverMessage;
    if (data is Map<String, dynamic>) {
      serverMessage = (data['message'] ?? data['error'] ?? data['detail'])?.toString();
    } else if (data is String) {
      serverMessage = data;
    }

    final String msg = (serverMessage ?? '').trim();
    if (msg.isNotEmpty) {
      return msg;
    }

    if (status == 401) {
      return 'Bạn cần đăng nhập để gửi báo cáo.';
    }
    if (status == 403) {
      return 'Bạn không có quyền gửi báo cáo.';
    }
    if (status == 400) {
      return 'Dữ liệu báo cáo chưa hợp lệ.';
    }
  }

  return 'Gửi báo cáo thất bại. Vui lòng thử lại.';
}

