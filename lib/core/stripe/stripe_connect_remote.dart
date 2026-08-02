import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// Host Stripe Connect Express onboarding + payout readiness.
class StripeConnectRemote {
  StripeConnectRemote(this._client);

  final SupabaseClient _client;

  static const _fn = 'connect-account';
  static const Duration _sessionRefreshTimeout = Duration(seconds: 25);
  static const Duration _edgeInvokeTimeout = Duration(seconds: 45);

  Future<void> _ensureSessionReady() async {
    final auth = _client.auth;
    if (auth.currentSession == null) {
      throw const StripeConnectRemoteException('Sign in to set up payouts.');
    }
    try {
      await auth.refreshSession().timeout(
        _sessionRefreshTimeout,
        onTimeout: () => throw TimeoutException('refreshSession'),
      );
    } catch (_) {
      final s = auth.currentSession;
      if (s == null || s.isExpired) {
        throw const StripeConnectRemoteException(
          'Your session expired. Sign out, sign in again, then retry.',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    await _ensureSessionReady();
    try {
      final res = await _client.functions
          .invoke(_fn, body: body)
          .timeout(
            _edgeInvokeTimeout,
            onTimeout: () {
              throw const StripeConnectRemoteException(
                'Payout service did not respond. Check your connection.',
              );
            },
          );
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const StripeConnectRemoteException(
        'Payout service returned an unexpected response.',
      );
    } on FunctionException catch (e) {
      throw StripeConnectRemoteException(_errorMessage(e));
    }
  }

  static String _errorMessage(FunctionException e) {
    final d = e.details;
    if (d is Map) {
      final err = d['error'];
      if (err is String && err.isNotEmpty) return err;
      final msg = d['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Payout service error (${e.status}). Try again.';
  }

  Future<StripeConnectStatus> fetchStatus() async {
    final data = await _invoke({'action': 'status'});
    return StripeConnectStatus.fromJson(data);
  }

  // Creates/resumes Express onboarding. url is set when Stripe needs more info.
  Future<StripeConnectStatus> startOnboarding() async {
    final data = await _invoke({'action': 'onboard'});
    return StripeConnectStatus.fromJson(data);
  }

  Future<StripeConnectStatus> openDashboard() async {
    final data = await _invoke({'action': 'dashboard'});
    return StripeConnectStatus.fromJson(data);
  }
}

class StripeConnectStatus {
  const StripeConnectStatus({
    required this.connected,
    required this.chargesEnabled,
    required this.detailsSubmitted,
    required this.payoutsReady,
    this.url,
  });

  final bool connected;
  final bool chargesEnabled;
  final bool detailsSubmitted;
  final bool payoutsReady;
  final String? url;

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    return StripeConnectStatus(
      connected: json['connected'] == true,
      chargesEnabled: json['charges_enabled'] == true,
      detailsSubmitted: json['details_submitted'] == true,
      payoutsReady: json['payouts_ready'] == true,
      url: url is String && url.trim().isNotEmpty ? url.trim() : null,
    );
  }
}

class StripeConnectRemoteException implements Exception {
  const StripeConnectRemoteException(this.message);
  final String message;

  @override
  String toString() => message;
}
