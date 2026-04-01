import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/host_listing_booking_thread.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/profile_avatar_image_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/providers/notifications_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../../reservations/presentation/trip_conversation_screen.dart';
import '../../reservations/providers/reservations_providers.dart';
import 'active_bookings/booking_details_screen.dart';

enum HostListingThreadsScope { active, past }

bool hostListingBookingThreadMatchesQuery(
  HostListingBookingThread t,
  String q,
  WidgetRef ref,
) {
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

class HostListingBookingThreadsScaffold extends ConsumerStatefulWidget {
  const HostListingBookingThreadsScaffold({
    super.key,
    required this.listing,
    required this.scope,
    required this.emptyWhenNoThreads,
  });

  final Listing listing;
  final HostListingThreadsScope scope;
  final String emptyWhenNoThreads;

  @override
  ConsumerState<HostListingBookingThreadsScaffold> createState() =>
      _HostListingBookingThreadsScaffoldState();
}

class _HostListingBookingThreadsScaffoldState
    extends ConsumerState<HostListingBookingThreadsScaffold> {
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

  @override
  Widget build(BuildContext context) {
    final threadsAsync = switch (widget.scope) {
      HostListingThreadsScope.active =>
        ref.watch(hostListingActiveThreadsProvider(widget.listing.id)),
      HostListingThreadsScope.past =>
        ref.watch(hostListingPastThreadsProvider(widget.listing.id)),
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: widget.listing.addressLine,
        showBack: true,
      ),
      body: AppHubSearchListColumn(
        searchController: _searchController,
        searchHint: 'Search conversations',
        onSearchChanged: (value) => setState(() => _query = value),
        expandedChild: threadsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const AppMutedBodyCenter(
            'Could not load conversations.',
          ),
          data: (threads) {
            final filtered = threads
                .where((t) =>
                    hostListingBookingThreadMatchesQuery(t, _query, ref))
                .toList();
            if (filtered.isEmpty) {
              return AppMutedBodyCenter(
                threads.isEmpty
                    ? widget.emptyWhenNoThreads
                    : 'No results match your search.',
              );
            }
            return AppDividerSeparatedListView(
              itemCount: filtered.length,
              rowBuilder: (context, index) {
                final thread = filtered[index];
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
                final unread = ref.watch(
                  unreadMessageNotificationsForReservationProvider(
                    thread.reservation.id,
                  ),
                );
                return AppMenuRow(
                  leadingType: AppMenuLeadingType.profile,
                  leadingImageProvider: avatar,
                  title: name,
                  subtitle: preview,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread > 0) ...[
                        AppNotificationBadge(count: unread, compact: true),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        Icons.mail_rounded,
                        size: 22,
                        color: AppColors.iconGrey,
                      ),
                    ],
                  ),
                  onTap: () {
                    final uid = ref.read(currentSessionProvider)?.user.id;
                    if (uid == null) return;
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TripConversationScreen(
                          reservationId: thread.reservation.id,
                          initialConversationId: thread.conversation?.id,
                          peerDisplayName: name,
                          viewTripLabel: 'View booking',
                          onViewTrip: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
