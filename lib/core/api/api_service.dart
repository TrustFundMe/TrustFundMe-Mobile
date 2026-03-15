import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    
    // Thêm Interceptor để tự động đính kèm Token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        String? token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Xử lý lỗi tập trung tại đây (ví dụ: Logout nếu token hết hạn)
        return handler.next(e);
      },
    ));
  }

  // Ví dụ hàm lấy danh sách Campaign từ Backend
  Future<Response> getCampaigns() async {
    return await _dio.get("${ApiConfig.campaignUrl}/campaigns");
  }

  // Ví dụ hàm Login
  Future<Response> login(String username, String password) async {
    final response = await _dio.post(
      "${ApiConfig.identityUrl}${ApiConfig.loginEndpoint}",
      data: {
        'email': username,
        'password': password,
      },
    );
    
    if (response.statusCode == 200) {
      String token = response.data['accessToken'];
      await _storage.write(key: 'jwt_token', value: token);
    }
    return response;
  }
}
