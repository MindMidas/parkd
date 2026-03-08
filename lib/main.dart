import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

// TODO: Replace placeholder app startup.
Future<void> main() async {
  // TODO: Add startup initialization (Supabase/env/logging) here.
  runApp(const ProviderScope(child: ParkdApp()));
}
