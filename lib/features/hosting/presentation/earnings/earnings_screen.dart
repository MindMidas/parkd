import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/host_earnings_row.dart';
import '../../../../core/models/host_payment_transaction.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/listing_search.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../providers/hosting_providers.dart';
import '../active_bookings/booking_details_screen.dart';

final _paidDateFmt = DateFormat('MMM d, y');

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  late final TextEditingController _searchController;
  String _txnSearchQuery = '';

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
    if (l != null && listingMatchesSearchQuery(l, q)) return true;
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

  @override
  Widget build(BuildContext context) {
    final monthlyAsync = ref.watch(hostEarningsForCurrentUserProvider);
    final txnsAsync = ref.watch(hostSucceededTransactionsForCurrentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Earnings',
        showBack: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
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
                        'Up to three months, by when each booking starts. '
                        'Search only filters the paid trips below.',
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
            child: txnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const AppMutedBodyCenter(
                'Could not load earnings.',
              ),
              data: (txns) {
                final filtered =
                    txns.where((t) => _txnMatches(t, _txnSearchQuery)).toList();
                if (filtered.isEmpty) {
                  return AppMutedBodyCenter(
                    txns.isEmpty
                        ? 'No earnings yet'
                        : 'No transactions match your search.',
                  );
                }
                return AppDividerSeparatedListView(
                  itemCount: filtered.length,
                  rowBuilder: (context, index) =>
                      _TransactionRow(txn: filtered[index]),
                );
              },
            ),
          ),
        ],
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
        Text(
          row.reservationCount == 1
              ? '1 trip'
              : '${row.reservationCount} trips',
          style: AppTypography.caption,
        ),
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
    final paid = txn.payment.createdAt ?? txn.payment.updatedAt ?? DateTime.now();

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
          MaterialPageRoute<void>(
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
