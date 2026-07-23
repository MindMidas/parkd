import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/stripe/stripe_checkout_remote.dart';

void main() {
  group('TrustedCheckoutSession', () {
    Map<String, dynamic> response({
      int subtotalCents = 1000,
      int serviceFeeCents = 150,
      int amountCents = 1150,
    }) {
      return {
        'reservation_id': 'reservation-1',
        'payment_id': 'payment-1',
        'subtotal_cents': subtotalCents,
        'service_fee_cents': serviceFeeCents,
        'amount_cents': amountCents,
        'currency': 'cad',
      };
    }

    test(
      'parses a mobile client-secret response using integer minor units',
      () {
        final checkout = TrustedCheckoutSession.fromJson({
          ...response(),
          'client_secret': 'pi_test_123_secret_test',
        });

        expect(checkout.reservationId, 'reservation-1');
        expect(checkout.paymentId, 'payment-1');
        expect(checkout.currency, 'CAD');
        expect(checkout.subtotal, 10);
        expect(checkout.serviceFee, 1.5);
        expect(checkout.total, 11.5);
        expect(checkout.clientSecret, 'pi_test_123_secret_test');
        expect(checkout.checkoutUrl, isNull);
      },
    );

    test('parses an HTTPS Stripe-hosted web checkout response', () {
      final checkout = TrustedCheckoutSession.fromJson({
        ...response(),
        'checkout_url': 'https://checkout.stripe.test/session/test-1',
      });

      expect(checkout.clientSecret, isNull);
      expect(
        checkout.checkoutUrl,
        Uri.parse('https://checkout.stripe.test/session/test-1'),
      );
    });

    test('rejects inconsistent or fractional monetary totals', () {
      expect(
        () => TrustedCheckoutSession.fromJson(
          response(amountCents: 1149)..['client_secret'] = 'secret',
        ),
        throwsA(isA<StripeCheckoutRemoteException>()),
      );
      expect(
        () => TrustedCheckoutSession.fromJson({
          ...response(),
          'subtotal_cents': 1000.5,
          'client_secret': 'secret',
        }),
        throwsA(isA<StripeCheckoutRemoteException>()),
      );
    });

    test('rejects missing and non-HTTPS checkout destinations', () {
      expect(
        () => TrustedCheckoutSession.fromJson(response()),
        throwsA(isA<StripeCheckoutRemoteException>()),
      );
      expect(
        () => TrustedCheckoutSession.fromJson({
          ...response(),
          'checkout_url': 'http://checkout.example.test/session',
        }),
        throwsA(isA<StripeCheckoutRemoteException>()),
      );
      expect(
        () => TrustedCheckoutSession.fromJson({
          ...response(),
          'checkout_url': 'javascript:alert(1)',
        }),
        throwsA(isA<StripeCheckoutRemoteException>()),
      );
    });
  });
}
