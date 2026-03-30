import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/main_shell_tab_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim();
  if (mapboxToken == null || mapboxToken.isEmpty) {
    throw StateError(
      'Missing MAPBOX_ACCESS_TOKEN in .env. Create a public default token in '
      'Mapbox Account → Tokens and add it to your .env file.',
    );
  }
  MapboxOptions.setAccessToken(mapboxToken);

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    throw StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env file.');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final stripePk = dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim();
  if (stripePk != null && stripePk.isNotEmpty) {
    Stripe.publishableKey = stripePk;
    // Must match CFBundleURLSchemes in ios/Runner/Info.plist (Stripe 3DS / PaymentSheet return)
    Stripe.urlScheme = 'parkd';
    await Stripe.instance.applySettings();
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const ParkdApp(),
    ),
  );
}
