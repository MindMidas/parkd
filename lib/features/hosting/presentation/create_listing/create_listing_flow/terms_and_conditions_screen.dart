import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../map/presentation/home_map_screen.dart';
import '../../../../map/presentation/main_tab.dart';
import '../../manage_listings/edit/confirmation_success_screen.dart';
import '../create_listing_draft.dart';
import '../create_listing_publish.dart';

// Scroll the legal summary, then checkbox + transactional publish.
class TermsAndConditionsScreen extends ConsumerStatefulWidget {
  const TermsAndConditionsScreen({
    super.key,
    required this.draft,
    this.onPublish,
    this.currentStep,
    this.totalSteps,
  });

  final CreateListingDraft draft;

  // Optional host callback after the user leaves the success screen
  final VoidCallback? onPublish;

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
  String? _actionError;
  bool _termsError = false;

  Future<void> _publish() async {
    setState(() {
      _actionError = null;
      _termsError = false;
    });
    if (!_agreed) {
      setState(() => _termsError = true);
      return;
    }
    if (_publishing || widget.draft.publishedSuccessfully) return;
    if (!widget.draft.isCompleteForPublish) {
      setState(
        () => _actionError =
            'Something is missing from your listing. Go back and check each step.',
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      await CreateListingPublish.submit(ref, widget.draft);
      if (!mounted) return;
      _openPublishedSuccess();
    } catch (e) {
      if (!mounted) return;
      if (widget.draft.publishedSuccessfully) {
        _openPublishedSuccess();
        return;
      }
      setState(
        () => _actionError = CreateListingPublish.describePublishError(e),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _openPublishedSuccess() {
    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final onPublish = widget.onPublish;
    navigator.pushReplacement(
      AppPageRoute<void>(
        builder: (_) => ConfirmationSuccessScreen(
          title: 'Listing published',
          message:
              'Your parking spot is now live. Drivers can find and book it on Parkd.',
          buttonLabel: 'Go to home',
          onClose: () {
            if (onPublish != null) {
              onPublish();
            } else {
              rootNavigator.pushAndRemoveUntil(
                AppPageRoute<void>(
                  builder: (_) => const HomeMapScreen(
                    initialIndex: MainTab.map,
                    hasTabInRoute: true,
                  ),
                ),
                (route) => false,
              );
            }
          },
          popsOnClose: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useStepBar = widget.currentStep != null && widget.totalSteps != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: useStepBar
          ? AppStepTopBar(
              title: 'Terms and conditions',
              currentStep: widget.currentStep!,
              totalSteps: widget.totalSteps!,
            )
          : const AppTopBar(title: 'Terms and conditions', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppHubMenuIntro(
                      lead:
                          'Please read and agree before publishing your '
                          'listing.',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Terms and Conditions',
                            style: AppTypography.overline,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Please read the following terms carefully before publishing your parking listing on Parkd. '
                            'By creating and publishing a listing, you agree to comply with these terms.',
                            style: AppTypography.caption,
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          AppTermsNumberedSection(
                            number: '1',
                            title: 'Accurate Listing Information',
                            body:
                                'Hosts are responsible for ensuring that all listing information is accurate and up to date. '
                                'This includes the parking location, availability, pricing, photos, and any additional details provided. '
                                'Misleading or inaccurate listings may be removed by Parkd at any time.',
                          ),

                          const SizedBox(height: AppSpacing.md),
                          AppTermsNumberedSection(
                            number: '2',
                            title: 'Legal Use of Parking Space',
                            body:
                                'By listing a parking space, you confirm that you have the legal right to rent or share the parking spot. '
                                'The space must not violate local laws, building policies, or homeowner association regulations. '
                                'Parkd is not responsible for verifying ownership or authorization of the parking location.',
                          ),

                          const SizedBox(height: AppSpacing.md),
                          AppTermsNumberedSection(
                            number: '3',
                            title: 'Safety and Accessibility',
                            body:
                                'Hosts agree to provide parking spaces that are reasonably safe and accessible for drivers. '
                                'Any hazards, restrictions, or access instructions must be clearly communicated in the listing description. '
                                'Parkd is not liable for accidents or damages resulting from unsafe parking environments.',
                          ),

                          const SizedBox(height: AppSpacing.md),
                          AppTermsNumberedSection(
                            number: '4',
                            title: 'Pricing and Payments',
                            body:
                                'Hosts set their own pricing for parking slots. Parkd charges a service fee on each booking. '
                                'Payments are processed through the Parkd platform and are subject to our payment terms. '
                                'Hosts are responsible for any applicable taxes on earnings.',
                          ),

                          const SizedBox(height: AppSpacing.md),
                          AppTermsNumberedSection(
                            number: '5',
                            title: 'Cancellations and refunds',
                            body:
                                'Hosts must honour confirmed bookings. Repeated cancellations may '
                                'result in listing suspension. Drivers get a full refund when they '
                                'cancel more than 2 hours before start; later cancellations free the '
                                'spot but are not refunded.',
                          ),

                          const SizedBox(height: AppSpacing.md),
                          AppTermsNumberedSection(
                            number: '6',
                            title: 'Privacy and Data',
                            body:
                                'By using Parkd, you agree to our Privacy Policy. We collect and use your information '
                                'to operate and improve the platform. Your personal data will not be sold to third parties. '
                                'Location data is used solely to facilitate parking bookings.',
                          ),

                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AppStickyFooter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_actionError != null) ...[
                    AppInlineError(
                      message: _actionError!,
                      onDismiss: () => setState(() => _actionError = null),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppTermsAgreementCheckboxRow(
                    value: _agreed,
                    onChanged: _publishing
                        ? (_) {}
                        : (v) => setState(() {
                            _agreed = v;
                            if (v) _termsError = false;
                          }),
                    label: 'I agree to the Parkd Terms and Conditions',
                  ),
                  if (_termsError) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const AppFormErrorCaption(
                      'Please accept Terms and Conditions to continue.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Publish',
                    loading: _publishing,
                    onPressed: _publishing ? null : _publish,
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
