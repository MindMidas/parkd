import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloudinary/cloudinary_uploader.dart';
import '../models/profile.dart';

// public.profiles, avatar via cloudinary if configured else storage avatars bucket
class ProfilesRemote {
  ProfilesRemote(
    this._client, {
    CloudinaryUploader? cloudinary,
  }) : _cloudinary = cloudinary;

  final SupabaseClient _client;
  final CloudinaryUploader? _cloudinary;

  static const _avatarsBucket = 'avatars';

  // whether phoneE164 is not already stored on a profile
  Future<bool> isPhoneAvailable(String phoneE164) async {
    final p = phoneE164.trim();
    if (p.isEmpty) return false;
    final row =
        await _client.from('profiles').select('id').eq('phone', p).maybeSingle();
    return row == null;
  }

  // whether username is free ('profiles.username', case-insensitive in app)
  Future<bool> isUsernameAvailable(String username) async {
    final u = username.trim().toLowerCase();
    if (u.isEmpty) return false;
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', u)
        .maybeSingle();
    return row == null;
  }

  // returns null if no row exists for userId
  Future<Profile?> fetchById(String userId) async {
    final data = await _client
        .from('profiles')
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
    // If you pass email we write profiles.email (when not mid email change flow).
    String? email,
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
    if (email != null && email.trim().isNotEmpty) {
      row['email'] = email.trim();
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
    final path = '$userId/avatar${_avatarExtension(contentType)}';
    await _client.storage.from(_avatarsBucket).upload(
          path,
          file,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final publicUrl = _client.storage.from(_avatarsBucket).getPublicUrl(path);
    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl}).eq('id', userId);
  }

  Future<void> uploadAvatarFromBytes({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final cloudinary = _cloudinary;
    if (cloudinary != null) {
      final url = await cloudinary.uploadImage(
        bytes: bytes,
        contentType: contentType,
        folder: 'parkd/avatars',
        publicId: userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_'),
      );
      await _client
          .from('profiles')
          .update({'avatar_url': url}).eq('id', userId);
      return;
    }
    final path = '$userId/avatar${_avatarExtension(contentType)}';
    await _client.storage.from(_avatarsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final publicUrl = _client.storage.from(_avatarsBucket).getPublicUrl(path);
    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl}).eq('id', userId);
  }

  // infers 'image/jpeg' / 'image/png' from localFilePath (picker path or name)
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
