import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/booking_time_window.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/slot_pricing_summary.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/profile_avatar_image_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../moderation/presentation/moderation_actions.dart';
import '../../profile/data/listings_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/map_providers.dart';
import 'reservation_screen.dart';

ListingsRepository _listingsRepo(WidgetRef ref) =>
    ref.read(listingsRepositoryProvider);

ProfileRepository _profileRepo(WidgetRef ref) =>
    ref.read(profileRepositoryProvider);

String _formatWeeklyRange(String start, String end) {
  String fmt(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    var h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts[1].substring(0, 2).trim()) ?? 0;
    final isPm = h >= 12;
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}';
  }

  return '${fmt(start)} – ${fmt(end)}';
}

Set<int> _weekdaysFromWeekly(List<AvailabilityWeekly> weekly) {
  return weekly
      .map((w) => w.dayOfWeek == 0 ? DateTime.sunday : w.dayOfWeek)
      .toSet();
}

String _hostHandleFromName(String displayName) {
  final t = displayName.trim();
  if (t.isEmpty) return '@host';
  return '@${t.toLowerCase().replaceAll(' ', '')}';
}

String _hostHandle(Profile? profile, String displayName) {
  final u = profile?.username?.trim();
  if (u != null && u.isNotEmpty) return '@$u';
  return _hostHandleFromName(displayName);
}

({
  List<AvailabilityWeekly> weekly,
  List<AvailabilitySpecific> specific,
  List<BookingTimeWindow> bookings,
})
_heatmapSchedule(
  List<AvailabilityWeekly> apiWeekly,
  List<AvailabilitySpecific> apiSpecific,
  List<BookingTimeWindow> apiBookings,
) {
  return (weekly: apiWeekly, specific: apiSpecific, bookings: apiBookings);
}

bool _noPublishedAvailability(
  ({
    Profile? profile,
    List<ListingPhoto> photos,
    List<AvailabilityWeekly> weekly,
    List<AvailabilitySpecific> specific,
    List<BookingTimeWindow> bookings,
  })
  data,
) {
  return data.weekly.isEmpty && data.specific.isEmpty;
}

/// Pops with result `'full'` when the user drags the sheet handle up so the map can
/// push [ListingDetailFromMapScreen] as a separate route
const String kListingDetailSheetResultFull = 'full';

/// Fixed ~70% height; only the top handle expands to full detail — body scrolls independently
// Map listing detail sheet — drag handle + embedded detail body over the map
class ListingDetailFromMapSheet extends StatefulWidget {
  const ListingDetailFromMapSheet({super.key, required this.listing});

  final Listing listing;

  @override
  State<ListingDetailFromMapSheet> createState() =>
      _ListingDetailFromMapSheetState();
}

class _ListingDetailFromMapSheetState extends State<ListingDetailFromMapSheet> {
  int? _handlePointer;
  double _handleDragAccum = 0;

