import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageCropperHelper {
  static Future<String?> cropAvatar(String sourcePath) async {
    final CroppedFile? result = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt ảnh đại diện',
          toolbarColor: const Color(0xFFF84D43),
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          hideBottomControls: false,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Cắt ảnh đại diện',
          aspectRatioLockEnabled: true,
          rectX: 1,
          rectY: 1,
          rectWidth: 1,
          rectHeight: 1,
        ),
      ],
    );
    return result?.path;
  }

  static Future<String?> cropCampaignImage(String sourcePath) async {
    final CroppedFile? result = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cắt ảnh chiến dịch',
          toolbarColor: const Color(0xFFF84D43),
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.ratio4x3,
        ),
        IOSUiSettings(
          title: 'Cắt ảnh chiến dịch',
          aspectRatioLockEnabled: false,
        ),
      ],
    );
    return result?.path;
  }
}
