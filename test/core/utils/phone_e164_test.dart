import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/phone_e164.dart';

void main() {
  group('normalizePhoneToE164', () {
    test('normalizes North American numbers', () {
      expect(normalizePhoneToE164('(519) 555-1234'), '+15195551234');
      expect(normalizePhoneToE164('1-519-555-1234'), '+15195551234');
    });

    test('normalizes international numbers', () {
      expect(normalizePhoneToE164('+44 20 7946 0958'), '+442079460958');
    });

    test('rejects missing and too-short input', () {
      expect(normalizePhoneToE164(''), isNull);
      expect(normalizePhoneToE164('12345'), isNull);
    });
  });
}
