import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/listing_next_available.dart';
import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/booking_time_window.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/review_row.dart';
import '../../../core/models/slot_pricing_summary.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
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
  if (data.weekly.isNotEmpty) return false;
  final now = DateTime.now();
  return !listingHasFutureSpecificWindow(data.specific, now: now);
}

const String kListingDetailSheetResultFull = 'full';

// Fixed ~70% height; only the top handle expands to full detail — body scrolls independently
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
                  top: Radius.circular(AppRadius.sheet),
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
                        child: const AppBottomSheetGrabber(),
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
          ratingLabel: profile == null
              ? null
              : profileRatingLabel(
                  rating: profile.rating,
                  ratingCount: profile.ratingCount,
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListingPhotoFrame(
          heroTag: 'listing-photo-${listing.id}',
          borderRadius: AppRadius.md,
          overlay: null,
          child: _heroPhoto(
            listing: listing,
            photos: data?.photos,
            loading: false,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Location', style: AppTypography.overline),
        const SizedBox(height: AppSpacing.sm),
        AppStreetAddressCard(
          streetLine: listing.revealsExactStreetAddress
              ? listing.addressLine
              : (listing.townCountryLine.isNotEmpty
                    ? listing.townCountryLine
                    : listing.approximateAreaHeadline),
          localityLine: listing.revealsExactStreetAddress &&
                  listing.townCountryLine.isNotEmpty
              ? listing.townCountryLine
              : null,
          spotLine: listing.spotLabel,
          usePrimaryColorForSecondaryLines: true,
          footer: !listing.revealsExactStreetAddress
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppApproximateLocationMap(
                      latitude: listing.latitude,
                      longitude: listing.longitude,
                      showApproximateHalo: listing.isApproximateLocation,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      listing.isApproximateLocation
                          ? 'Exact location will be provided after booking.'
                          : 'Exact street address will be provided after booking.',
                      style: AppTypography.caption,
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Availability', style: AppTypography.overline),
        const SizedBox(height: AppSpacing.sm),
        AppDisplayOutlineCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Heatmap', style: AppTypography.captionStrong),
              const SizedBox(height: AppSpacing.sm),
              AppListingAvailabilityHeatmap(
                loading: false,
                listing: listing,
                weekly: heatmapSchedule.weekly,
                specific: heatmapSchedule.specific,
                bookings: heatmapSchedule.bookings,
              ),
              const SizedBox(height: AppSpacing.md),
              const AppDividerWide(),
              const SizedBox(height: AppSpacing.md),
              Text('Hours & pricing', style: AppTypography.captionStrong),
              const SizedBox(height: AppSpacing.sm),
              _AvailabilitySection(
                weekly: data?.weekly ?? const [],
                specific: data?.specific ?? const [],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildLoadingOrErrorBody() {
    if (_loadFailed) {
      return const AppPageStatus.error(
        title: 'Could not load this listing.',
        message: 'Check your connection and try again.',
      );
    }
    return const AppPageStatus.loading();
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
    final noAvailability =
        data != null && _noPublishedAvailability(data);
    final disabled = isOwnListing || data == null || noAvailability;
    final String? helper;
    if (isOwnListing) {
      helper = 'This is your listing.';
    } else if (noAvailability) {
      helper = 'No availability to book right now.';
    } else {
      helper = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (helper != null) ...[
          Text(
            helper,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppPrimaryButton(
          label: 'Reserve',
          onPressed: disabled
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
                  Navigator.of(context).push<void>(
                    AppPageRoute<void>(
                      builder: (_) => ReservationScreen(
                        listing: listing,
                        weekly: heat.weekly,
                        specific: heat.specific,
                        bookings: heat.bookings,
                        heatmapLoading: false,
                        hourlyRate: hr,
                        dailyRate: minD ?? hr * 8,
                        streetAddress: listing.addressLine,
                        localityLine: listing.townCountryLine.isNotEmpty
                            ? listing.townCountryLine
                            : listing.localityLine,
                        spotLabel: listing.spotLabel,
                        latitude: listing.latitude,
                        longitude: listing.longitude,
                        availableWeekdays: weekdays,
                      ),
                    ),
                  );
                },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final data = _data;

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
          AppStickyFooter(
            child: _reserveButton(
              listing,
              ready ? data : null,
              isOwnListing: isOwnListing,
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
                AppOverflowMenuButton(
                  tooltip: 'Safety options',
                  onSelected: _onSafetyAction,
                  items: const [
                    AppOverflowMenuItem(
                      value: 'report',
                      label: 'Report listing',
                      icon: Icons.flag_outlined,
                    ),
                    AppOverflowMenuItem(
                      value: 'block',
                      label: 'Block host',
                      icon: Icons.block_rounded,
                      destructive: true,
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
          AppStickyFooter(
            child: _reserveButton(
              listing,
              ready ? data : null,
              isOwnListing: isOwnListing,
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
        style: AppTypography.caption,
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
