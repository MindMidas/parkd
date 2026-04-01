import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../models/profile.dart';

// Local avatar paths use this prefix on Profile.avatarUrl for dev or offline.
const String kProfileAvatarLocalScheme = 'parkd-local:';

// Network or file ImageProvider for avatarUrl, or null to show placeholder.
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
