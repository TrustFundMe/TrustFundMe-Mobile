import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    // Thêm Interceptor để tự động đính kèm Token cho các request tới Backend
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Chỉ đính kèm Token khi gọi tới các Backend service (Identity, Campaign, etc.)
        // KHÔNG đính kèm Token khi gọi trực tiếp tới Supabase qua REST API
        if (!options.path.contains("supabase.co")) {
          String? token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        return handler.next(e);
      },
    ));
  }

  // Lấy danh sách Campaign từ Backend
  Future<Response> getCampaigns() async {
    return await _dio.get("${ApiConfig.campaignUrl}/campaigns");
  }

  // Hàm Login
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

  // Hàm cập nhật Profile
  Future<Response> updateProfile(int userId, Map<String, dynamic> data) async {
    return await _dio.put(
      "${ApiConfig.identityUrl}${ApiConfig.userEndpoint}/$userId",
      data: data,
    );
  }

  // Hàm upload trực tiếp lên Supabase Storage (Giống FE)
  Future<String> uploadToSupabase(String filePath, int userId) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final ext = filePath.split('.').last;
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";
    
    // Sử dụng folder "avatars" giống như FE route.ts đã làm
    final path = "avatars/$userId/$fileName";
    
    // URL format: https://[project-id].supabase.co/storage/v1/object/[bucket]/[path]
    final uploadUrl = "${ApiConfig.supabaseUrl}/storage/v1/object/${ApiConfig.supabaseBucket}/$path";

    // Detect content type
    String contentType = "image/jpeg";
    if (ext.toLowerCase() == "png") contentType = "image/png";
    if (ext.toLowerCase() == "gif") contentType = "image/gif";
    if (ext.toLowerCase() == "webp") contentType = "image/webp";

    await _dio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {
          // Sử dụng Service Role Key để có toàn quyền ghi vào bucket (bypass RLS)
          "Authorization": "Bearer ${ApiConfig.supabaseKey}",
          "Content-Type": contentType,
          "x-upsert": "true",
        },
      ),
    );
    
    // Public URL format: https://[project-id].supabase.co/storage/v1/object/public/[bucket]/[path]
    return "${ApiConfig.supabaseUrl}/storage/v1/object/public/${ApiConfig.supabaseBucket}/$path";
  }

  // --- Bank Account APIs ---

  Future<Response> getMyBankAccounts() async {
    return await _dio.get("${ApiConfig.identityUrl}${ApiConfig.bankAccountEndpoint}");
  }

  Future<Response> createBankAccount(Map<String, dynamic> data) async {
    return await _dio.post(
      "${ApiConfig.identityUrl}${ApiConfig.bankAccountEndpoint}",
      data: data,
    );
  }

  Future<Response> updateBankAccount(int id, Map<String, dynamic> data) async {
    return await _dio.put(
      "${ApiConfig.identityUrl}${ApiConfig.bankAccountEndpoint}/$id",
      data: data,
    );
  }
}
