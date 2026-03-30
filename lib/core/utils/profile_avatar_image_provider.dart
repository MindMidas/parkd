import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../models/profile.dart';

// prefix for [Profile.avatarUrl] when image is local file path (offline / dev)
const String kProfileAvatarLocalScheme = 'parkd-local:';

// builds an ImageProvider for a profile avatarUrl, or null for placeholder
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
