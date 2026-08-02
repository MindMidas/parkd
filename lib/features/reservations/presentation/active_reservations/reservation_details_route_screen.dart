import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/reservations_providers.dart';
import 'reservation_details_screen.dart';

// Opens reservation details when only the reservation id is known (payment success)
class ReservationDetailsRouteScreen extends ConsumerWidget {
  const ReservationDetailsRouteScreen({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync = ref.watch(reservationByIdProvider(reservationId));

    void retry() => ref.invalidate(reservationByIdProvider(reservationId));

    return reservationAsync.when(
      loading: () => const _RouteLoadingScreen(),
      error: (_, _) => _RouteFailureScreen(onRetry: retry),
      data: (reservation) {
        if (reservation == null) {
          return _RouteFailureScreen(onRetry: retry);
        }
        final listingAsync = ref.watch(
          listingByIdProvider(reservation.listingId),
        );
        return listingAsync.when(
          loading: () => const _RouteLoadingScreen(),
          error: (_, _) =>
              ReservationDetailsScreen(reservation: reservation, listing: null),
          data: (listing) => ReservationDetailsScreen(
            reservation: reservation,
            listing: listing,
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
      appBar: AppTopBar(title: 'Reservation details', showBack: true),
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
      appBar: const AppTopBar(title: 'Reservation details', showBack: true),
      body: AppPageStatus.error(
        title: 'Reservation unavailable',
        message: 'This reservation could not be opened.',
        actionLabel: onRetry != null ? 'Try again' : null,
        onAction: onRetry,
      ),
    );
  }
}
