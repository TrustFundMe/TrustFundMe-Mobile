import 'dart:io';
import 'package:dio/dio.dart';
import 'base_service.dart';

/// Service xử lý media upload, get, update, delete.
class MediaService extends BaseService {
  /// Upload media file.
  Future<Response<dynamic>> uploadMedia(
    File file, {
    int? postId,
    int? campaignId,
    int? expenditureId,
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
      if (postId != null) 'postId': postId,
      if (campaignId != null) 'campaignId': campaignId,
      if (expenditureId != null) 'expenditureId': expenditureId,
      if (mediaType != null) 'mediaType': mediaType,
      if (description != null) 'description': description,
    });

    return dio.post(
      '$mediaUrl/media/upload',
      data: formData,
      options: Options(
        headers: <String, String>{
          'Content-Type': 'multipart/form-data',
        },
      ),
    );
  }

  /// Lấy media theo post ID.
  Future<Response<dynamic>> getMediaByPostId(int postId) async {
    return dio.get('$mediaUrl/media/posts/$postId');
  }

  /// Lấy ảnh đầu tiên của campaign.
  Future<Response<dynamic>> getCampaignFirstImage(int campaignId) async {
    return dio.get('$mediaUrl/media/campaign/$campaignId/first');
  }

  /// Cập nhật media metadata.
  Future<Response<dynamic>> updateMedia(
    int mediaId,
    Map<String, dynamic> body,
  ) async {
    return dio.patch('$mediaUrl/media/$mediaId', data: body);
  }

  /// Xóa media.
  Future<Response<dynamic>> deleteMedia(int mediaId) async {
    return dio.delete('$mediaUrl/media/$mediaId');
  }

  /// Link media tới campaign.
  Future<Response<dynamic>> linkMediaToCampaign(
    int mediaId,
    int campaignId,
  ) async {
    return dio.patch(
      '$mediaUrl/media/$mediaId',
      data: <String, dynamic>{'campaignId': campaignId},
    );
  }

  /// Lấy tất cả media theo campaign ID.
  Future<Response<dynamic>> getMediaByCampaignId(int campaignId) async {
    return dio.get('$mediaUrl/media/campaign/$campaignId');
  }
}
