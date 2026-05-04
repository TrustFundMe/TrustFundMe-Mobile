import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý Trust Score (mới — tương đương trustScoreService trên web).
///
/// Backend: campaign-service chứa trust-score APIs.
class TrustScoreService extends BaseService {
  /// Lấy trust score của user.
  Future<Response<dynamic>> getUserScore(int userId) async {
    return dio.get('$campaignUrl/trust-score/user/$userId');
  }

  /// Lấy trust score logs (có filter).
  Future<Response<dynamic>> getTrustScoreLogs({
    int? userId,
    String? ruleKey,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, dynamic> params = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (userId != null) params['userId'] = userId;
    if (ruleKey != null) params['ruleKey'] = ruleKey;
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    return dio.get('$campaignUrl/trust-score/logs', queryParameters: params);
  }

  /// Lấy leaderboard trust score.
  Future<Response<dynamic>> getLeaderboard({int limit = 10}) async {
    return dio.get(
      '$campaignUrl/trust-score/leaderboard',
      queryParameters: <String, dynamic>{'limit': limit},
    );
  }

  /// Lấy cấu hình trust score rules (admin).
  Future<Response<dynamic>> getConfigs() async {
    return dio.get('$campaignUrl/trust-score/config');
  }
}
