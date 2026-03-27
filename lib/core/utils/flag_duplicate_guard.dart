import '../api/api_service.dart';

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

Future<bool> hasSubmittedFlag(
  ApiService api, {
  int? postId,
  int? campaignId,
}) async {
  if (postId == null && campaignId == null) return false;
  try {
    final res = await api.getMyFlags(page: 0, size: 200);
    final dynamic data = res.data;
    List<dynamic> content = <dynamic>[];
    if (data is Map<String, dynamic>) {
      final dynamic c = data['content'];
      if (c is List<dynamic>) content = c;
    } else if (data is List<dynamic>) {
      content = data;
    }

    for (final dynamic item in content) {
      if (item is! Map<String, dynamic>) continue;
      final int? pId = _toInt(item['postId']);
      final int? cId = _toInt(item['campaignId']);
      if (postId != null && pId == postId) return true;
      if (campaignId != null && cId == campaignId) return true;
    }
  } catch (_) {
    // Soft-fail: if pre-check fails, still allow submit API call.
  }
  return false;
}

