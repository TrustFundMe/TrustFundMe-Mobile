import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý campaigns, categories, follows, fundraising goals, AI.
class CampaignService extends BaseService {
  // ─── Campaign CRUD ────────────────────────────────────────────────────────

  /// Lấy danh sách tất cả campaigns.
  Future<Response<dynamic>> getCampaigns() async {
    return dio.get('$campaignUrl/campaigns');
  }

  /// Lấy campaigns có phân trang, filter category, tìm kiếm.
  Future<Response<dynamic>> getCampaignsPaginated({
    int page = 0,
    int size = 10,
    int? categoryId,
    String? search,
    String? status,
    String sort = 'createdAt,desc',
  }) async {
    final Map<String, dynamic> q = <String, dynamic>{
      'page': page,
      'size': size,
      'sort': sort,
    };
    if (categoryId != null) q['categoryId'] = categoryId;
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (status != null && status.isNotEmpty) q['status'] = status;
    return dio.get('$campaignUrl/campaigns', queryParameters: q);
  }

  /// Lấy campaign theo ID.
  Future<Response<dynamic>> getCampaign(int id) async {
    return dio.get('$campaignUrl/campaigns/$id');
  }

  /// Tạo campaign mới.
  Future<Response<dynamic>> createCampaign(
    Map<String, dynamic> data,
  ) async {
    return dio.post('$campaignUrl/campaigns', data: data);
  }

  /// Cập nhật campaign.
  Future<Response<dynamic>> updateCampaign(
    int id,
    Map<String, dynamic> data,
  ) async {
    return dio.put('$campaignUrl/campaigns/$id', data: data);
  }

  /// Xóa campaign.
  Future<Response<dynamic>> deleteCampaign(int id) async {
    return dio.delete('$campaignUrl/campaigns/$id');
  }

  /// Lấy campaigns theo fund owner (paginated).
  Future<Response<dynamic>> getUserCampaigns(
    int userId, {
    int page = 0,
    int size = 10,
  }) async {
    return dio.get(
      '$campaignUrl/campaigns/fund-owner/$userId/paginated',
      queryParameters: <String, dynamic>{
        'page': page,
        'size': size,
      },
    );
  }

  // ─── Categories ───────────────────────────────────────────────────────────

  /// Lấy danh sách campaign categories.
  Future<Response<dynamic>> getCategories() async {
    return dio.get('$campaignUrl/campaign-categories');
  }

  // ─── Follow / Unfollow ────────────────────────────────────────────────────

  /// Follow một campaign.
  Future<Response<dynamic>> followCampaign(int campaignId) async {
    return dio.post('$campaignUrl/campaign-follows/$campaignId');
  }

  /// Unfollow một campaign.
  Future<Response<dynamic>> unfollowCampaign(int campaignId) async {
    return dio.delete('$campaignUrl/campaign-follows/$campaignId');
  }

  /// Kiểm tra user hiện tại có follow campaign không.
  Future<Response<dynamic>> isFollowingCampaign(int campaignId) async {
    return dio.get('$campaignUrl/campaign-follows/$campaignId/me');
  }

  /// Lấy số lượng follower của campaign.
  Future<Response<dynamic>> getFollowerCount(int campaignId) async {
    return dio.get('$campaignUrl/campaign-follows/$campaignId/count');
  }

  /// Lấy danh sách followers của campaign.
  Future<Response<dynamic>> getFollowers(int campaignId) async {
    return dio.get('$campaignUrl/campaign-follows/$campaignId/followers');
  }

  // ─── Fundraising Goals ────────────────────────────────────────────────────

  /// Lấy active goal của campaign.
  Future<Response<dynamic>> getActiveGoalByCampaign(int campaignId) async {
    return dio.get('$campaignUrl/fundraising-goals/active/$campaignId');
  }

  /// Tạo fundraising goal mới.
  Future<Response<dynamic>> createGoal(
    Map<String, dynamic> data,
  ) async {
    return dio.post('$campaignUrl/fundraising-goals', data: data);
  }

  /// Lấy tất cả goals của campaign.
  Future<Response<dynamic>> getGoalsByCampaign(int campaignId) async {
    return dio.get('$campaignUrl/fundraising-goals/campaign/$campaignId');
  }

  // ─── Campaign Tasks ───────────────────────────────────────────────────────

  /// Lấy approval task theo campaign ID.
  Future<Response<dynamic>> getTaskByCampaignId(int campaignId) async {
    return dio.get('$campaignUrl/admin/tasks/campaign/$campaignId');
  }

  // ─── AI ────────────────────────────────────────────────────────────────────

  /// Tạo mô tả campaign bằng AI.
  Future<Response<dynamic>> generateDescription(
    String prompt, {
    String? rules,
  }) async {
    return dio.post(
      '$aiUrl/generate-description',
      data: <String, dynamic>{
        'prompt': prompt,
        'rules': rules,
      },
    );
  }
}
