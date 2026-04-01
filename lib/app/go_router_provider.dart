import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_signup_screen.dart';
import '../features/auth/presentation/password_recovery_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/hosting/providers/hosting_providers.dart';
import '../features/map/presentation/home_map_screen.dart';
import 'main_tab.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/providers/reservations_providers.dart';
import '../core/stripe/stripe_checkout_provider.dart';
import '../features/reservations/presentation/trip_conversation_screen.dart';

final _backendRepositoryLinkProvider = Provider<void>((ref) {
  ref.watch(listingsRepositoryProvider);
  ref.watch(profileRepositoryProvider);
  ref.watch(paymentMethodsRepositoryProvider);
  ref.watch(reservationsRepositoryProvider);
  ref.watch(messagingRepositoryProvider);
  ref.watch(hostEarningsRepositoryProvider);
  ref.watch(stripeCheckoutRemoteProvider);
});

// Poke GoRouter on auth or MFA changes so redirects run without rebuilding the router.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(currentSessionProvider, (previous, next) => notifyListeners());
    ref.listen(needsMfaChallengeProvider, (previous, next) => notifyListeners());
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(_backendRepositoryLinkProvider);
  final refresh = GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final session = ref.read(currentSessionProvider);
          if (session == null) {
            return '/auth';
          }
          return '/home';
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const LoginSignupScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password/email',
        redirect: (context, state) => '/auth/forgot-password',
      ),
      GoRoute(
        path: '/auth/forgot-password/sms',
        redirect: (context, state) => '/auth/forgot-password',
      ),
      GoRoute(
        path: '/trip-conversation',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return TripConversationScreen(
            reservationId: data['reservationId'],
            initialConversationId: data['conversationId'],
            peerDisplayName: data['peerDisplayName'],
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          final tabParam = params['tab'];
          final index = MainTab.fromQuery(tabParam);
          final hasTabInRoute = params.containsKey('tab');
          return HomeMapScreen(
            initialIndex: index,
            hasTabInRoute: hasTabInRoute,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final needsMfaChallenge = ref.read(needsMfaChallengeProvider);
      final loc = state.matchedLocation;
      final isOnAuthRoute = loc == '/auth' || loc.startsWith('/auth/');
      final isAuthenticated = session != null;
      // True on the main login screen only, not forgot-password routes.
      final isOnLoginScreen = loc == '/auth';

      if (!isAuthenticated && !isOnAuthRoute) {
        return '/auth';
      }

      // Logged in but MFA not done yet: keep them on login until TOTP passes.
      if (isAuthenticated && needsMfaChallenge && !isOnLoginScreen) {
        return '/auth';
      }

      if (isAuthenticated && !needsMfaChallenge && loc == '/auth') {
        return '/home';
      }

      return null;
    },
  );
});
