enum AppEnvironmentKey {
  supabaseUrl('SUPABASE_URL'),
  supabaseAnonKey('SUPABASE_ANON_KEY'),
  mapboxAccessToken('MAPBOX_ACCESS_TOKEN'),
  stripePublishableKey('STRIPE_PUBLISHABLE_KEY'),
  turnstileSiteKey('TURNSTILE_SITE_KEY'),
  passwordResetRedirectUrl('PASSWORD_RESET_REDIRECT_URL');

  const AppEnvironmentKey(this.name);

  final String name;
}

/// Runtime configuration loader.
///
/// All builds provide public runtime configuration through `--dart-define` or
/// `--dart-define-from-file`. Secret values must never be compiled into Flutter.
abstract final class AppEnvironment {
  /// Portfolio builds are deliberately non-commercial and test-data-only.
  /// Set `--dart-define=PARKD_DEMO=false` only after a separate production
  /// security and legal review.
  static const bool isPortfolioDemo = bool.fromEnvironment(
    'PARKD_DEMO',
    defaultValue: true,
  );

  static const int demoDataRetentionHours = 24;

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const _stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );
  static const _turnstileSiteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');
  static const _passwordResetRedirectUrl = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_URL',
  );

  static String? optional(AppEnvironmentKey key) {
    final defineValue = _fromDartDefine(key).trim();
    return defineValue.isEmpty ? null : defineValue;
  }

  static String requiredValue(AppEnvironmentKey key, {required String help}) {
    final value = optional(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing ${key.name}. $help');
    }
    return value;
  }

  /// Prevents a portfolio build from accidentally accepting live payments.
  static void validateDemoPaymentKey(String? publishableKey) {
    if (!isPortfolioDemo || publishableKey == null || publishableKey.isEmpty) {
      return;
    }
    if (!publishableKey.startsWith('pk_test_')) {
      throw StateError(
        'PARKD_DEMO builds only accept Stripe pk_test_ publishable keys.',
      );
    }
  }

  static String _fromDartDefine(AppEnvironmentKey key) {
    switch (key) {
      case AppEnvironmentKey.supabaseUrl:
        return _supabaseUrl;
      case AppEnvironmentKey.supabaseAnonKey:
        return _supabaseAnonKey;
      case AppEnvironmentKey.mapboxAccessToken:
        return _mapboxAccessToken;
      case AppEnvironmentKey.stripePublishableKey:
        return _stripePublishableKey;
      case AppEnvironmentKey.turnstileSiteKey:
        return _turnstileSiteKey;
      case AppEnvironmentKey.passwordResetRedirectUrl:
        return _passwordResetRedirectUrl;
    }
  }
}