  void _onHandlePointerUp() {
    final d = _handleDragAccum;
    _handlePointer = null;
    _handleDragAccum = 0;

    // Ignore tiny jitter; pointer events avoid competing with scroll gesture arena
    if (d < -36) {
      Navigator.of(context).pop(kListingDetailSheetResultFull);
      return;
    }
    if (d > 36) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final sheetH = h * 0.70;

    return SizedBox(
      height: h,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Map / dimmed area: must sit in this overlay so Flutter wins over the map
          // platform view for hit-testing (barrier alone is unreliable)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: sheetH,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Material(
                  color: AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          _handlePointer = e.pointer;
                          _handleDragAccum = 0;
                        },
                        onPointerMove: (e) {
                          if (_handlePointer == e.pointer) {
                            _handleDragAccum += e.delta.dy;
                          }
                        },
                        onPointerUp: (e) {
                          if (_handlePointer != e.pointer) return;
                          _onHandlePointerUp();
                        },
                        onPointerCancel: (e) {
                          if (_handlePointer == e.pointer) {
                            _handlePointer = null;
                            _handleDragAccum = 0;
                          }
                        },
                        child: const SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: AppBottomSheetGrabber(),
                        ),
                      ),
                      Expanded(
                        child: ListingDetailFromMapScreen(
                          listing: widget.listing,
                          mapPreviewSheet: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Full-screen version when you drag the handle up — same scroll body + footer as the sheet
class ListingDetailFromMapScreen extends ConsumerStatefulWidget {
  const ListingDetailFromMapScreen({
    super.key,
    required this.listing,
    this.mapPreviewSheet = false,
  });

  final Listing listing;

  final bool mapPreviewSheet;

  @override
  ConsumerState<ListingDetailFromMapScreen> createState() =>
      _ListingDetailFromMapScreenState();
}

class _ListingDetailFromMapScreenState
    extends ConsumerState<ListingDetailFromMapScreen> {
  ({
    Profile? profile,
    List<ListingPhoto> photos,
    List<AvailabilityWeekly> weekly,
    List<AvailabilitySpecific> specific,
    List<BookingTimeWindow> bookings,
  })?
  _data;
  bool _loading = true;
  bool _loadFailed = false;

  Future<void> _onSafetyAction(String action) async {
    final listing = widget.listing;
    if (action == 'report') {
      await showParkdReportDialog(
        context: context,
        ref: ref,
        targetType: 'listing',
        targetId: listing.id,
        targetLabel: 'listing',
      );
      return;
    }
    if (action == 'block') {
      final hostName = _data?.profile?.displayName ?? 'this host';
      final blocked = await confirmAndBlockParkdUser(
        context: context,
        ref: ref,
        userId: listing.hostId,
        displayName: hostName,
      );
      if (!blocked || !mounted) return;
      ref.invalidate(mapPublishedListingsProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final listings = _listingsRepo(ref);
    final profiles = _profileRepo(ref);
    final id = widget.listing.id;
    final rangeStart = DateTime.now().subtract(const Duration(hours: 1));
    final rangeEnd = DateTime.now().add(const Duration(days: 14));
    try {
      final results = await Future.wait([
        listings.getListingPhotos(id),
        widget.listing.isApproximateLocation
            ? Future<List<AvailabilityWeekly>>.value(
                widget.listing.publicWeeklyAvailability,
              )
            : listings.getAvailabilityWeekly(id),
        widget.listing.isApproximateLocation
            ? Future<List<AvailabilitySpecific>>.value(
                widget.listing.publicSpecificAvailability,
              )
            : listings.getAvailabilitySpecific(id),
        listings.getBookingBlocksOverlapping(
          id,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
        profiles.getProfile(widget.listing.hostId),
      ]);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = false;
        _data = (
          profile: results[4] as Profile?,
          photos: results[0] as List<ListingPhoto>,
          weekly: results[1] as List<AvailabilityWeekly>,
          specific: results[2] as List<AvailabilitySpecific>,
          bookings: results[3] as List<BookingTimeWindow>,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Widget _buildListingDetailBody(
    BuildContext context,
    Listing listing,
    ({
      Profile? profile,
      List<ListingPhoto> photos,
      List<AvailabilityWeekly> weekly,
      List<AvailabilitySpecific> specific,
      List<BookingTimeWindow> bookings,
    })?
    data,
  ) {
    final profile = data?.profile;
    final rawName = profile?.fullName?.trim();
    final displayName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : 'Host';
    final heatmapSchedule = _heatmapSchedule(
      data?.weekly ?? const [],
      data?.specific ?? const [],
      data?.bookings ?? const [],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPersonInlineCard(
          title: 'Host',
          compact: true,
          displayName: displayName,
          handle: _hostHandle(profile, displayName),
          avatarImageProvider: profileAvatarImageProvider(profile),
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: appListingPhotoFrameAspectRatio,
            child: _heroPhoto(
              listing: listing,
              photos: data?.photos,
              loading: false,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppStreetAddressCard(
          title: listing.isApproximateLocation
              ? 'Approximate parking area'
              : 'Parking location',
          streetLine: listing.addressLine,
          localityLine: listing.localityLine.isNotEmpty
              ? listing.localityLine
              : null,
          spotLine: listing.spotLabel,
          usePrimaryColorForSecondaryLines: true,
        ),
        if (listing.isApproximateLocation) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'For host privacy, the exact address and map pin unlock only after '
            'a test reservation is confirmed.',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppDisplayTitledOutlineCard(
          title: 'Availability heatmap',
          child: AppListingAvailabilityHeatmap(
            loading: false,
            listing: listing,
            weekly: heatmapSchedule.weekly,
            specific: heatmapSchedule.specific,
            bookings: heatmapSchedule.bookings,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppDisplayTitledOutlineCard(
          title: 'Hours & pricing',
          child: _AvailabilitySection(
            weekly: data?.weekly ?? const [],
            specific: data?.specific ?? const [],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildLoadingOrErrorBody() {
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Could not load this listing. Check your connection and try again.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMuted,
          ),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _reserveButton(
    Listing listing,
    ({
      Profile? profile,
      List<ListingPhoto> photos,
      List<AvailabilityWeekly> weekly,
      List<AvailabilitySpecific> specific,
      List<BookingTimeWindow> bookings,
    })?
    data, {
    required bool isOwnListing,
  }) {
    return AppPrimaryButton(
      label: 'Make a reservation',
      icon: Icons.chevron_right_rounded,
      onPressed: isOwnListing || data == null || _noPublishedAvailability(data)
          ? null
          : () {
              final w = data.weekly;
              final weekdays = _weekdaysFromWeekly(w);
              final minH = SlotPricingSummary.minHourly(w, data.specific);
              final minD = SlotPricingSummary.minDailyWhereSet(
                w,
                data.specific,
              );
              final hr = minH ?? 0;
              final heat = _heatmapSchedule(
                data.weekly,
                data.specific,
                data.bookings,
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReservationScreen(
                    listing: listing,
                    weekly: heat.weekly,
                    specific: heat.specific,
                    bookings: heat.bookings,
                    heatmapLoading: false,
                    hourlyRate: hr,
                    dailyRate: minD ?? hr * 8,
                    streetAddress: listing.addressLine,
                    localityLine: listing.localityLine,
                    spotLabel: listing.spotLabel,
                    latitude: listing.latitude,
                    longitude: listing.longitude,
                    availableWeekdays: weekdays,
                  ),
                ),
              );
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final data = _data;

    // Match [ReservationScreen] footer: only horizontal + lg bottom — do not add
    // view bottom safe inset here; on the map sheet that inset is global and
    // stacks as empty space above the sheet’s rounded bottom
    const reserveBarPadding = EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    );

    final ready = !_loading && data != null && !_loadFailed;
    final sessionUserId = ref.watch(currentSessionProvider)?.user.id;
    final isOwnListing =
        sessionUserId != null && sessionUserId == listing.hostId;

    if (widget.mapPreviewSheet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ready
                ? AppDetailScrollBody(
                    bottomScrollPadding: AppSpacing.md,
                    child: _buildListingDetailBody(context, listing, data),
                  )
                : _buildLoadingOrErrorBody(),
          ),
          Padding(
            padding: reserveBarPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _reserveButton(
                  listing,
                  ready ? data : null,
                  isOwnListing: isOwnListing,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: listing.addressLine,
        showBack: true,
        actions: isOwnListing
            ? null
            : [
                PopupMenuButton<String>(
                  tooltip: 'Safety options',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: _onSafetyAction,
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'report',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Report listing'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.block_rounded),
                        title: Text('Block host'),
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ready
                ? AppDetailScrollBody(
                    child: _buildListingDetailBody(context, listing, data),
                  )
                : _buildLoadingOrErrorBody(),
          ),
          Padding(
            padding: reserveBarPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _reserveButton(
                  listing,
                  ready ? data : null,
                  isOwnListing: isOwnListing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _neutralHeroSurface({Widget? center}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.secondaryBlue.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: center,
    );
  }

  /// Uses Supabase [photos] when loaded; until then [Listing.heroPhotoUrl] from the map query embed
  Widget _heroPhoto({
    required Listing listing,
    required List<ListingPhoto>? photos,
    required bool loading,
  }) {
    ListingPhoto? heroRow;
    if (photos != null && photos.isNotEmpty) {
      final sorted = [...photos]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      heroRow = sorted.first;
    }
    final fromRow = heroRow?.photoUrl.trim() ?? '';
    final fromMapPin = listing.heroPhotoUrl?.trim() ?? '';
    final url = fromRow.isNotEmpty ? fromRow : fromMapPin;
    final markerFraction = heroRow?.markerX != null && heroRow?.markerY != null
        ? Offset(heroRow!.markerX!, heroRow.markerY!)
        : null;

    if (url.isEmpty) {
      if (loading) {
        return _neutralHeroSurface(
          center: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return _neutralHeroSurface(
        center: Icon(
          Icons.local_parking_rounded,
          size: 56,
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
        ),
      );
    }

    final image = Image.network(
      url,
      key: ValueKey<String>(url),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _neutralHeroSurface(
          center: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, _, _) => _neutralHeroSurface(
        center: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.iconGrey,
          size: 40,
        ),
      ),
    );

    return AppListingPhotoSpotOverlay(
      markerFraction: markerFraction,
      child: image,
    );
  }
}

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({required this.weekly, required this.specific});

  final List<AvailabilityWeekly> weekly;
  final List<AvailabilitySpecific> specific;

  @override
  Widget build(BuildContext context) {
    final dateSlots = specific
        .map(
          (s) => DateRangeSlot(
            from: s.fromDisplay,
            to: s.toDisplay,
            priceHour: s.priceHour,
            priceDay: s.priceDay,
          ),
        )
        .toList();
    final weekSlots = weekly
        .map(
          (w) => WeeklySlot(
            day: w.dayLabel,
            timeRange: _formatWeeklyRange(w.startTime, w.endTime),
            priceHour: w.priceHour,
            priceDay: w.priceDay,
          ),
        )
        .toList();

    if (dateSlots.isEmpty && weekSlots.isEmpty) {
      return Text(
        'No schedule on file for this spot yet.',
        style: AppTypography.bodyMuted,
      );
    }

    return AppAvailabilitySlots.combined(
      title: 'Available this week',
      dateRangeSlots: dateSlots.isEmpty ? null : dateSlots,
      weeklySlots: weekSlots.isEmpty ? null : weekSlots,
      showTitle: false,
      useOuterPadding: false,
    );
  }
}
