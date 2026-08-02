import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../theme/app_colors.dart';

Future<String?> cropListingHeroPhoto({
  required BuildContext context,
  required String sourcePath,
}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
    maxWidth: 2048,
    maxHeight: 1536,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 88,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop parking photo',
        toolbarColor: AppColors.primaryBlue,
        toolbarWidgetColor: AppColors.onPrimary,
        statusBarLight: false,
        activeControlsWidgetColor: AppColors.primaryBlue,
        lockAspectRatio: true,
        initAspectRatio: CropAspectRatioPreset.ratio4x3,
      ),
      IOSUiSettings(
        title: 'Crop parking photo',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
      ),
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.dialog,
        size: const CropperSize(width: 560, height: 420),
        cropBoxResizable: false,
      ),
    ],
  );
  return cropped?.path;
}

// Square output; circle overlay on iOS/Android. Shown as a circle in the app UI
Future<String?> cropProfileAvatar({
  required BuildContext context,
  required String sourcePath,
}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    maxWidth: 1024,
    maxHeight: 1024,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop profile photo',
        toolbarColor: AppColors.primaryBlue,
        toolbarWidgetColor: AppColors.onPrimary,
        statusBarLight: false,
        activeControlsWidgetColor: AppColors.primaryBlue,
        lockAspectRatio: true,
        initAspectRatio: CropAspectRatioPreset.square,
        cropStyle: CropStyle.circle,
      ),
      IOSUiSettings(
        title: 'Crop profile photo',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        cropStyle: CropStyle.circle,
      ),
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.dialog,
        size: const CropperSize(width: 480, height: 480),
        cropBoxResizable: false,
      ),
    ],
  );
  return cropped?.path;
}
