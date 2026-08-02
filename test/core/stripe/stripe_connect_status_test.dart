import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/stripe/stripe_connect_remote.dart';

void main() {
  test('StripeConnectStatus parses ready and url', () {
    final status = StripeConnectStatus.fromJson({
      'connected': true,
      'charges_enabled': true,
      'details_submitted': true,
      'payouts_ready': true,
      'url': 'https://connect.stripe.test/setup',
    });
    expect(status.payoutsReady, isTrue);
    expect(status.url, 'https://connect.stripe.test/setup');
  });

  test('StripeConnectStatus treats blank url as null', () {
    final status = StripeConnectStatus.fromJson({
      'connected': false,
      'charges_enabled': false,
      'details_submitted': false,
      'payouts_ready': false,
      'url': '   ',
    });
    expect(status.url, isNull);
    expect(status.connected, isFalse);
  });
}
