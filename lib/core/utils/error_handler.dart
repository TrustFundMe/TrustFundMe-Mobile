import 'package:dio/dio.dart';

class ErrorHandler {
  static String handle(dynamic e) {
    if (e is DioException) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data.containsKey('message') && data['message'] != null) {
            return data['message'].toString();
          }
          if (data.containsKey('error') && data['error'] != null) {
             return data['error'].toString();
          }
        }
        
        switch (e.response!.statusCode) {
          case 400:
            return "Dữ liệu yêu cầu không hợp lệ. Vui lòng kiểm tra lại.";
          case 401:
            return "Email hoặc mật khẩu không chính xác.";
          case 403:
            return "Bạn không có quyền truy cập chức năng này.";
          case 404:
            return "Không tìm thấy nội dung yêu cầu.";
          case 500:
            return "Lỗi máy chủ hệ thống. Vui lòng thử lại sau.";
          default:
            return "Có lỗi xảy ra (Mã lỗi: ${e.response!.statusCode}). Vui lòng thử lại.";
        }
      } else if (e.type == DioExceptionType.connectionTimeout || 
                 e.type == DioExceptionType.receiveTimeout || 
                 e.type == DioExceptionType.sendTimeout) {
        return "Kết nối mạng quá hạn. Vui lòng kiểm tra lại kết nối.";
      } else if (e.type == DioExceptionType.cancel) {
        return "Yêu cầu đã bị hủy.";
      } else {
        return "Lỗi kết nối. Vui lòng kiểm tra lại mạng của bạn.";
      }
    }
    return e?.toString() ?? "Có lỗi không xác định xảy ra.";
  }
}
