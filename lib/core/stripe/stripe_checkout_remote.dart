import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

// Edge Functions call Stripe; app only uses publishable key + client_secret
class StripeCheckoutRemote {
  StripeCheckoutRemote(this._client);

  final SupabaseClient _client;

  static const _createIntent = 'create-payment-intent';
  static const _finalize = 'finalize-reservation-payment';
  static const _cancelReservation = 'cancel-reservation';
  static const _createSetupIntent = 'create-setup-intent';
  static const _completePaymentMethodSetup = 'complete-payment-method-setup';

  static const Duration _sessionRefreshTimeout = Duration(seconds: 25);
  static const Duration _edgeInvokeTimeout = Duration(seconds: 45);

  // Refresh the session so Edge receives a valid JWT.
  Future<void> _ensureSessionReadyForEdge() async {
    final auth = _client.auth;
    if (auth.currentSession == null) {
      throw const StripeCheckoutRemoteException(
        'You must be signed in to save a card or pay.',
      );
    }
    try {
      await auth.refreshSession().timeout(
        _sessionRefreshTimeout,
        onTimeout: () => throw TimeoutException('refreshSession'),
      );
    } catch (_) {
      final s = auth.currentSession;
      if (s == null || s.isExpired) {
        throw const StripeCheckoutRemoteException(
          'Your session expired or could not be refreshed. Sign out, sign in again, then retry.',
        );
      }
    }
  }

