import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/security/image_upload_policy.dart';

void main() {
  group('ImageUploadPolicy', () {
    test('accepts JPEG and PNG bytes by magic signature', () {
      final jpeg = ImageUploadPolicy.validate(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00]),
        maxBytes: 32,
      );
      final png = ImageUploadPolicy.validate(
        Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          0x00,
        ]),
        maxBytes: 32,
      );

      expect(jpeg.contentType, 'image/jpeg');
      expect(jpeg.extension, 'jpg');
      expect(png.contentType, 'image/png');
      expect(png.extension, 'png');
    });

    test('rejects empty, oversized, and unsupported image data', () {
      expect(
        () => ImageUploadPolicy.validate(Uint8List(0), maxBytes: 32),
        throwsA(isA<ImageUploadPolicyException>()),
      );
      expect(
        () => ImageUploadPolicy.validate(Uint8List(5), maxBytes: 4),
        throwsA(isA<ImageUploadPolicyException>()),
      );
      expect(
        () => ImageUploadPolicy.validate(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
          maxBytes: 32,
        ),
        throwsA(isA<ImageUploadPolicyException>()),
      );
    });

    test('rejects truncated signatures instead of trusting an extension', () {
      expect(
        () => ImageUploadPolicy.validate(
          Uint8List.fromList([0xff, 0xd8]),
          maxBytes: 32,
        ),
        throwsA(isA<ImageUploadPolicyException>()),
      );
      expect(
        () => ImageUploadPolicy.validate(
          Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
          maxBytes: 32,
        ),
        throwsA(isA<ImageUploadPolicyException>()),
      );
    });
  });
}
