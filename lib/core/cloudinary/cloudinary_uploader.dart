import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Unsigned preset uploadsm env missing to null & app uses supabase storage
class CloudinaryUploader {
  CloudinaryUploader({
    required String cloudName,
    required String uploadPreset,
  })  : _cloudName = cloudName,
        _uploadPreset = uploadPreset;

  final String _cloudName;
  final String _uploadPreset;

  static CloudinaryUploader? tryFromDotEnv() {
    final cloud = dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim();
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.trim();
    if (cloud == null ||
        cloud.isEmpty ||
        preset == null ||
        preset.isEmpty) {
      return null;
    }
    return CloudinaryUploader(cloudName: cloud, uploadPreset: preset);
  }

  // Returns Cloudinary secure_url
  Future<String> uploadImage({
    required Uint8List bytes,
    required String contentType,
    required String folder,
    String? publicId,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = folder;
    if (publicId != null && publicId.isNotEmpty) {
      request.fields['public_id'] = publicId;
    }
    final filename =
        contentType.toLowerCase().contains('png') ? 'upload.png' : 'upload.jpg';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinaryUploadException(
        'Cloudinary upload failed (${response.statusCode}): ${response.body}',
      );
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const CloudinaryUploadException('Invalid Cloudinary response');
    }
    final url = json['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const CloudinaryUploadException('Missing secure_url in response');
    }
    return url;
  }
}

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message);
  final String message;

  @override
  String toString() => 'CloudinaryUploadException: $message';
}
