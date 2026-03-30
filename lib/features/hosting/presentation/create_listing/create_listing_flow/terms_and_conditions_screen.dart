import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/messaging/app_messenger.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../create_listing_draft.dart';
import '../create_listing_publish.dart';

class TermsAndConditionsScreen extends ConsumerStatefulWidget {
  const TermsAndConditionsScreen({
    super.key,
    required this.draft,
    required this.onPublishSuccess,
    this.currentStep,
    this.totalSteps,
  });

  final CreateListingDraft draft;
  final VoidCallback onPublishSuccess;

  final int? currentStep;
  final int? totalSteps;

  @override
  ConsumerState<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState
    extends ConsumerState<TermsAndConditionsScreen> {
  bool _agreed = false;
  bool _publishing = false;

  Future<void> _publish() async {
    if (!_agreed || _publishing) return;
    if (!widget.draft.isCompleteForPublish) {
      AppMessenger.showError(
        context,
        'Something is missing from your listing. Go back and check each step.',
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      await CreateListingPublish.submit(ref, widget.draft);
      if (!mounted) return;
      widget.onPublishSuccess();
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          CreateListingPublish.describePublishError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final useStepBar =
        widget.currentStep != null && widget.totalSteps != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: useStepBar
          ? AppStepTopBar(
              title: 'Terms and Conditions',
              currentStep: widget.currentStep!,
              totalSteps: widget.totalSteps!,
            )
          : const AppTopBar(
              title: 'Terms and Conditions',
              showBack: true,
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      'Please read and agree before publishing your listing',
                      textAlign: TextAlign.center,
                      style: AppTypography.navTitle.copyWith(
                        color: AppColors.black,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),

                    const AppFormHelperText('Terms and Conditions'),

                    const SizedBox(height: AppSpacing.sm),

                    const AppFormHelperText(
                      'Please read the following terms carefully before publishing your parking listing on Parkd. '
                      'By creating and publishing a listing, you agree to comply with these terms.',
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppTermsNumberedSection(
                      number: '1',
                      title: 'Accurate Listing Information',
                      body:
                          'Hosts are responsible for ensuring that all listing information is accurate and up to date. '
                          'This includes the parking location, availability, pricing, photos, and any additional details provided. '
                          'Misleading or inaccurate listings may be removed by Parkd at any time.',
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    AppTermsNumberedSection(
                      number: '2',
                      title: 'Legal Use of Parking Space',
                      body:
                          'By listing a parking space, you confirm that you have the legal right to rent or share the parking spot. '
                          'The space must not violate local laws, building policies, or homeowner association regulations. '
                          'Parkd is not responsible for verifying ownership or authorization of the parking location.',
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    AppTermsNumberedSection(
                      number: '3',
                      title: 'Safety and Accessibility',
                      body:
                          'Hosts agree to provide parking spaces that are reasonably safe and accessible for drivers. '
                          'Any hazards, restrictions, or access instructions must be clearly communicated in the listing description. '
                          'Parkd is not liable for accidents or damages resulting from unsafe parking environments.',
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    AppTermsNumberedSection(
                      number: '4',
                      title: 'Pricing and Payments',
                      body:
                          'Hosts set their own pricing for parking slots. Parkd charges a service fee on each booking. '
                          'Payments are processed through the Parkd platform and are subject to our payment terms. '
                          'Hosts are responsible for any applicable taxes on earnings from their listings.',
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    AppTermsNumberedSection(
                      number: '5',
                      title: 'Cancellations and Refunds',
                      body:
                          'Hosts must honour confirmed bookings. Repeated cancellations may result in listing suspension. '
                          'Refund eligibility for drivers is determined by Parkd\'s cancellation policy, '
                          'which may vary depending on how far in advance the cancellation is made.',
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    AppTermsNumberedSection(
                      number: '6',
                      title: 'Privacy and Data',
                      body:
                          'By using Parkd, you agree to our Privacy Policy. We collect and use your information '
                          'to operate and improve the platform. Your personal data will not be sold to third parties. '
                          'Location data is used only for parking bookings.',
                    ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            AppSurfaceFooterPad(
              child: Column(
                children: [
                  AppTermsAgreementCheckboxRow(
                    value: _agreed,
                    onChanged: _publishing
                        ? (_) {}
                        : (v) => setState(() => _agreed = v),
                    label: 'I agree to the Parkd Terms and Conditions',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Publish',
                    loading: _publishing,
                    onPressed: _agreed && !_publishing ? _publish : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
