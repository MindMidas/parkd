import 'dart:typed_data';

class ImageUploadPolicy {
  const ImageUploadPolicy._();

  static const int maxAvatarBytes = 3 * 1024 * 1024;
  static const int maxListingPhotoBytes = 5 * 1024 * 1024;

  static ({String contentType, String extension}) validate(
    Uint8List bytes, {
    required int maxBytes,
  }) {
    if (bytes.isEmpty) {
      throw const ImageUploadPolicyException('The image file is empty.');
    }
    if (bytes.lengthInBytes > maxBytes) {
      final maxMb = maxBytes ~/ (1024 * 1024);
      throw ImageUploadPolicyException(
        'The image is too large. Choose an image under $maxMb MB.',
      );
    }

    if (_isJpeg(bytes)) {
      return (contentType: 'image/jpeg', extension: 'jpg');
    }
    if (_isPng(bytes)) {
      return (contentType: 'image/png', extension: 'png');
    }
    throw const ImageUploadPolicyException(
      'Only valid JPEG and PNG images are supported.',
    );
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;

  static bool _isPng(Uint8List bytes) {
    const signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }
}

class ImageUploadPolicyException implements Exception {
  const ImageUploadPolicyException(this.message);

  final String message;

  @override
  String toString() => message;
}
