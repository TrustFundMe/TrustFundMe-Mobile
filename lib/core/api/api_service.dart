import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.receiveTimeout = const Duration(seconds: 60);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Chỉ đính kèm JWT cho các service backend của bạn.
          if (!options.path.contains('supabase.co')) {
            final String? token = await _storage.read(key: 'jwt_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response<dynamic>> getCampaigns() async {
    return _dio.get('${ApiConfig.campaignUrl}/campaigns');
  }

  Future<Response<dynamic>> getFeedPostComments(
    int postId, {
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    return _dio.get(
      '${ApiConfig.campaignUrl}/feed-posts/$postId/comments',
      queryParameters: <String, dynamic>{
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
  }

  Future<Response<dynamic>> createFeedPostComment(
    int postId,
    String content, {
    int? parentCommentId,
  }) async {
    return _dio.post(
      '${ApiConfig.campaignUrl}/feed-posts/$postId/comments',
      data: <String, dynamic>{
        'content': content,
        'parentCommentId': parentCommentId,
      },
    );
  }

  Future<Response<dynamic>> login(String username, String password) async {
    final Response<dynamic> response = await _dio.post(
      '${ApiConfig.identityUrl}${ApiConfig.loginEndpoint}',
      data: <String, dynamic>{
        'email': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final String token = response.data['accessToken'] as String;
      await _storage.write(key: 'jwt_token', value: token);
    }
    return response;
  }

  Future<Response<dynamic>> loginWithGoogle(String idToken) async {
    final Response<dynamic> response = await _dio.post(
      '${ApiConfig.identityUrl}${ApiConfig.googleLoginEndpoint}',
      data: <String, dynamic>{'idToken': idToken},
    );

    if (response.statusCode == 200) {
      final String token = response.data['accessToken'] as String;
      await _storage.write(key: 'jwt_token', value: token);
    }
    return response;
  }

  Future<Response<dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> data,
  ) async {
    return _dio.put(
      '${ApiConfig.identityUrl}${ApiConfig.userEndpoint}/$userId',
      data: data,
    );
  }

  Future<String> uploadToSupabase(String filePath, int userId) async {
    final File file = File(filePath);
    final List<int> bytes = await file.readAsBytes();
    final String ext = filePath.split('.').last;
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$ext';

    final String path = 'avatars/$userId/$fileName';
    final String uploadUrl =
        '${ApiConfig.supabaseUrl}/storage/v1/object/${ApiConfig.supabaseBucket}/$path';

    String contentType = 'image/jpeg';
    if (ext.toLowerCase() == 'png') contentType = 'image/png';
    if (ext.toLowerCase() == 'gif') contentType = 'image/gif';
    if (ext.toLowerCase() == 'webp') contentType = 'image/webp';

    await _dio.put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer ${ApiConfig.supabaseKey}',
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
      ),
    );

    return '${ApiConfig.supabaseUrl}/storage/v1/object/public/${ApiConfig.supabaseBucket}/$path';
  }

  // Campaign APIs

  Future<Response<dynamic>> getCategories() async {
    return _dio.get('${ApiConfig.campaignUrl}/campaign-categories');
  }

  Future<Response<dynamic>> createCampaign(
    Map<String, dynamic> data,
  ) async {
    return _dio.post(
      '${ApiConfig.campaignUrl}/campaigns',
      data: data,
    );
  }

  Future<Response<dynamic>> updateCampaign(
    int id,
    Map<String, dynamic> data,
  ) async {
    return _dio.put(
      '${ApiConfig.campaignUrl}/campaigns/$id',
      data: data,
    );
  }

  Future<Response<dynamic>> getUserCampaigns(int userId, {int page = 0, int size = 10}) async {
    return _dio.get(
      "${ApiConfig.campaignUrl}/campaigns/fund-owner/$userId/paginated",
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  Future<Response<dynamic>> deleteCampaign(int id) async {
    return _dio.delete("${ApiConfig.campaignUrl}/campaigns/$id");
  }

  Future<Response<dynamic>> getCampaign(int id) async {
    return _dio.get("${ApiConfig.campaignUrl}/campaigns/$id");
  }

  Future<Response<dynamic>> getActiveGoalByCampaign(int campaignId) async {
    return _dio.get("${ApiConfig.campaignUrl}/fundraising-goals/active/$campaignId");
  }

  Future<Response<dynamic>> getCampaignFirstImage(int campaignId) async {
    return _dio.get("${ApiConfig.mediaUrl}/media/campaign/$campaignId/first");
  }

  // AI APIs

  Future<Response<dynamic>> generateDescription(
    String prompt, {
    String? rules,
  }) async {
    return _dio.post(
      '${ApiConfig.aiUrl}/generate-description',
      data: <String, dynamic>{
        'prompt': prompt,
        'rules': rules,
      },
    );
  }

  // Fundraising Goal APIs

  Future<Response<dynamic>> createGoal(
    Map<String, dynamic> data,
  ) async {
    return _dio.post(
      '${ApiConfig.campaignUrl}/fundraising-goals',
      data: data,
    );
  }

  Future<Response<dynamic>> getGoalsByCampaign(int campaignId) async {
    return _dio.get(
      '${ApiConfig.campaignUrl}/fundraising-goals/campaign/$campaignId',
    );
  }

  // Expenditure APIs

  Future<Response<dynamic>> createExpenditure(
    Map<String, dynamic> data,
  ) async {
    return _dio.post(
      '${ApiConfig.campaignUrl}/expenditures',
      data: data,
    );
  }

  Future<Response<dynamic>> getExpenditureItemsByCampaign(
    int campaignId,
  ) async {
    return _dio.get(
      '${ApiConfig.campaignUrl}/expenditures/campaign/$campaignId/items',
    );
  }

  // Media Asset APIs

  Future<Response<dynamic>> uploadMedia(
    File file, {
    int? campaignId,
    String? mediaType,
    String? description,
  }) async {
    String fileName = file.path.split(Platform.pathSeparator).last;
    if (fileName.isEmpty) {
      fileName = file.path.split('/').last;
    }

    final FormData formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      if (campaignId != null) 'campaignId': campaignId,
      if (mediaType != null) 'mediaType': mediaType,
      if (description != null) 'description': description,
    });

    return _dio.post(
      '${ApiConfig.mediaUrl}/media/upload',
      data: formData,
      options: Options(
        headers: <String, String>{
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }

  Future<Response<dynamic>> linkMediaToCampaign(
    int mediaId,
    int campaignId,
  ) async {
    return _dio.patch(
      '${ApiConfig.mediaUrl}/media/$mediaId',
      data: <String, dynamic>{'campaignId': campaignId},
    );
  }

  // Bank Account APIs

  Future<Response<dynamic>> getMyBankAccounts() async {
    return _dio.get(
      '${ApiConfig.identityUrl}${ApiConfig.bankAccountEndpoint}',
    );
  }

  Future<Response<dynamic>> createBankAccount(
    Map<String, dynamic> data,
  ) async {
    return _dio.post(
      '${ApiConfig.identityUrl}${ApiConfig.bankAccountEndpoint}',
      data: data,
    );
  }

  Future<Response<dynamic>> updateBankAccount(
    int id,
    Map<String, dynamic> data,
  ) async {
    return _dio.put(
      '${ApiConfig.identityUrl}${ApiConfig.bankAccountEndpoint}/$id',
      data: data,
    );
  }

  // Payment-service APIs (Access + Refresh flow ở BE, mobile chỉ dùng access token)

  Future<Response<dynamic>> createPayment(
    Map<String, dynamic> body,
  ) async {
    return _dio.post('${ApiConfig.paymentUrl}/create', data: body);
  }

  Future<Response<dynamic>> verifyDonationPayment(int donationId) async {
    return _dio.get('${ApiConfig.paymentUrl}/donation/$donationId/verify');
  }

  Future<Response<dynamic>> getCampaignProgress(int campaignId) async {
    return _dio.get(
      '${ApiConfig.paymentUrl}/campaign/$campaignId/progress',
    );
  }

  Future<Response<dynamic>> getRecentDonors(
    int campaignId, {
    int limit = 3,
  }) async {
    return _dio.get(
      '${ApiConfig.paymentUrl}/campaign/$campaignId/recent-donations',
      queryParameters: <String, dynamic>{'limit': limit},
    );
  }

  Future<Response<dynamic>> checkExpenditureItemLimit(
    int expenditureItemId,
    int quantity,
  ) async {
    return _dio.get(
      '${ApiConfig.paymentUrl}/expenditure-item/$expenditureItemId/check',
      queryParameters: <String, dynamic>{'quantity': quantity},
    );
  }
}
