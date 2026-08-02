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

// Runtime configuration loader.
abstract final class AppEnvironment {
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
