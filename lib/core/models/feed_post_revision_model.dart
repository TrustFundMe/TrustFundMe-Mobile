class RevisionMediaItem {
  RevisionMediaItem({
    this.mediaId,
    required this.url,
    this.mediaType,
    this.sortOrder,
  });

  final int? mediaId;
  final String url;
  final String? mediaType;
  final int? sortOrder;

  factory RevisionMediaItem.fromJson(Map<String, dynamic> json) {
    return RevisionMediaItem(
      // Handle both int and String representations (e.g. "1" vs 1)
      mediaId: json['mediaId'] is int
          ? json['mediaId'] as int
          : int.tryParse(json['mediaId']?.toString() ?? ''),
      url: (json['url'] as String?) ?? '',
      mediaType: json['mediaType'] as String?,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
    );
  }
}

class FeedPostRevisionModel {
  FeedPostRevisionModel({
    required this.id,
    required this.postId,
    required this.revisionNo,
    this.title,
    required this.content,
    required this.status,
    required this.mediaSnapshot,
    required this.editedBy,
    this.editedByName,
    this.editNote,
    required this.createdAt,
  });

  final int id;
  final int postId;
  final int revisionNo;
  final String? title;
  final String content;
  final String status;
  final List<RevisionMediaItem> mediaSnapshot;
  final int editedBy;
  final String? editedByName;
  final String? editNote;
  final String createdAt;

  static int _int(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  factory FeedPostRevisionModel.fromJson(Map<String, dynamic> json) {
    final List<RevisionMediaItem> media = <RevisionMediaItem>[];
    final dynamic raw = json['mediaSnapshot'];
    if (raw is List) {
      for (final dynamic item in raw) {
        if (item is Map<String, dynamic>) {
          media.add(RevisionMediaItem.fromJson(item));
        }
      }
    }

    final int parsedId = _int(json['id']);
    assert(parsedId > 0, 'FeedPostRevisionModel: parsed id=$parsedId — JSON parse may have failed');

    return FeedPostRevisionModel(
      id: parsedId,
      postId: _int(json['postId']),
      revisionNo: _int(json['revisionNo']),
      title: json['title'] as String?,
      content: (json['content'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      mediaSnapshot: media,
      editedBy: _int(json['editedBy']),
      editedByName: json['editedByName'] as String?,
      editNote: json['editNote'] as String?,
      createdAt: (json['createdAt'] as String?) ?? '',
    );
  }
}
