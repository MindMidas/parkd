import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('userFacingAuthMessage', () {
    test('maps duplicate and rate-limit codes to actionable copy', () {
      expect(
        userFacingAuthMessage(
          const AuthException('duplicate', code: 'email_exists'),
        ),
        'Could not create an account with those details.',
      );
      expect(
        userFacingAuthMessage(
          const AuthException('rate limited', code: 'over_request_rate_limit'),
        ),
        contains('Wait a few minutes'),
      );
    });

    test('does not mislabel MFA factor conflicts as email conflicts', () {
      expect(
        userFacingAuthMessage(const AuthException('MFA factor already exists')),
        contains('authenticator setup'),
      );
    });

    test('preserves safe fallback messages', () {
      expect(
        userFacingAuthMessage(const AuthException('Service unavailable')),
        'Service unavailable',
      );
      expect(userFacingAuthMessage(Exception('offline')), contains('offline'));
    });
  });
}
