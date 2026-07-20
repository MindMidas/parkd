import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_signup_screen.dart';
import '../features/auth/presentation/password_recovery_screen.dart';
import '../features/auth/presentation/update_password_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/hosting/providers/hosting_providers.dart';
import '../features/map/presentation/home_map_screen.dart';
import '../features/map/presentation/main_tab.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/providers/reservations_providers.dart';
import '../features/reservations/presentation/notification_conversation_route_screen.dart';
import '../features/legal/presentation/legal_document_screen.dart';
import '../core/stripe/stripe_checkout_provider.dart';

final _backendRepositoryLinkProvider = Provider<void>((ref) {
  ref.watch(listingsRepositoryProvider);
  ref.watch(profileRepositoryProvider);
  ref.watch(paymentMethodsRepositoryProvider);
  ref.watch(reservationsRepositoryProvider);
  ref.watch(messagingRepositoryProvider);
  ref.watch(hostEarningsRepositoryProvider);
  ref.watch(stripeCheckoutRemoteProvider);
});

/// Notifies [GoRouter] when auth/MFA state changes without recreating the router
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(currentSessionProvider, (previous, next) => notifyListeners());
    ref.listen(
      needsMfaChallengeProvider,
      (previous, next) => notifyListeners(),
    );
    ref.listen(
      passwordRecoverySessionProvider,
      (previous, next) => notifyListeners(),
    );
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
        path: '/auth/reset-password',
        builder: (context, state) => const UpdatePasswordScreen(),
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
        path: '/reservations/:reservationId/messages',
        builder: (context, state) => NotificationConversationRouteScreen(
          reservationId: state.pathParameters['reservationId'] ?? '',
        ),
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
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.terms),
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final needsMfaChallenge = ref.read(needsMfaChallengeProvider);
      final isPasswordRecovery = ref.read(passwordRecoverySessionProvider);
      final loc = state.matchedLocation;
      final isOnAuthRoute = loc == '/auth' || loc.startsWith('/auth/');
      final isOnLegalRoute = loc.startsWith('/legal/');
      final isAuthenticated = session != null;
      // Login + TOTP screen only (`/auth`, not forgot-password)
      final isOnLoginScreen = loc == '/auth';

      if (isPasswordRecovery && loc != '/auth/reset-password') {
        return '/auth/reset-password';
      }

      if (!isAuthenticated && !isOnAuthRoute && !isOnLegalRoute) {
        return '/auth';
      }

      // Password sign-in creates an AAL1 session until TOTP is verified. Force the MFA
      // UI on cold start (initial route is /home) and block other app routes
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
