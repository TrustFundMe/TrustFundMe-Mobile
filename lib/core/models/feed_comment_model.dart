class FeedCommentModel {
  FeedCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentCommentId,
    required this.content,
    required this.likeCount,
    required this.isLiked,
    required this.authorName,
    this.authorAvatar,
    required this.createdAt,
    this.updatedAt,
    this.replies = const <FeedCommentModel>[],
  });

  final int id;
  final int postId;
  final int userId;
  final int? parentCommentId;
  String content;
  int likeCount;
  bool isLiked;
  String authorName;
  final String? authorAvatar;
  final String createdAt;
  final String? updatedAt;
  List<FeedCommentModel> replies;

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return false;
  }

  factory FeedCommentModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawReplies = json['replies'] as List<dynamic>? ?? <dynamic>[];
    return FeedCommentModel(
      id: _int(json['id'])!,
      postId: _int(json['postId']) ?? 0,
      userId: _int(json['userId']) ?? 0,
      parentCommentId: _int(json['parentCommentId']),
      content: (json['content'] as String?) ?? '',
      likeCount: _int(json['likeCount']) ?? 0,
      isLiked: _bool(json['isLiked']),
      authorName: (json['authorName'] as String?)?.trim().isNotEmpty == true
          ? json['authorName'] as String
          : 'Thành viên #${_int(json['userId']) ?? 0}',
      authorAvatar: json['authorAvatar'] as String?,
      createdAt: (json['createdAt'] as String?) ?? '',
      updatedAt: json['updatedAt'] as String?,
      replies: rawReplies
          .whereType<Map<String, dynamic>>()
          .map(FeedCommentModel.fromJson)
          .toList(),
    );
  }

  FeedCommentModel copyWithLike({required int likeCount, required bool isLiked}) {
    return FeedCommentModel(
      id: id,
      postId: postId,
      userId: userId,
      parentCommentId: parentCommentId,
      content: content,
      likeCount: likeCount,
      isLiked: isLiked,
      authorName: authorName,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
      updatedAt: updatedAt,
      replies: replies,
    );
  }
}
