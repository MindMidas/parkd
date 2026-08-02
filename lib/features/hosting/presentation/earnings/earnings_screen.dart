import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/host_earnings_row.dart';
import '../../../../core/models/host_payment_transaction.dart';
import '../../../../core/stripe/stripe_checkout_provider.dart';
import '../../../../core/stripe/stripe_connect_remote.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/hosting_providers.dart';
import '../active_bookings/booking_details_screen.dart';

final _paidDateFmt = DateFormat('MMM d, y');

// Earnings: Connect payouts setup + monthly rollups + paid trip lines.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  late final TextEditingController _searchController;
  String _txnSearchQuery = '';
  bool _connectBusy = false;
  String? _actionError;

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

  bool _txnMatches(HostPaymentTransaction t, String q) {
    if (q.isEmpty) return true;
    final low = q.toLowerCase();
    final l = t.listing;
    if (l != null) {
      if (l.addressLine.toLowerCase().contains(low)) return true;
      if (l.localityLine.toLowerCase().contains(low)) return true;
      if (l.spotLabel?.toLowerCase().contains(low) == true) return true;
    }
    if (t.reservation.id.toLowerCase().contains(low)) return true;
    if (t.payment.id.toLowerCase().contains(low)) return true;
    if (t.netToHost.toString().contains(low)) return true;
    final paid = t.payment.createdAt ?? t.payment.updatedAt;
    if (paid != null &&
        _paidDateFmt.format(paid.toLocal()).toLowerCase().contains(low)) {
      return true;
    }
    return false;
  }

  Future<void> _refreshConnect() async {
    ref.invalidate(stripeConnectStatusProvider);
  }

  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      setState(() => _actionError = 'Could not open Stripe.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _actionError = 'Could not open Stripe.');
    }
  }

  Future<void> _startOnboarding() async {
    if (_connectBusy) return;
    setState(() {
      _connectBusy = true;
      _actionError = null;
    });
    try {
      final status = await ref
          .read(stripeConnectRemoteProvider)
          .startOnboarding();
      ref.invalidate(stripeConnectStatusProvider);
      if (!mounted) return;
      if (status.payoutsReady) {
        AppMessenger.showSuccess(context, 'Payouts are ready.');
        return;
      }
      final url = status.url;
      if (url == null) {
        setState(
          () => _actionError =
              'Stripe did not return an onboarding link. Try again.',
        );
        return;
      }
      await _openUrl(url);
    } on StripeConnectRemoteException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Could not start payout setup.');
      }
    } finally {
      if (mounted) setState(() => _connectBusy = false);
    }
  }

  Future<void> _openDashboard() async {
    if (_connectBusy) return;
    setState(() {
      _connectBusy = true;
      _actionError = null;
    });
    try {
      final status = await ref
          .read(stripeConnectRemoteProvider)
          .openDashboard();
      final url = status.url;
      if (!mounted) return;
      if (url == null) {
        setState(() => _actionError = 'Could not open Stripe dashboard.');
        return;
      }
      await _openUrl(url);
    } on StripeConnectRemoteException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Could not open Stripe dashboard.');
      }
    } finally {
      if (mounted) setState(() => _connectBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthlyAsync = ref.watch(hostEarningsForCurrentUserProvider);
    final txnsAsync = ref.watch(
      hostSucceededTransactionsForCurrentUserProvider,
    );
    final connectAsync = ref.watch(stripeConnectStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Earnings', showBack: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: AppInlineError(
                message: _actionError!,
                onDismiss: () => setState(() => _actionError = null),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              _actionError != null ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _PayoutsCard(
              statusAsync: connectAsync,
              busy: _connectBusy,
              onRefresh: _refreshConnect,
              onSetup: _startOnboarding,
              onDashboard: _openDashboard,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: monthlyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
              data: (months) {
                if (months.isEmpty) return const SizedBox.shrink();
                final top = months.take(3).toList();
                return AppDisplayTitledOutlineCard(
                  title: 'Monthly summary',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppFormHelperText(
                        'Up to three recent calendar months: your parking earnings '
                        '(sum of trip prices) grouped by when each reservation '
                        'starts.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < top.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        _MonthSummaryRow(row: top[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppListScreenSearchPanel(
              controller: _searchController,
              hintText: 'Search by guest or address',
              onChanged: (value) => setState(() => _txnSearchQuery = value),
            ),
          ),
          Expanded(
            child: AppAsyncBody(
              value: txnsAsync,
              errorTitle: 'Could not load earnings.',
              errorMessage: 'Check your connection and try again.',
              data: (txns) {
                final filtered = txns
                    .where((t) => _txnMatches(t, _txnSearchQuery))
                    .toList();
                if (filtered.isEmpty) {
                  return AppPageStatus.empty(
                    title: txns.isEmpty ? 'No earnings yet' : 'No matches',
                    message: txns.isEmpty
                        ? 'Paid bookings will show up here after guests book.'
                        : 'Try a different guest or address.',
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: filtered.length + 2,
                  separatorBuilder: (_, _) => const AppDividerWide(),
                  itemBuilder: (context, index) {
                    if (index == 0 || index == filtered.length + 1) {
                      return const SizedBox.shrink();
                    }
                    return _TransactionRow(txn: filtered[index - 1]);
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

class _PayoutsCard extends StatelessWidget {
  const _PayoutsCard({
    required this.statusAsync,
    required this.busy,
    required this.onRefresh,
    required this.onSetup,
    required this.onDashboard,
  });

  final AsyncValue<StripeConnectStatus> statusAsync;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onSetup;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: 'Payouts',
      child: statusAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: AppPageStatus.loading(),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Could not load payout status.',
              style: AppTypography.caption.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Try again',
              onPressed: busy ? null : onRefresh,
            ),
          ],
        ),
        data: (status) {
          final ready = status.payoutsReady;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ready
                    ? 'Stripe payouts are ready. New bookings send your parking '
                          'earnings to your connected account.'
                    : 'Connect Stripe so booking earnings can be paid out.',
                style: AppTypography.caption.copyWith(height: 1.4),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ready
                    ? 'Status: Ready'
                    : status.connected
                    ? 'Status: Finish setup in Stripe'
                    : 'Status: Not connected',
                style: AppTypography.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.md),
              if (ready) ...[
                AppPrimaryButton(
                  label: 'Open Stripe dashboard',
                  loading: busy,
                  onPressed: busy ? null : onDashboard,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSecondaryButton(
                  label: 'Refresh status',
                  onPressed: busy ? null : onRefresh,
                ),
              ] else ...[
                AppPrimaryButton(
                  label: status.connected
                      ? 'Continue Stripe setup'
                      : 'Set up payouts',
                  loading: busy,
                  onPressed: busy ? null : onSetup,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSecondaryButton(
                  label: 'Refresh status',
                  onPressed: busy ? null : onRefresh,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MonthSummaryRow extends StatelessWidget {
  const _MonthSummaryRow({required this.row});

  final HostEarningsRow row;

  static final _monthFmt = DateFormat('MMMM y');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _monthFmt.format(row.month.toLocal()),
            style: AppTypography.body,
          ),
        ),
        Text('${row.reservationCount} trips', style: AppTypography.caption),
        const SizedBox(width: AppSpacing.md),
        AppMoneyText(
          row.grossEarnings,
          style: AppMoneyStyle.bodyStrong,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.txn});

  final HostPaymentTransaction txn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(profileByUserIdProvider(txn.reservation.driverId));
    final name = driver.maybeWhen(
      data: (p) => p?.displayName ?? 'Driver',
      orElse: () => 'Driver',
    );
    final avatar = profileAvatarImageProvider(driver.asData?.value);
    final paid =
        txn.payment.createdAt ?? txn.payment.updatedAt ?? DateTime.now();

    return AppMenuRow(
      leadingType: AppMenuLeadingType.profile,
      leadingImageProvider: avatar,
      title: name,
      subtitle: 'Paid ${_paidDateFmt.format(paid.toLocal())}',
      rightKind: AppMenuRightKind.amount,
      rightAmount: txn.netToHost,
      rightAmountPrefix: '+ ',
      rightAmountStyle: AppMoneyStyle.bodyStrong,
      rightAmountColor: AppColors.success,
      onTap: () {
        Navigator.of(context).push<void>(
          AppPageRoute<void>(
            builder: (_) => BookingDetailsScreen(
              reservation: txn.reservation,
              listing: txn.listing,
            ),
          ),
        );
      },
    );
  }
}
