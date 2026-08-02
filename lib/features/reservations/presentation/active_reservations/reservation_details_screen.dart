import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/models/payment_record_status.dart';
import '../../../../core/models/reservation_row.dart';
import '../../../../core/models/reservation_status.dart';
import '../../../../core/stripe/stripe_checkout_provider.dart';
import '../../../../core/stripe/stripe_checkout_remote.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/directions_launcher.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/utils/reservation_cancel_policy.dart';
import '../../../../core/models/review_row.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reviews/presentation/leave_review_screen.dart';
import '../../../reviews/providers/reviews_providers.dart';
import '../../providers/reservations_providers.dart';
import '../trip_conversation_screen.dart';
import '../widgets/listing_parking_hero.dart';

String _handleFromDisplayName(String displayName) {
  final t = displayName.trim();
  if (t.isEmpty) return '@host';
  return '@${t.toLowerCase().replaceAll(' ', '')}';
}

// Driver view of a trip they booked
class ReservationDetailsScreen extends ConsumerStatefulWidget {
  const ReservationDetailsScreen({
    super.key,
    required this.reservation,
    required this.listing,
  });

  final ReservationRow reservation;
  final Listing? listing;

  @override
  ConsumerState<ReservationDetailsScreen> createState() =>
      _ReservationDetailsScreenState();
}

class _ReservationDetailsScreenState
    extends ConsumerState<ReservationDetailsScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _cancelling = false;
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

  bool get _canCancel => reservationIsDriverCancellable(
    r.startTime,
    status: r.status.name,
    now: _now,
  );

  bool get _cancelRefundable =>
      reservationCancelIsRefundable(r.startTime, now: _now);

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

  Future<void> _confirmCancel() async {
    if (_cancelling || !_canCancel) return;
    final refundable = _cancelRefundable;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: 'Cancel reservation?',
        message: refundable
            ? 'This booking will be cancelled and you’ll receive a full refund.'
            : 'This booking will be cancelled. Because you’re within 2 hours of '
                  'the start time, the payment is not refundable.',
        cancelLabel: 'Keep',
        confirmLabel: 'Cancel reservation',
        confirmDestructive: true,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
      _actionError = null;
    });
    try {
      final result = await ref
          .read(stripeCheckoutRemoteProvider)
          .cancelReservation(reservationId: r.id);
      ref.invalidate(driverActiveReservationsProvider);
      ref.invalidate(driverPastReservationsProvider);
      ref.invalidate(driverActiveTripsProvider);
      ref.invalidate(driverPastTripsProvider);
      ref.invalidate(reservationByIdProvider(r.id));
      ref.invalidate(reservationPaymentProvider(r.id));
      ref.invalidate(hostActiveReservationsProvider);
      ref.invalidate(hostPastReservationsProvider);
      if (!mounted) return;
      AppMessenger.showSuccess(
        context,
        result.refunded
            ? 'Reservation cancelled. Your refund is on the way.'
            : 'Reservation cancelled.',
      );
      Navigator.of(context).pop();
    } on StripeCheckoutRemoteException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError = 'Could not cancel this reservation. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
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
    final hostProfile = ref.watch(profileByUserIdProvider(r.hostId));
    final payAsync = ref.watch(reservationPaymentProvider(r.id));
    final myReviewAsync = ref.watch(myReviewForReservationProvider(r.id));

    if (hostProfile.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(title: 'Reservation details', showBack: true),
        body: AppPageStatus.loading(),
      );
    }

    final hostP = hostProfile.asData?.value;
    final hostName = hostP?.displayName ?? 'Host';
    final u = hostP?.username?.trim();
    final hostHandle = (u != null && u.isNotEmpty)
        ? '@$u'
        : _handleFromDisplayName(hostName);
    final hostAvatar = profileAvatarImageProvider(hostP);
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Reservation details', showBack: true),
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
                      title: 'Host',
                      compact: true,
                      displayName: hostName,
                      handle: hostHandle,
                      avatarImageProvider: hostAvatar,
                      ratingLabel: hostP == null
                          ? null
                          : profileRatingLabel(
                              rating: hostP.rating,
                              ratingCount: hostP.ratingCount,
                            ),
                      actionLabel: 'Chat',
                      onActionPressed: () {
                        final uid = ref.read(currentSessionProvider)?.user.id;
                        if (uid == null) return;
                        Navigator.of(context).push<void>(
                          AppPageRoute<void>(
                            builder: (_) => TripConversationScreen(
                              reservationId: r.id,
                              peerUserId: r.hostId,
                              peerDisplayName: hostName,
                            ),
                          ),
                        );
                      },
                    ),
                    if (alreadyReviewed) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'You already left a review for this trip.',
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
                    payAsync.when(
                      data: (pay) {
                        final totalDue = r.totalPrice + r.serviceFee;
                        late final String label;
                        late final Color? moneyColor;
                        late final AppMoneyStyle moneyStyle;
                        switch (pay?.status) {
                          case PaymentRecordStatus.succeeded:
                            label = 'Paid';
                            moneyColor = AppColors.success;
                            moneyStyle = AppMoneyStyle.bodyStrong;
                          case PaymentRecordStatus.pending:
                            label = 'Payment pending';
                            moneyColor = AppColors.textSecondary;
                            moneyStyle = AppMoneyStyle.body;
                          case PaymentRecordStatus.failed:
                            label = 'Payment failed';
                            moneyColor = AppColors.error;
                            moneyStyle = AppMoneyStyle.body;
                          case PaymentRecordStatus.refunded:
                            label = 'Refunded';
                            moneyColor = AppColors.textSecondary;
                            moneyStyle = AppMoneyStyle.body;
                          case null:
                            label = r.status == ReservationStatus.pending
                                ? 'Unpaid'
                                : 'Payment';
                            moneyColor = AppColors.textSecondary;
                            moneyStyle = AppMoneyStyle.body;
                        }
                        return AppDisplayTitledOutlineCard(
                          title: 'Cost',
                          child: AppDetailAmountRow(
                            label: label,
                            amount: totalDue,
                            moneyStyle: moneyStyle,
                            moneyColor: moneyColor,
                          ),
                        );
                      },
                      loading: () => AppDisplayTitledOutlineCard(
                        title: 'Cost',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: Text(
                              'Loading payment…',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      error: (error, stackTrace) => AppDisplayTitledOutlineCard(
                        title: 'Cost',
                        child: AppDetailAmountRow(
                          label: 'Payment',
                          amount: r.totalPrice + r.serviceFee,
                          moneyStyle: AppMoneyStyle.body,
                          moneyColor: AppColors.textSecondary,
                        ),
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
                onPressed: _cancelling
                    ? null
                    : () {
                        Navigator.of(context).push<void>(
                          AppPageRoute<void>(
                            builder: (_) => LeaveReviewScreen(
                              reservationId: r.id,
                              revieweeId: r.hostId,
                              revieweeDisplayName: hostName,
                            ),
                          ),
                        );
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_canCancel) ...[
              AppSecondaryButton(
                label: 'Cancel reservation',
                destructive: true,
                loading: _cancelling,
                onPressed: _cancelling ? null : _confirmCancel,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (canLeaveReview)
              AppSecondaryButton(
                label: 'Get directions',
                onPressed: _cancelling ? null : () => _openDirections(context),
              )
            else
              AppPrimaryButton(
                label: 'Get directions',
                onPressed: _cancelling ? null : () => _openDirections(context),
              ),
          ],
        ),
      ),
    );
  }
}
