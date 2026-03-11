import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/home/presentation/home_map_screen.dart';

class ParkdApp extends ConsumerWidget {
  const ParkdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) => session == null ? '/auth' : '/home',
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeMapScreen(),
        ),
      ],
      redirect: (context, state) {
        final isOnAuthRoute = state.matchedLocation == '/auth';
        final isAuthenticated = session != null;

        if (!isAuthenticated && !isOnAuthRoute) {
          return '/auth';
        }

        if (isAuthenticated && isOnAuthRoute) {
          return '/home';
        }

        return null;
      },
    );

    return MaterialApp.router(
      title: 'Parkd',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
