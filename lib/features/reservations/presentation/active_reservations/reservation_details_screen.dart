import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/models/payment_record_status.dart';
import '../../../../core/models/reservation_row.dart';
import '../../../../core/models/reservation_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/messaging/app_messenger.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/display_formatting.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/reservations_providers.dart';
import '../trip_conversation_screen.dart';

String _handleFromDisplayName(String displayName) {
  final t = displayName.trim();
  if (t.isEmpty) return '@host';
  return '@${t.toLowerCase().replaceAll(' ', '')}';
}

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

class _ReservationDetailsScreenState extends ConsumerState<ReservationDetailsScreen> {
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
  String get _localityLine => listing?.localityLine ?? '';
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
    final destination = Uri.encodeComponent(_fullAddress);
    final url = Uri.parse('https://maps.apple.com/?daddr=$destination&dirflg=d');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
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
    final hostProfile = ref.watch(profileByUserIdProvider(r.hostId));
    final payAsync = ref.watch(reservationPaymentProvider(r.id));

    if (hostProfile.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(
          title: 'Reservation details',
          showBack: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hostP = hostProfile.asData?.value;
    final hostName = hostP?.displayName ?? 'Host';
    final u = hostP?.username?.trim();
    final hostHandle = (u != null && u.isNotEmpty)
        ? '@$u'
        : _handleFromDisplayName(hostName);
    final hostAvatar = profileAvatarImageProvider(hostP);

    final df = DateFormat('MMM d, y');
    final tf = DateFormat('h:mm a');
    const sep = ' · ';
    final fromStr =
        '${df.format(r.startTime.toLocal())}$sep${tf.format(r.startTime.toLocal())}';
    final toStr =
        '${df.format(r.endTime.toLocal())}$sep${tf.format(r.endTime.toLocal())}';

    final bottomInset = scrollViewBottomInset(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Reservation details',
        showBack: true,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.lg + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReservationParkingHeroFrame(
                listingId: listing?.id,
                fallbackImageUrl: listing?.heroPhotoUrl ?? '',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
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
                      actionLabel: 'Chat',
                      onActionPressed: () {
                        final uid = ref.read(currentSessionProvider)?.user.id;
                        if (uid == null) return;
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => TripConversationScreen(
                              reservationId: r.id,
                              peerDisplayName: hostName,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppStreetAddressCard(
                      title: 'Parking location',
                      streetLine: _streetLine,
                      localityLine:
                          _localityLine.isNotEmpty ? _localityLine : null,
                      spotLine: _spotLabel,
                      usePrimaryColorForSecondaryLines: true,
                      footer: AppPrimaryButton(
                        label: 'Get directions',
                        icon: Icons.explore_outlined,
                        onPressed: () => _openDirections(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppDisplayTitledOutlineCard(
                      title: 'Reservation duration',
                      child: _liveCountdown
                          ? AppDetailDurationTimingBlock(
                              fromValue: fromStr,
                              toValue: toStr,
                              totalTimeLabel:
                                  formatDurationCompact(_totalTime),
                              timeLeftLabel:
                                  formatDurationCompact(_timeLeft),
                              animatedKey: ValueKey<String>(
                                formatDurationCompact(_timeLeft),
                              ),
                            )
                          : AppDetailDurationTimingBlock(
                              fromValue: fromStr,
                              toValue: toStr,
                              totalTimeLabel:
                                  formatDurationCompact(_totalTime),
                              timeLeftLabel: null,
                              animate: false,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                      error: (error, stackTrace) =>
                          AppDisplayTitledOutlineCard(
                        title: 'Cost',
                        child: AppDetailAmountRow(
                          label: 'Payment',
                          amount: r.totalPrice + r.serviceFee,
                          moneyStyle: AppMoneyStyle.body,
                          moneyColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppReferenceIdCopyField(referenceId: r.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationParkingHeroFrame extends ConsumerWidget {
  const _ReservationParkingHeroFrame({
    this.listingId,
    required this.fallbackImageUrl,
  });

  final String? listingId;
  final String fallbackImageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = listingId?.trim();
    if (id == null || id.isEmpty) {
      return _ReservationHeroContent(
        imageUrl: fallbackImageUrl,
        markerFraction: null,
      );
    }

    final photosAsync = ref.watch(listingPhotosProvider(id));
    return photosAsync.when(
      data: (photos) {
        final sorted = [...photos]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final first = sorted.isNotEmpty ? sorted.first : null;
        final fromPhoto = first?.photoUrl.trim() ?? '';
        final url = fromPhoto.isNotEmpty ? fromPhoto : fallbackImageUrl.trim();
        Offset? marker;
        if (first != null &&
            first.markerX != null &&
            first.markerY != null) {
          marker = Offset(first.markerX!, first.markerY!);
        }
        return _ReservationHeroContent(
          imageUrl: url,
          markerFraction: marker,
        );
      },
      loading: () => _ReservationHeroContent(
        imageUrl: fallbackImageUrl,
        markerFraction: null,
      ),
      error: (_, _) => _ReservationHeroContent(
        imageUrl: fallbackImageUrl,
        markerFraction: null,
      ),
    );
  }
}

class _ReservationHeroContent extends StatelessWidget {
  const _ReservationHeroContent({
    required this.imageUrl,
    required this.markerFraction,
  });

  final String imageUrl;
  final Offset? markerFraction;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final Widget photo;
    if (url.isEmpty) {
      photo = ColoredBox(
        color: AppColors.secondaryBlue.withValues(alpha: 0.35),
        child: Center(
          child: Icon(
            Icons.local_parking_rounded,
            size: 56,
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
          ),
        ),
      );
    } else {
      photo = Image.network(
        url,
        key: ValueKey<String>(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: AppColors.secondaryBlue.withValues(alpha: 0.15),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.secondaryBlue.withValues(alpha: 0.25),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.iconGrey,
              size: 40,
            ),
          ),
        ),
      );
    }

    final withMarker = markerFraction != null
        ? AppListingPhotoSpotOverlay(
            markerFraction: markerFraction,
            child: photo,
          )
        : photo;

    return AppListingPhotoFrame(
      onTap: url.isNotEmpty
          ? () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AppNetworkImageFullscreenScreen(
                    imageUrl: url,
                    markerFraction: markerFraction,
                  ),
                ),
              );
            }
          : null,
      overlay: url.isNotEmpty
          ? Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: AppScrimIconLabelPill(
                icon: Icons.open_in_full_rounded,
                label: 'Expand',
                scrimColor: AppColors.scrimOnImage,
              ),
            )
          : null,
      child: withMarker,
    );
  }
}
