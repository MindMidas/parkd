import 'package:flutter/material.dart';
import 'package:parkd/core/widgets/app_step_top_bar.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';

class SetPricingScreen extends StatefulWidget {
  const SetPricingScreen({
    super.key,
    this.initialHourly,
    this.initialDaily,
  });

  final double? initialHourly;
  final double? initialDaily;

  @override
  State<SetPricingScreen> createState() => _SetPricingScreenState();
}

class _SetPricingScreenState extends State<SetPricingScreen> {
  late double _hourly;
  late double _daily;

  @override
  void initState() {
    super.initState();
    _hourly = widget.initialHourly ?? 5.0;
    _daily = widget.initialDaily ?? 30.0;
  }

  void _step(bool isHourly, int delta) {
    setState(() {
      if (isHourly) {
        _hourly = (_hourly + delta).clamp(1.0, 999.0);
      } else {
        _daily = (_daily + delta).clamp(1.0, 999.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppStepTopBar(
        title: 'Set your price',
        currentStep: 5,
        totalSteps: 5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Choose how much drivers pay',
                      style: AppTypography.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Hourly stepper
                    AppTimeStepperRow(
                      label: 'Hourly price',
                      value: '\$${_hourly.toStringAsFixed(0)}',
                      labelWidth: 140,
                      onDecrement: () => _step(true, -1),
                      onIncrement: () => _step(true, 1),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Daily stepper
                    AppTimeStepperRow(
                      label: 'Daily price (optional)',
                      value: '\$${_daily.toStringAsFixed(0)}',
                      labelWidth: 140,
                      onDecrement: () => _step(false, -1),
                      onIncrement: () => _step(false, 1),
                    ),
                  ],
                ),
              ),
            ),

            // Save button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: AppPrimaryButton(
                label: 'Save',
                onPressed: () => Navigator.pop(
                  context,
                  (hourly: _hourly, daily: _daily),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}