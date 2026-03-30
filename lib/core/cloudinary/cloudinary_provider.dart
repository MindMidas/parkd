import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloudinary_uploader.dart';

final cloudinaryUploaderProvider = Provider<CloudinaryUploader?>((ref) {
  return CloudinaryUploader.tryFromDotEnv();
});
