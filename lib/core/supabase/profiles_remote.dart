import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../security/image_upload_policy.dart';

/// `profiles` rows with avatars stored in policy-protected Supabase Storage.
class ProfilesRemote {
  ProfilesRemote(this._client);

  final SupabaseClient _client;

  static const _avatarsBucket = 'avatars';

  /// Returns null if no row exists for [userId]
  Future<Profile?> fetchById(String userId) async {
    final currentUserId = _client.auth.currentUser?.id;
    final table = currentUserId == userId ? 'profiles' : 'public_profiles';
    final data = await _client
        .from(table)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phoneE164,
    DateTime? birthDate,
    String? username,
  }) async {
    final row = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phoneE164,
      'birth_date': birthDate != null
          ? '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
          : null,
    };
    if (username != null) {
      row['username'] = username.trim().toLowerCase();
    }
    await _client.from('profiles').update(row).eq('id', userId);
  }

  static String _avatarExtension(String contentType) =>
      contentType.toLowerCase().contains('png') ? '.png' : '.jpg';

  Future<void> uploadAvatarFromFile({
    required String userId,
    required File file,
    required String contentType,
  }) async {
    await uploadAvatarFromBytes(
      userId: userId,
      bytes: await file.readAsBytes(),
      contentType: contentType,
    );
  }

  Future<void> uploadAvatarFromBytes({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final validated = ImageUploadPolicy.validate(
      bytes,
      maxBytes: ImageUploadPolicy.maxAvatarBytes,
    );
    final path = '$userId/avatar${_avatarExtension(validated.contentType)}';
    await _client.storage
        .from(_avatarsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: validated.contentType,
          ),
        );
    final publicUrl = _client.storage.from(_avatarsBucket).getPublicUrl(path);
    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', userId);
  }

  /// Infers `image/jpeg` / `image/png` from [localFilePath] (picker path or name)
  static String inferImageContentType(String localFilePath) {
    final lower = localFilePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> uploadAvatarFromLocalPath({
    required String userId,
    required String localFilePath,
  }) async {
    final contentType = inferImageContentType(localFilePath);
    final Uint8List bytes = kIsWeb
        ? await XFile(localFilePath).readAsBytes()
        : await File(localFilePath).readAsBytes();
    await uploadAvatarFromBytes(
      userId: userId,
      bytes: bytes,
      contentType: contentType,
    );
  }
}
