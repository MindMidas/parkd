import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../models/profile.dart';

// Prefix for Profile.avatarUrl when the image is a local development file.
const String kProfileAvatarLocalScheme = 'parkd-local:';

// Builds an ImageProvider for a profile avatarUrl.
ImageProvider? profileAvatarImageProvider(Profile? profile) {
  final url = profile?.avatarUrl?.trim();
  if (url == null || url.isEmpty) return null;
  if (url.startsWith(kProfileAvatarLocalScheme)) {
    if (kIsWeb) return null;
    final path = url.substring(kProfileAvatarLocalScheme.length);
    return FileImage(File(path));
  }
  return NetworkImage(url);
}
