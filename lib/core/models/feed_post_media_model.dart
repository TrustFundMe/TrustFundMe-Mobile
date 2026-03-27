/// Normalized media row from media-service (tolerates alternate JSON keys).
class FeedPostMediaItem {
  const FeedPostMediaItem({
    required this.id,
    required this.url,
    required this.mediaType,
    this.fileName,
    this.mimeType,
  });

  final int id;
  final String url;
  /// Backend enum: PHOTO, VIDEO, FILE (or lowercase from some gateways).
  final String mediaType;
  final String? fileName;
  final String? mimeType;

  bool get isPhoto =>
      mediaType.toUpperCase() == 'PHOTO' || _looksLikeImageUrl(url);

  bool get isVideo => mediaType.toUpperCase() == 'VIDEO';

  bool get isFile =>
      mediaType.toUpperCase() == 'FILE' ||
      (!isPhoto && !isVideo && url.isNotEmpty);

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  factory FeedPostMediaItem.fromJson(Map<String, dynamic> json) {
    final int id = _int(json['id']) ?? 0;
    final String url = _str(json['url']);
    final String type = _str(json['mediaType']).isNotEmpty
        ? _str(json['mediaType'])
        : (_str(json['type']).isNotEmpty ? _str(json['type']) : 'FILE');
    final String? name = json['fileName'] as String? ??
        json['filename'] as String? ??
        json['originalFilename'] as String?;
    final String? mime = json['contentType'] as String? ??
        json['mimeType'] as String? ??
        json['mime'] as String?;

    return FeedPostMediaItem(
      id: id,
      url: url,
      mediaType: type,
      fileName: name,
      mimeType: mime,
    );
  }
}

bool _looksLikeImageUrl(String u) {
  final String lower = u.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.contains('/image');
}

/// Parses list or single map from `GET /api/media/posts/{postId}`.
List<FeedPostMediaItem> parseFeedPostMediaResponse(dynamic data) {
  if (data == null) return <FeedPostMediaItem>[];
  if (data is List<dynamic>) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedPostMediaItem.fromJson)
        .where((FeedPostMediaItem e) => e.url.isNotEmpty)
        .toList();
  }
  if (data is Map<String, dynamic>) {
    final List<dynamic>? inner = data['content'] as List<dynamic>? ??
        data['items'] as List<dynamic>? ??
        data['data'] as List<dynamic>?;
    if (inner != null) {
      return inner
          .whereType<Map<String, dynamic>>()
          .map(FeedPostMediaItem.fromJson)
          .where((FeedPostMediaItem e) => e.url.isNotEmpty)
          .toList();
    }
  }
  return <FeedPostMediaItem>[];
}
