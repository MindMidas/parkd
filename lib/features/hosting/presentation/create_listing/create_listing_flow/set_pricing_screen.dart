import 'package:flutter/material.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../core/theme/app_colors.dart';

// Hourly and daily pricing step, also reused by availability editors.
class SetPricingScreen extends StatefulWidget {
  const SetPricingScreen({
    super.key,
    this.initialHourly,
    this.initialDaily,
    this.currentStep,
    this.totalSteps,
  });

  final double? initialHourly;
  final double? initialDaily;

  final int? currentStep;
  final int? totalSteps;

  @override
  State<SetPricingScreen> createState() => _SetPricingScreenState();
}

class _SetPricingScreenState extends State<SetPricingScreen> {
  late double _hourly;
  double? _daily;

  @override
  void initState() {
    super.initState();
    _hourly = widget.initialHourly ?? 10.0;
    _daily = widget.initialDaily;
  }

  @override
  Widget build(BuildContext context) {
    final useStepBar = widget.currentStep != null && widget.totalSteps != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: useStepBar
          ? AppStepTopBar(
              title: 'Price',
              currentStep: widget.currentStep!,
              totalSteps: widget.totalSteps!,
            )
          : const AppTopBar(title: 'Price', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    AppListingModifyPriceCard(
                      hourly: _hourly.round(),
                      daily: _daily?.round(),
                      onHourlyChanged: (v) {
                        setState(() {
                          _hourly = v.toDouble().clamp(0.0, 999.0);
                        });
                      },
                      onDailyChanged: (v) {
                        setState(() {
                          if (v == null) {
                            _daily = null;
                          } else {
                            _daily = v.toDouble().clamp(0.0, 9999.0);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            AppStickyFooter(
              child: AppPrimaryButton(
                label: 'Save',
                onPressed: () =>
                    Navigator.pop(context, (hourly: _hourly, daily: _daily)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
