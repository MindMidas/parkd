import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/models/reservation_row.dart';
import '../../../../core/models/reservation_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/directions_launcher.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';

/// Host view of a single booking (driver is the guest)
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
    if (await launchDrivingDirections(_fullAddress)) return;
    if (!context.mounted) return;
    AppMessenger.showError(context, 'Could not open directions.');
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
    final guestName = guestProfile.maybeWhen(
      data: (p) => p?.displayName ?? 'Driver',
      orElse: () => 'Driver',
    );
    final guestHandle = guestProfile.maybeWhen(
      data: (p) => p?.username != null ? '@${p!.username}' : '@guest',
      orElse: () => '@guest',
    );
    final guestAvatar = profileAvatarImageProvider(guestProfile.asData?.value);

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
      body: AppDetailScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPersonInlineCard(
              title: 'Driver',
              compact: true,
              displayName: guestName,
              handle: guestHandle,
              avatarImageProvider: guestAvatar,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Location', style: AppTypography.overline),
            const SizedBox(height: AppSpacing.sm),
            AppStreetAddressCard(
              streetLine: _streetLine,
              localityLine: _localityLine.isNotEmpty ? _localityLine : null,
              spotLine: _spotLabel,
              usePrimaryColorForSecondaryLines: true,
              footer: AppPrimaryButton(
                label: 'Get directions',
                icon: Icons.explore_outlined,
                onPressed: () => _openDirections(context),
              ),
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
    );
  }
}
