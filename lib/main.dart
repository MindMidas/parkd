import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/main_shell_tab_provider.dart';
import 'core/config/app_environment.dart';
import 'core/map/mapbox_runtime.dart';
import 'core/security/supabase_auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  initializeNativeMapbox(
    tokenProvider: () => AppEnvironment.requiredValue(
      AppEnvironmentKey.mapboxAccessToken,
      help:
          'Create a public default token in Mapbox Account → Tokens and pass it '
          'with --dart-define=MAPBOX_ACCESS_TOKEN=... or '
          '--dart-define-from-file=dart_defines.local.json.',
    ),
  );

  final supabaseUrl = AppEnvironment.requiredValue(
    AppEnvironmentKey.supabaseUrl,
    help: 'Pass it with --dart-define or --dart-define-from-file.',
  );
  final supabaseAnonKey = AppEnvironment.requiredValue(
    AppEnvironmentKey.supabaseAnonKey,
    help: 'Pass it with --dart-define or --dart-define-from-file.',
  );

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: createSupabaseSessionStorage(),
      pkceAsyncStorage: createSupabasePkceStorage(),
    ),
  );

  final stripePk = AppEnvironment.optional(
    AppEnvironmentKey.stripePublishableKey,
  );
  if (stripePk != null && stripePk.isNotEmpty) {
    Stripe.publishableKey = stripePk;
    // Must match CFBundleURLSchemes in ios/Runner/Info.plist (Stripe 3DS / PaymentSheet return)
    Stripe.urlScheme = 'parkd';
    await Stripe.instance.applySettings();
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const ParkdApp(),
    ),
  );
}
