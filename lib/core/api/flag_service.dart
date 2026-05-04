import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý flags/reports cho campaigns và posts.
///
/// Tương đương [flagService] trên web app (danbox).
class FlagService extends BaseService {
  /// Submit flag/report.
  Future<Response<dynamic>> submitFlag({
    int? postId,
    int? campaignId,
    required String reason,
  }) async {
    return dio.post(
      '$campaignUrl/flags',
      data: <String, dynamic>{
        if (postId != null) 'postId': postId,
        if (campaignId != null) 'campaignId': campaignId,
        'reason': reason,
      },
    );
  }

  /// Lấy flags của user hiện tại.
  Future<Response<dynamic>> getMyFlags({
    int page = 0,
    int size = 20,
  }) async {
    return dio.get(
      '$campaignUrl/flags/me',
      queryParameters: <String, dynamic>{
        'page': page,
        'size': size,
      },
    );
  }

  /// Flag một campaign (convenience helper).
  Future<Response<dynamic>> flagCampaign(
    int campaignId,
    String reason,
  ) async {
    return submitFlag(campaignId: campaignId, reason: reason);
  }

  /// Flag một feed post (convenience helper).
  Future<Response<dynamic>> flagPost(int postId, String reason) async {
    return submitFlag(postId: postId, reason: reason);
  }

  /// Lấy flag theo ID (admin/staff).
  Future<Response<dynamic>> getFlagById(int flagId) async {
    return dio.get('$campaignUrl/flags/$flagId');
  }

  /// Lấy flags theo campaign (admin/staff).
  Future<Response<dynamic>> getFlagsByCampaign(
    int campaignId, {
    int page = 0,
    int size = 10,
  }) async {
    return dio.get(
      '$campaignUrl/flags/campaign/$campaignId',
      queryParameters: <String, dynamic>{'page': page, 'size': size},
    );
  }

  /// Lấy flags theo post (admin/staff).
  Future<Response<dynamic>> getFlagsByPost(
    int postId, {
    int page = 0,
    int size = 10,
  }) async {
    return dio.get(
      '$campaignUrl/flags/post/$postId',
      queryParameters: <String, dynamic>{'page': page, 'size': size},
    );
  }
}
