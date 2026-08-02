import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/host_listing_booking_thread.dart';
import '../../../../core/models/listing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/notifications_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reservations/presentation/trip_conversation_screen.dart';
import '../../../reservations/presentation/widgets/mark_messages_unread_sheet.dart';
import '../../../reservations/providers/reservations_providers.dart';
import '../active_bookings/booking_details_screen.dart';

// Host: past-trip threads for listing
class PastBookingMessagesScreen extends ConsumerStatefulWidget {
  const PastBookingMessagesScreen({super.key, required this.listing});

  final Listing listing;

  @override
  ConsumerState<PastBookingMessagesScreen> createState() =>
      _PastBookingMessagesScreenState();
}

class _PastBookingMessagesScreenState
    extends ConsumerState<PastBookingMessagesScreen> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _threadMatches(HostListingBookingThread t, String q) {
    if (q.isEmpty) return true;
    final low = q.toLowerCase();
    if (t.lastMessagePreview?.toLowerCase().contains(low) == true) {
      return true;
    }
    if (t.reservation.id.toLowerCase().contains(low)) return true;
    final p = ref
        .watch(profileByUserIdProvider(t.reservation.driverId))
        .maybeWhen(data: (v) => v, orElse: () => null);
    final name = p?.displayName.toLowerCase() ?? '';
    final user = p?.username?.toLowerCase() ?? '';
    return name.contains(low) || user.contains(low);
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(
      hostListingPastThreadsProvider(widget.listing.id),
    );
    final unreadByReservation = ref.watch(
      unreadBookingEventCountByReservationProvider,
    );
    final mutedReservationIds = ref.watch(mutedReservationMessagesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: widget.listing.addressLine, showBack: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppListScreenSearchPanel(
              controller: _searchController,
              hintText: 'Search conversations',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: AppAsyncBody(
              value: threadsAsync,
              isEmpty: (threads) => threads.isEmpty,
              emptyTitle: 'No conversations yet',
              emptyMessage: 'No past bookings for this spot.',
              errorTitle: 'Could not load conversations',
              onRetry: () => ref.invalidate(
                hostListingPastThreadsProvider(widget.listing.id),
              ),
              data: (threads) {
                final filtered = threads
                    .where((t) => _threadMatches(t, _query))
                    .toList();
                if (filtered.isEmpty) {
                  return const AppPageStatus.empty(
                    title: 'No matches',
                    message: 'No results match your search.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: filtered.length + 2,
                  separatorBuilder: (context, index) => const AppDividerWide(),
                  itemBuilder: (context, index) {
                    if (index == 0 || index == filtered.length + 1) {
                      return const SizedBox.shrink();
                    }
                    final thread = filtered[index - 1];
                    final driverProfile = ref.watch(
                      profileByUserIdProvider(thread.reservation.driverId),
                    );
                    final name = driverProfile.maybeWhen(
                      data: (p) => p?.displayName ?? 'Driver',
                      orElse: () => 'Driver',
                    );
                    final preview =
                        thread.lastMessagePreview ?? 'No messages yet';
                    final avatar = profileAvatarImageProvider(
                      driverProfile.asData?.value,
                    );
                    final isMuted = mutedReservationIds.contains(
                      thread.reservation.id,
                    );
                    return AppMenuRow(
                      leadingType: AppMenuLeadingType.profile,
                      leadingImageProvider: avatar,
                      title: name,
                      subtitle: preview,
                      rightKind: AppMenuRightKind.icon,
                      rightIcon: Icons.mail_rounded,
                      isMuted: isMuted,
                      badgeCount:
                          unreadByReservation[thread.reservation.id] ?? 0,
                      onTap: () {
                        final uid = ref.read(currentSessionProvider)?.user.id;
                        if (uid == null) return;
                        Navigator.of(context).push<void>(
                          AppPageRoute<void>(
                            builder: (_) => TripConversationScreen(
                              reservationId: thread.reservation.id,
                              peerUserId: thread.reservation.driverId,
                              initialConversationId: thread.conversation?.id,
                              peerDisplayName: name,
                              viewTripLabel: 'View booking',
                              onViewTrip: () {
                                Navigator.of(context).push<void>(
                                  AppPageRoute<void>(
                                    builder: (_) => BookingDetailsScreen(
                                      reservation: thread.reservation,
                                      listing: widget.listing,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      onLongPress: () => showChatNotificationOptionsSheet(
                        context: context,
                        ref: ref,
                        reservationId: thread.reservation.id,
                        isMuted: isMuted,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
