import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/validation/form_validators.dart';

void main() {
  group('FormValidators', () {
    test('validates account identity fields', () {
      expect(FormValidators.fullName('Jane Driver'), isNull);
      expect(FormValidators.fullName('J'), isNotNull);
      expect(FormValidators.username('mind_midas'), isNull);
      expect(FormValidators.username('ab'), isNotNull);
      expect(FormValidators.username('bad-name'), isNotNull);
    });

    test('validates email and phone fields', () {
      expect(FormValidators.email('driver@example.com'), isNull);
      expect(FormValidators.email('not-email'), isNotNull);
      expect(FormValidators.phoneOptional(''), isNull);
      expect(FormValidators.phoneOptional('(519) 555-1234'), isNull);
      expect(FormValidators.phoneRequired('123'), isNotNull);
    });

    test('validates OTP and MFA codes', () {
      expect(FormValidators.signupEmailOtp('123456'), isNull);
      expect(FormValidators.signupEmailOtp('12345678'), isNull);
      expect(FormValidators.signupEmailOtp('12 34 56'), isNull);
      expect(FormValidators.signupEmailOtp('abc123'), isNotNull);
      expect(FormValidators.signupSmsOtp('123456'), isNull);
      expect(FormValidators.signupSmsOtp('12345'), isNotNull);
      expect(FormValidators.totpCode('654321'), isNull);
      expect(FormValidators.totpCode('65432'), isNotNull);
    });

    test('validates password confirmation', () {
      final controller = TextEditingController(text: 'ParkdPass1!');
      addTearDown(controller.dispose);

      expect(FormValidators.matchPassword(controller)('ParkdPass1!'), isNull);
      expect(
        FormValidators.matchPassword(controller)('ParkdPass2!'),
        isNotNull,
      );
    });
  });
}
