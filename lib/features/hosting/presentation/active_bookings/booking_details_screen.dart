import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/models/reservation_row.dart';
import '../../../../core/models/reservation_status.dart';
import '../../../../core/models/review_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/directions_launcher.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reservations/presentation/trip_conversation_screen.dart';
import '../../../reservations/presentation/widgets/listing_parking_hero.dart';
import '../../../reviews/presentation/leave_review_screen.dart';
import '../../../reviews/providers/reviews_providers.dart';

String _handleFromDisplayName(String displayName) {
  final t = displayName.trim();
  if (t.isEmpty) return '@guest';
  return '@${t.toLowerCase().replaceAll(' ', '')}';
}

// Host view of a single booking (driver is the guest)
class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.reservation,
    required this.listing,
  });

  final ReservationRow reservation;
  final Listing? listing;

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  String? _actionError;

  ReservationRow get r => widget.reservation;
  Listing? get listing => widget.listing;

  bool get _liveCountdown {
    switch (r.status) {
      case ReservationStatus.completed:
      case ReservationStatus.cancelled:
        return false;
      default:
        return true;
    }
  }

  String get _streetLine => listing?.addressLine ?? 'Parking spot';
  String get _localityLine => listing?.townCountryLine ?? '';
  String? get _spotLabel => listing?.spotLabel;

  Duration get _totalTime => r.endTime.difference(r.startTime);

  Duration get _timeLeft {
    final d = r.endTime.difference(_now);
    return d.isNegative ? Duration.zero : d;
  }

  String get _fullAddress => [
    _streetLine,
    if (_localityLine.isNotEmpty) _localityLine,
    if (_spotLabel != null && _spotLabel!.isNotEmpty) _spotLabel!,
  ].join(', ');

  Future<void> _openDirections(BuildContext context) async {
    setState(() => _actionError = null);
    if (await launchDrivingDirections(_fullAddress)) return;
    if (!mounted) return;
    setState(() => _actionError = 'Could not open directions.');
  }

  @override
  void initState() {
    super.initState();
    if (_liveCountdown) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guestProfile = ref.watch(profileByUserIdProvider(r.driverId));
    final myReviewAsync = ref.watch(myReviewForReservationProvider(r.id));

    if (guestProfile.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(title: 'Booking details', showBack: true),
        body: AppPageStatus.loading(),
      );
    }

    final guestP = guestProfile.asData?.value;
    final guestName = guestP?.displayName ?? 'Driver';
    final u = guestP?.username?.trim();
    final guestHandle = (u != null && u.isNotEmpty)
        ? '@$u'
        : _handleFromDisplayName(guestName);
    final guestAvatar = profileAvatarImageProvider(guestP);
    final canLeaveReview =
        r.status == ReservationStatus.completed &&
        myReviewAsync.maybeWhen(data: (v) => v == null, orElse: () => false);
    final alreadyReviewed = myReviewAsync.maybeWhen(
      data: (v) => v != null,
      orElse: () => false,
    );

    final df = DateFormat('MMM d, y');
    final tf = DateFormat('h:mm a');
    const sep = ' · ';
    final fromStr =
        '${df.format(r.startTime.toLocal())}$sep${tf.format(r.startTime.toLocal())}';
    final toStr =
        '${df.format(r.endTime.toLocal())}$sep${tf.format(r.endTime.toLocal())}';

    final earnings = r.totalPrice;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Booking details', showBack: true),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListingParkingHero(
                listingId: listing?.id,
                fallbackImageUrl: listing?.heroPhotoUrl ?? '',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPersonInlineCard(
                      title: 'Driver',
                      compact: true,
                      displayName: guestName,
                      handle: guestHandle,
                      avatarImageProvider: guestAvatar,
                      ratingLabel: guestP == null
                          ? null
                          : profileRatingLabel(
                              rating: guestP.rating,
                              ratingCount: guestP.ratingCount,
                            ),
                      actionLabel: 'Chat',
                      onActionPressed: () {
                        final uid = ref.read(currentSessionProvider)?.user.id;
                        if (uid == null) return;
                        Navigator.of(context).push<void>(
                          AppPageRoute<void>(
                            builder: (_) => TripConversationScreen(
                              reservationId: r.id,
                              peerUserId: r.driverId,
                              peerDisplayName: guestName,
                              viewTripLabel: 'View booking',
                              onViewTrip: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    if (alreadyReviewed) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'You already left a review for this booking.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text('Location', style: AppTypography.overline),
                    const SizedBox(height: AppSpacing.sm),
                    AppStreetAddressCard(
                      streetLine: _streetLine,
                      localityLine: _localityLine.isNotEmpty
                          ? _localityLine
                          : null,
                      spotLine: _spotLabel,
                      usePrimaryColorForSecondaryLines: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppDisplayTitledOutlineCard(
                      title: 'Duration',
                      child: _liveCountdown
                          ? AppDetailDurationTimingBlock(
                              fromValue: fromStr,
                              toValue: toStr,
                              totalTimeLabel: formatDurationCompact(_totalTime),
                              timeLeftLabel: formatDurationCompact(_timeLeft),
                              animatedKey: ValueKey<String>(
                                formatDurationCompact(_timeLeft),
                              ),
                            )
                          : AppDetailDurationTimingBlock(
                              fromValue: fromStr,
                              toValue: toStr,
                              totalTimeLabel: formatDurationCompact(_totalTime),
                              timeLeftLabel: null,
                              animate: false,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppDisplayTitledOutlineCard(
                      title: 'Payout',
                      child: AppDetailAmountRow(
                        label: 'Your earnings',
                        amount: earnings,
                        moneyStyle: AppMoneyStyle.bodyStrong,
                        moneyColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppReferenceIdCopyField(referenceId: r.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppStickyFooter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_actionError != null) ...[
              AppInlineError(
                message: _actionError!,
                onDismiss: () => setState(() => _actionError = null),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (canLeaveReview) ...[
              AppPrimaryButton(
                label: 'Leave a review',
                onPressed: () {
                  Navigator.of(context).push<void>(
                    AppPageRoute<void>(
                      builder: (_) => LeaveReviewScreen(
                        reservationId: r.id,
                        revieweeId: r.driverId,
                        revieweeDisplayName: guestName,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                label: 'Get directions',
                onPressed: () => _openDirections(context),
              ),
            ] else
              AppPrimaryButton(
                label: 'Get directions',
                onPressed: () => _openDirections(context),
              ),
          ],
        ),
      ),
    );
  }
}
