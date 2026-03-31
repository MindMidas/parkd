import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'go_router_provider.dart';
import 'realtime_alerts_overlay.dart';

class ParkdApp extends ConsumerWidget {
  const ParkdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Parkd',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        return RealtimeAlertsOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
