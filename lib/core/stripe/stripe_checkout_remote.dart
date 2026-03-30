import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// Edge Functions call Stripe, app only uses publishable key + client_secret
class StripeCheckoutRemote {
  StripeCheckoutRemote(this._client);

  final SupabaseClient _client;

  static const _createIntent = 'create-payment-intent';
  static const _finalize = 'finalize-reservation-payment';
  static const _createSetupIntent = 'create-setup-intent';
  static const _completePaymentMethodSetup = 'complete-payment-method-setup';

  static const Duration _sessionRefreshTimeout = Duration(seconds: 25);
  static const Duration _edgeInvokeTimeout = Duration(seconds: 45);

  // refresh session so Edge gets a valid JWT
  Future<void> _ensureSessionReadyForEdge() async {
    final auth = _client.auth;
    if (auth.currentSession == null) {
      throw const StripeCheckoutRemoteException(
        'You must be signed in to save a card or pay.',
      );
    }
    try {
      await auth
          .refreshSession()
          .timeout(
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
          .invoke(
            functionName,
            body: body ?? const <String, dynamic>{},
          )
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

  // paymentMethodId is saved card row id (stored method)
  Future<String> createPaymentIntentClientSecret(
    String reservationId, {
    String? paymentMethodId,
  }) async {
    final body = <String, dynamic>{'reservation_id': reservationId};
    if (paymentMethodId != null && paymentMethodId.trim().isNotEmpty) {
      body['payment_method_id'] = paymentMethodId.trim();
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
    final map = Map<String, dynamic>.from(data);
    final secret = map['client_secret'] as String?;
    if (secret == null || secret.isEmpty) {
      throw const StripeCheckoutRemoteException('Missing payment client secret');
    }
    return secret;
  }

  Future<String> createSetupIntentClientSecret() async {
    final res = await _invoke(_createSetupIntent, body: const <String, dynamic>{});
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

  // returns new payment_methods id (when present)
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

  static String _messageFromResponse(Object? data, String fallback) {
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    return fallback;
  }
}

class StripeCheckoutRemoteException implements Exception {
  const StripeCheckoutRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}
