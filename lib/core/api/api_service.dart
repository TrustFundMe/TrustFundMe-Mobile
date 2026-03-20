import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    
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

  // --- Campaign APIs ---

  Future<Response> getCategories() async {
    return await _dio.get("${ApiConfig.campaignUrl}/campaign-categories");
  }

  Future<Response> createCampaign(Map<String, dynamic> data) async {
    return await _dio.post("${ApiConfig.campaignUrl}/campaigns", data: data);
  }

  Future<Response> updateCampaign(int id, Map<String, dynamic> data) async {
    return await _dio.put("${ApiConfig.campaignUrl}/campaigns/$id", data: data);
  }

  Future<Response> getUserCampaigns(int userId, {int page = 0, int size = 10}) async {
    return await _dio.get(
      "${ApiConfig.campaignUrl}/campaigns/fund-owner/$userId/paginated",
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  Future<Response> deleteCampaign(int id) async {
    return await _dio.delete("${ApiConfig.campaignUrl}/campaigns/$id");
  }

  Future<Response> getCampaign(int id) async {
    return await _dio.get("${ApiConfig.campaignUrl}/campaigns/$id");
  }

  Future<Response> getActiveGoalByCampaign(int campaignId) async {
    return await _dio.get("${ApiConfig.campaignUrl}/fundraising-goals/active/$campaignId");
  }

  Future<Response> getCampaignFirstImage(int campaignId) async {
    return await _dio.get("${ApiConfig.mediaUrl}/media/campaign/$campaignId/first");
  }

  // --- AI APIs ---

  Future<Response> generateDescription(String prompt, {String? rules}) async {
    return await _dio.post(
      "${ApiConfig.aiUrl}/generate-description",
      data: {
        'prompt': prompt,
        'rules': rules,
      },
    );
  }

  // --- Fundraising Goal APIs ---

  Future<Response> createGoal(Map<String, dynamic> data) async {
    return await _dio.post("${ApiConfig.campaignUrl}/fundraising-goals", data: data);
  }

  Future<Response> getGoalsByCampaign(int campaignId) async {
    return await _dio.get("${ApiConfig.campaignUrl}/fundraising-goals/campaign/$campaignId");
  }

  // --- Expenditure APIs ---

  Future<Response> createExpenditure(Map<String, dynamic> data) async {
    return await _dio.post("${ApiConfig.campaignUrl}/expenditures", data: data);
  }

  // --- Media Asset APIs (Campaign/Post/Expenditure) ---

  Future<Response> uploadMedia(
    File file, {
    int? campaignId,
    String? mediaType, // "PHOTO", "VIDEO", "FILE"
    String? description,
  }) async {
    String fileName = file.path.split(Platform.pathSeparator).last;
    if (fileName.isEmpty) fileName = file.path.split('/').last; // Fallback
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
      // ignore: use_null_aware_elements
      if (campaignId != null) "campaignId": campaignId,
      // ignore: use_null_aware_elements
      if (mediaType != null) "mediaType": mediaType,
      // ignore: use_null_aware_elements
      if (description != null) "description": description,
    });

    return await _dio.post(
      "${ApiConfig.mediaUrl}/media/upload",
      data: formData,
      options: Options(headers: {"Content-Type": "multipart/form-data"}),
    );
  }

  Future<Response> linkMediaToCampaign(int mediaId, int campaignId) async {
    return await _dio.patch(
      "${ApiConfig.mediaUrl}/media/$mediaId",
      data: {"campaignId": campaignId},
    );
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
