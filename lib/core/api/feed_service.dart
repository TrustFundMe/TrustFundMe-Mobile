import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý feed posts, comments, likes, forum categories.
class FeedService extends BaseService {
  // ─── Feed Posts ────────────────────────────────────────────────────────────

  /// Lấy danh sách feed posts (active, published).
  Future<Response<dynamic>> getFeedPosts({
    int page = 0,
    int size = 10,
    String sort = 'createdAt,desc',
    int? categoryId,
    int? campaignId,
  }) async {
    final Map<String, dynamic> q = <String, dynamic>{
      'page': page,
      'size': size,
      'sort': sort,
    };
    if (categoryId != null) q['categoryId'] = categoryId;
    if (campaignId != null) q['campaignId'] = campaignId;

    return dio.get('$campaignUrl/feed-posts', queryParameters: q);
  }

  /// Lấy feed posts theo target (campaign, expenditure, v.v.).
  Future<Response<dynamic>> getFeedPostsByTarget({
    required int targetId,
    required String targetType,
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    return dio.get(
      '$campaignUrl/feed-posts',
      queryParameters: <String, dynamic>{
        'targetId': targetId,
        'targetType': targetType,
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
  }

  /// Lấy feed posts của user hiện tại.
  Future<Response<dynamic>> getMyFeedPosts({
    String status = 'ALL',
    int page = 0,
    int size = 20,
    String sort = 'updatedAt,desc',
  }) async {
    return dio.get(
      '$campaignUrl/feed-posts/my',
      queryParameters: <String, dynamic>{
        'status': status,
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
  }

  /// Lấy feed post theo ID.
  Future<Response<dynamic>> getFeedPostById(int id) async {
    return dio.get('$campaignUrl/feed-posts/$id');
  }

  /// Tạo feed post mới.
  Future<Response<dynamic>> createFeedPost(Map<String, dynamic> body) async {
    return dio.post('$campaignUrl/feed-posts', data: body);
  }

  /// Cập nhật feed post.
  Future<Response<dynamic>> updateFeedPost(
    int id,
    Map<String, dynamic> body,
  ) async {
    return dio.put('$campaignUrl/feed-posts/$id', data: body);
  }

  /// Xóa feed post.
  Future<Response<dynamic>> deleteFeedPost(int id) async {
    return dio.delete('$campaignUrl/feed-posts/$id');
  }

  /// Thay đổi visibility của post.
  Future<Response<dynamic>> patchFeedPostVisibility(
    int id,
    String visibility,
  ) async {
    return dio.patch(
      '$campaignUrl/feed-posts/$id/visibility',
      data: <String, dynamic>{'visibility': visibility},
    );
  }

  // ─── Likes ────────────────────────────────────────────────────────────────

  /// Toggle like cho feed post.
  Future<Response<dynamic>> toggleFeedPostLike(int postId) async {
    return dio.post('$campaignUrl/feed-posts/$postId/like');
  }

  /// Toggle like cho comment.
  Future<Response<dynamic>> toggleFeedPostCommentLike(int commentId) async {
    return dio.post('$campaignUrl/feed-posts/comments/$commentId/like');
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  /// Lấy comments của feed post.
  Future<Response<dynamic>> getFeedPostComments(
    int postId, {
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    return dio.get(
      '$campaignUrl/feed-posts/$postId/comments',
      queryParameters: <String, dynamic>{
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
  }

  /// Tạo comment cho feed post.
  Future<Response<dynamic>> createFeedPostComment(
    int postId,
    String content, {
    int? parentCommentId,
  }) async {
    return dio.post(
      '$campaignUrl/feed-posts/$postId/comments',
      data: <String, dynamic>{
        'content': content,
        'parentCommentId': parentCommentId,
      },
    );
  }

  /// Cập nhật comment.
  Future<Response<dynamic>> updateFeedPostComment(
    int commentId,
    String content,
  ) async {
    return dio.put(
      '$campaignUrl/feed-posts/comments/$commentId',
      data: <String, dynamic>{'content': content},
    );
  }

  /// Xóa comment.
  Future<Response<dynamic>> deleteFeedPostComment(int commentId) async {
    return dio.delete('$campaignUrl/feed-posts/comments/$commentId');
  }

  // ─── Post Seen ────────────────────────────────────────────────────────────

  /// Đánh dấu đã xem post (tăng view count trên server).
  Future<Response<dynamic>> markUserPostSeen(int postId) async {
    return dio.post(
      '$campaignUrl/user-post-seen',
      data: <String, dynamic>{'postId': postId},
    );
  }

  // ─── Forum Categories ────────────────────────────────────────────────────

  /// Lấy danh sách forum/feed topic categories.
  Future<Response<dynamic>> getForumCategories() async {
    return dio.get('$campaignUrl/forum/categories');
  }

  // ─── Revisions ────────────────────────────────────────────────────────────

  /// Lấy revision history của post.
  Future<Response<dynamic>> getFeedPostRevisions(
    int postId, {
    int page = 0,
    int size = 10,
  }) async {
    return dio.get(
      '$campaignUrl/feed-posts/$postId/revisions',
      queryParameters: <String, dynamic>{'page': page, 'size': size},
    );
  }

  /// Lấy chi tiết revision.
  Future<Response<dynamic>> getFeedPostRevisionById(
    int postId,
    int revisionId,
  ) async {
    return dio.get(
      '$campaignUrl/feed-posts/$postId/revisions/$revisionId',
    );
  }
}
