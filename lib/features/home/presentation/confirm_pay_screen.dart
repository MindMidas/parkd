import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
                    _buildSectionLabel('Parking spot'),
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
                    _buildSectionLabel('Reservation'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildRow('From', _formatDateTime(widget.startDateTime)),
                    const SizedBox(height: AppSpacing.xs),
                    _buildRow('To', _formatDateTime(widget.endDateTime)),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // --- Duration ---
                    _buildSectionLabel('Duration'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(widget.durationLabel, style: AppTypography.body),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // --- Price Breakdown ---
                    _buildSectionLabel('Price Breakdown'),
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
                    _buildSectionLabel('Payment Method'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildPaymentMethodCard(),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Terms ---
                    Text(
                      "By completing this reservation, you agree to Parkd's Terms of Service and Parking Policies.",
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      height: 100,
                      child: SingleChildScrollView(
                        child: Text(
                          'Please read the following terms carefully before '
                          'publishing your parking listing on Parkd. By '
                          'creating and publishing a listing, you agree to '
                          'comply with these terms.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // --- Checkbox ---
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (v) =>
                                setState(() => _agreedToTerms = v ?? false),
                            activeColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _agreedToTerms = !_agreedToTerms,
                            ),
                            child: Text(
                              'I agree to the Parkd Terms and Conditions',
                              style: AppTypography.body,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(value, style: AppTypography.body),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primaryBlue),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Visa',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            ' •••• 4242',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
