import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/reservations_providers.dart';
import 'trip_conversation_screen.dart';

String reservationMessagesLocation(String reservationId) {
  return '/reservations/${Uri.encodeComponent(reservationId)}/messages';
}

class NotificationConversationRouteScreen extends ConsumerWidget {
  const NotificationConversationRouteScreen({
    super.key,
    required this.reservationId,
  });

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservation = ref.watch(reservationByIdProvider(reservationId));
    return reservation.when(
      loading: () => const _RouteLoadingScreen(),
      error: (_, _) => _RouteFailureScreen(
        onRetry: () => ref.invalidate(reservationByIdProvider(reservationId)),
      ),
      data: (row) {
        final userId = ref.watch(currentSessionProvider)?.user.id;
        if (row == null || userId == null) {
          return _RouteFailureScreen(
            onRetry: () =>
                ref.invalidate(reservationByIdProvider(reservationId)),
          );
        }
        final String peerUserId;
        if (userId == row.hostId) {
          peerUserId = row.driverId;
        } else if (userId == row.driverId) {
          peerUserId = row.hostId;
        } else {
          return const _RouteFailureScreen();
        }
        final profile = ref.watch(profileByUserIdProvider(peerUserId));
        return profile.when(
          loading: () => const _RouteLoadingScreen(),
          error: (_, _) => TripConversationScreen(
            reservationId: row.id,
            peerDisplayName: 'Messages',
            peerUserId: peerUserId,
          ),
          data: (peer) => TripConversationScreen(
            reservationId: row.id,
            peerDisplayName: peer?.displayName ?? 'Messages',
            peerUserId: peerUserId,
          ),
        );
      },
    );
  }
}

class _RouteLoadingScreen extends StatelessWidget {
  const _RouteLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: 'Messages', showBack: true),
      body: AppPageStatus.loading(),
    );
  }
}

class _RouteFailureScreen extends StatelessWidget {
  const _RouteFailureScreen({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Messages', showBack: true),
      body: AppPageStatus.error(
        title: 'Conversation unavailable',
        message: 'This conversation could not be opened.',
        actionLabel: onRetry != null ? 'Try again' : null,
        onAction: onRetry,
      ),
    );
  }
}
