import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'payment_success_screen.dart';

class ConfirmPayScreen extends StatefulWidget {
  const ConfirmPayScreen({
    super.key,
    required this.streetAddress,
    required this.cityLine,
    required this.startDateTime,
    required this.endDateTime,
    required this.durationLabel,
    required this.subtotal,
    required this.latitude,
    required this.longitude,
  });

  final String streetAddress;
  final String cityLine;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String durationLabel;
  final double subtotal;
  final double latitude;
  final double longitude;

  @override
  State<ConfirmPayScreen> createState() => _ConfirmPayScreenState();
}

class _ConfirmPayScreenState extends State<ConfirmPayScreen> {
  bool _agreedToTerms = false;

  double get _serviceFee => (widget.subtotal * 0.035 * 100).round() / 100;
  double get _total => widget.subtotal + _serviceFee;

  String _formatDateTime(DateTime dt) {
    return '${DateFormat('MMM d, y').format(dt)} • ${DateFormat('h:mm a').format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    'Confirm & Pay',
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // --- Scrollable content ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // --- Parking spot ---
                    const AppSectionLabel('Parking spot'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.streetAddress,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.cityLine.isNotEmpty)
                      Text(widget.cityLine, style: AppTypography.body),
                    Text(
                      'Spot #345',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // --- Reservation ---
                    const AppSectionLabel('Reservation'),
                    const SizedBox(height: AppSpacing.sm),
                    AppLabelValueRow(label: 'From', value: _formatDateTime(widget.startDateTime)),
                    const SizedBox(height: AppSpacing.xs),
                    AppLabelValueRow(label: 'To', value: _formatDateTime(widget.endDateTime)),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // --- Duration ---
                    const AppSectionLabel('Duration'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(widget.durationLabel, style: AppTypography.body),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // --- Price Breakdown ---
                    const AppSectionLabel('Price Breakdown'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Subtotal: \$${widget.subtotal.toStringAsFixed(2)}',
                      style: AppTypography.body,
                    ),
                    Text(
                      'Service fee: \$${_serviceFee.toStringAsFixed(2)}',
                      style: AppTypography.body,
                    ),
                    Text(
                      'Total: \$${_total.toStringAsFixed(2)}',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // --- Payment Method ---
                    const AppSectionLabel('Payment Method'),
                    const SizedBox(height: AppSpacing.sm),
                    const AppPaymentMethodPill(brand: 'Visa', lastFour: '4242'),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Terms ---
                    AppTermsCheckbox(
                      heading: "By completing this reservation, you agree to Parkd's Terms of Service and Parking Policies.",
                      termsText: 'Please read the following terms carefully before '
                          'publishing your parking listing on Parkd. By '
                          'creating and publishing a listing, you agree to '
                          'comply with these terms.',
                      checkboxLabel: 'I agree to the Parkd Terms and Conditions',
                      value: _agreedToTerms,
                      onChanged: (v) => setState(() => _agreedToTerms = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            // --- Pay & Reserve button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreedToTerms
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PaymentSuccessScreen(
                                latitude: widget.latitude,
                                longitude: widget.longitude,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pay & Reserve',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.bolt, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
