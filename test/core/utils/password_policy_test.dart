import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/password_policy.dart';

void main() {
  group('signup password policy', () {
    test('accepts a password that meets every requirement', () {
      expect(signupPasswordValidationMessage('ParkdPass1!'), isNull);
      expect(
        signupPasswordRequirements('ParkdPass1!').every((rule) => rule.met),
        isTrue,
      );
    });

    test('rejects missing requirements in validation-priority order', () {
      expect(
        signupPasswordValidationMessage('Aa1!'),
        'Password must be at least 8 characters.',
      );
      expect(
        signupPasswordValidationMessage('PASSWORD1!'),
        'Password must include at least one lowercase letter.',
      );
      expect(
        signupPasswordValidationMessage('password1!'),
        'Password must include at least one uppercase letter.',
      );
      expect(
        signupPasswordValidationMessage('Password!'),
        'Password must include at least one number.',
      );
      expect(
        signupPasswordValidationMessage('Password1'),
        'Password must include at least one special character.',
      );
    });

    test('rejects overly long passwords', () {
      final password = 'Aa1!${'x' * maxSignupPasswordLength}';

      expect(
        signupPasswordValidationMessage(password),
        'Password is too long.',
      );
    });
  });
}