  Future<FunctionResponse> _invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    await _ensureSessionReadyForEdge();
    try {
      final res = await _client.functions
          .invoke(functionName, body: body ?? const <String, dynamic>{})
          .timeout(
            _edgeInvokeTimeout,
            onTimeout: () {
              throw StripeCheckoutRemoteException(
                'Payment service did not respond in ${_edgeInvokeTimeout.inSeconds}s. '
                'Check your connection and that Edge Functions are deployed.',
              );
            },
          );
      return res;
    } on FunctionException catch (e) {
      if (e.status == 401) {
        throw StripeCheckoutRemoteException(_authFailureMessage(e));
      }
      throw StripeCheckoutRemoteException(_edgeFunctionErrorMessage(e));
    }
  }

  static String _authFailureMessage(FunctionException e) {
    final d = e.details;
    if (d is Map) {
      final msg = d['message'];
      if (msg is String && msg.isNotEmpty) {
        return 'Sign-in was rejected for payment ($msg). Sign out, sign in again, '
            'and confirm SUPABASE_URL and SUPABASE_ANON_KEY match your project.';
      }
    }
    return 'Could not verify your session for payment. Sign out and sign in again.';
  }

  static String _edgeFunctionErrorMessage(FunctionException e) {
    final d = e.details;
    if (d is Map) {
      final err = d['error'];
      if (err is String && err.isNotEmpty) {
        return err;
      }
      final msg = d['message'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return 'Payment service error (${e.status}). Try again.';
  }

  // Starts or resumes one server-authoritative checkout.
  Future<TrustedCheckoutSession> createCheckout({
    required String listingId,
    required DateTime startTime,
    required DateTime endTime,
    required String idempotencyKey,
    required bool web,
    String? paymentMethodId,
    Uri? successUrl,
    Uri? cancelUrl,
  }) async {
    final body = <String, dynamic>{
      'listing_id': listingId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'idempotency_key': idempotencyKey,
      'platform': web ? 'web' : 'mobile',
    };
    if (paymentMethodId != null && paymentMethodId.trim().isNotEmpty) {
      body['payment_method_id'] = paymentMethodId.trim();
    }
    if (web) {
      if (successUrl == null || cancelUrl == null) {
        throw const StripeCheckoutRemoteException(
          'Web checkout requires success and cancellation URLs.',
        );
      }
      body['success_url'] = successUrl.toString();
      body['cancel_url'] = cancelUrl.toString();
    }
    final res = await _invoke(_createIntent, body: body);
    if (res.status != 200) {
      throw StripeCheckoutRemoteException(
        _messageFromResponse(res.data, 'Could not start payment'),
      );
    }
    final data = res.data;
    if (data is! Map) {
      throw const StripeCheckoutRemoteException('Invalid payment response');
    }
    return TrustedCheckoutSession.fromJson(Map<String, dynamic>.from(data));
  }

  // Creates a URL-safe key that is reused for every retry from one checkout UI.
  static String newIdempotencyKey() {
    final random = Random.secure();
    final entropy = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = entropy
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'checkout_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  Future<String> createSetupIntentClientSecret({
    required String idempotencyKey,
  }) async {
    final res = await _invoke(
      _createSetupIntent,
      body: {'idempotency_key': idempotencyKey},
    );
    if (res.status != 200) {
      throw StripeCheckoutRemoteException(
        _messageFromResponse(res.data, 'Could not start card setup'),
      );
    }
    final data = res.data;
    if (data is! Map) {
      throw const StripeCheckoutRemoteException('Invalid setup response');
    }
    final map = Map<String, dynamic>.from(data);
    final secret = map['client_secret'] as String?;
    if (secret == null || secret.isEmpty) {
      throw const StripeCheckoutRemoteException('Missing setup client secret');
    }
    return secret;
  }

  // Returns new payment_methods id when present
  Future<String?> completePaymentMethodSetup({
    required String setupIntentId,
  }) async {
    final res = await _invoke(
      _completePaymentMethodSetup,
      body: {'setup_intent_id': setupIntentId},
    );
    if (res.status != 200) {
      throw StripeCheckoutRemoteException(
        _messageFromResponse(res.data, 'Could not save card'),
      );
    }
    final data = res.data;
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final id = map['payment_method_id'] as String?;
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  Future<void> finalizePayment({required String paymentIntentId}) async {
    final res = await _invoke(
      _finalize,
      body: {'payment_intent_id': paymentIntentId},
    );
    if (res.status != 200) {
      throw StripeCheckoutRemoteException(
        _messageFromResponse(res.data, 'Could not confirm payment'),
      );
    }
  }

  // Cancels a confirmed upcoming reservation. Refunds when policy allows.
  Future<CancelReservationResult> cancelReservation({
    required String reservationId,
  }) async {
    final res = await _invoke(
      _cancelReservation,
      body: {'reservation_id': reservationId},
    );
    if (res.status != 200) {
      throw StripeCheckoutRemoteException(
        _messageFromResponse(res.data, 'Could not cancel reservation'),
      );
    }
    final data = res.data;
    if (data is! Map) {
      throw const StripeCheckoutRemoteException(
        'Invalid cancel reservation response',
      );
    }
    final map = Map<String, dynamic>.from(data);
    return CancelReservationResult(
      outcome: (map['outcome'] as String?) ?? 'cancelled',
      refunded: map['refunded'] == true,
    );
  }

  static String _messageFromResponse(Object? data, String fallback) {
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return fallback;
  }
}

class CancelReservationResult {
  const CancelReservationResult({
    required this.outcome,
    required this.refunded,
  });

  final String outcome;
  final bool refunded;
}

class StripeCheckoutRemoteException implements Exception {
  const StripeCheckoutRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TrustedCheckoutSession {
  const TrustedCheckoutSession({
    required this.reservationId,
    required this.paymentId,
    required this.subtotalCents,
    required this.serviceFeeCents,
    required this.amountCents,
    required this.currency,
    this.clientSecret,
    this.checkoutUrl,
  });

  final String reservationId;
  final String paymentId;
  final int subtotalCents;
  final int serviceFeeCents;
  final int amountCents;
  final String currency;
  final String? clientSecret;
  final Uri? checkoutUrl;

  double get subtotal => subtotalCents / 100;
  double get serviceFee => serviceFeeCents / 100;
  double get total => amountCents / 100;

  factory TrustedCheckoutSession.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw StripeCheckoutRemoteException(
          'Payment service returned an invalid $key.',
        );
      }
      return value.trim();
    }

    int requiredCents(String key) {
      final value = json[key];
      if (value is! num || value.isNaN || value.isInfinite) {
        throw StripeCheckoutRemoteException(
          'Payment service returned an invalid $key.',
        );
      }
      final cents = value.toInt();
      if (cents < 0 || cents != value) {
        throw StripeCheckoutRemoteException(
          'Payment service returned an invalid $key.',
        );
      }
      return cents;
    }

    final subtotal = requiredCents('subtotal_cents');
    final fee = requiredCents('service_fee_cents');
    final total = requiredCents('amount_cents');
    if (subtotal + fee != total || total < 50) {
      throw const StripeCheckoutRemoteException(
        'Payment service returned inconsistent totals.',
      );
    }

    final clientSecret = json['client_secret'];
    final checkoutUrlRaw = json['checkout_url'];
    final checkoutUrl = checkoutUrlRaw is String
        ? Uri.tryParse(checkoutUrlRaw.trim())
        : null;
    final secret = clientSecret is String && clientSecret.trim().isNotEmpty
        ? clientSecret.trim()
        : null;
    if (secret == null &&
        (checkoutUrl == null ||
            checkoutUrl.scheme != 'https' ||
            checkoutUrl.host.isEmpty)) {
      throw const StripeCheckoutRemoteException(
        'Payment service returned no usable checkout destination.',
      );
    }

    return TrustedCheckoutSession(
      reservationId: requiredString('reservation_id'),
      paymentId: requiredString('payment_id'),
      subtotalCents: subtotal,
      serviceFeeCents: fee,
      amountCents: total,
      currency: requiredString('currency').toUpperCase(),
      clientSecret: secret,
      checkoutUrl: checkoutUrl,
    );
  }
}
