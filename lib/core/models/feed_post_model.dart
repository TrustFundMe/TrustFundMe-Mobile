class FeedPostModel {
  FeedPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.title,
    required this.content,
    required this.visibility,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.targetId,
    this.targetType,
    this.targetName,
    this.replyCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
    this.isPinned = false,
    this.isLocked = false,
    this.hasRevisions = false,
    this.categoryId,
    this.postType = 'DISCUSSION',
  });

  final int id;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final String? title;
  final String content;
  final String visibility;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final int? targetId;
  final String? targetType;
  final String? targetName;
  int replyCount;
  int commentCount;
  int viewCount;
  int likeCount;
  bool isLiked;
  final bool isPinned;
  bool isLocked;
  /// True when the post has ≥1 entry in feed_post_revisions.
  /// Use this (not updatedAt vs createdAt) to show the "Đã chỉnh sửa" label.
  final bool hasRevisions;
  final int? categoryId;
  /// Backend `type` (e.g. DISCUSSION).
  final String postType;

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

  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    return FeedPostModel(
      id: _int(json['id']) ?? 0,
      authorId: _int(json['authorId']) ?? 0,
      authorName: (json['authorName'] as String?)?.trim().isNotEmpty == true
          ? json['authorName'] as String
          : 'Thành viên #${_int(json['authorId']) ?? 0}',
      authorAvatar: json['authorAvatar'] as String?,
      title: json['title'] as String?,
      content: (json['content'] as String?) ?? '',
      visibility: (json['visibility'] as String?) ?? 'PUBLIC',
      status: (json['status'] as String?) ?? 'DRAFT',
      createdAt: (json['createdAt'] as String?) ?? '',
      updatedAt: json['updatedAt'] as String?,
      targetId: _int(json['targetId']),
      targetType: json['targetType'] as String?,
      targetName: json['targetName'] as String?,
      replyCount: _int(json['replyCount']) ?? 0,
      commentCount: _int(json['commentCount']) ?? 0,
      viewCount: _int(json['viewCount']) ?? 0,
      likeCount: _int(json['likeCount']) ?? 0,
      isLiked: _bool(json['isLiked']),
      isPinned: _bool(json['isPinned']),
      isLocked: _bool(json['isLocked']),
      hasRevisions: _bool(json['hasRevisions']),
      categoryId: _int(json['categoryId']),
      postType: (json['type'] as String?)?.trim().isNotEmpty == true
          ? (json['type'] as String).trim()
          : 'DISCUSSION',
    );
  }

  FeedPostModel copyWithViewCount(int viewCount) {
    return FeedPostModel(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      title: title,
      content: content,
      visibility: visibility,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      targetId: targetId,
      targetType: targetType,
      targetName: targetName,
      replyCount: replyCount,
      commentCount: commentCount,
      viewCount: viewCount,
      likeCount: likeCount,
      isLiked: isLiked,
      isPinned: isPinned,
      isLocked: isLocked,
      hasRevisions: hasRevisions,
      categoryId: categoryId,
      postType: postType,
    );
  }

  FeedPostModel copyWithLike({required bool isLiked, required int likeCount}) {
    return FeedPostModel(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      title: title,
      content: content,
      visibility: visibility,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      targetId: targetId,
      targetType: targetType,
      targetName: targetName,
      replyCount: replyCount,
      commentCount: commentCount,
      viewCount: viewCount,
      likeCount: likeCount,
      isLiked: isLiked,
      isPinned: isPinned,
      isLocked: isLocked,
      hasRevisions: hasRevisions,
      categoryId: categoryId,
      postType: postType,
    );
  }
}
