import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/theme/app_typography.dart';
import '../../../../../../core/widgets/widgets.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key, required this.onPublish});

  final VoidCallback onPublish;

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms and Conditions',
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
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

                    // Header
                    Text(
                      'Please read and agree before publishing your listing',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),

                    // Terms label
                    Text(
                      'Terms and Conditions',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Terms body
                    Text(
                      'Please read the following terms carefully before publishing your parking listing on Parkd. '
                      'By creating and publishing a listing, you agree to comply with these terms.',
                      style: AppTypography.caption,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    _TermsSection(
                      number: '1',
                      title: 'Accurate Listing Information',
                      body:
                          'Hosts are responsible for ensuring that all listing information is accurate and up to date. '
                          'This includes the parking location, availability, pricing, photos, and any additional details provided. '
                          'Misleading or inaccurate listings may be removed by Parkd at any time.',
                    ),

                    _TermsSection(
                      number: '2',
                      title: 'Legal Use of Parking Space',
                      body:
                          'By listing a parking space, you confirm that you have the legal right to rent or share the parking spot. '
                          'The space must not violate local laws, building policies, or homeowner association regulations. '
                          'Parkd is not responsible for verifying ownership or authorization of the parking location.',
                    ),

                    _TermsSection(
                      number: '3',
                      title: 'Safety and Accessibility',
                      body:
                          'Hosts agree to provide parking spaces that are reasonably safe and accessible for drivers. '
                          'Any hazards, restrictions, or access instructions must be clearly communicated in the listing description. '
                          'Parkd is not liable for accidents or damages resulting from unsafe parking environments.',
                    ),

                    _TermsSection(
                      number: '4',
                      title: 'Pricing and Payments',
                      body:
                          'Hosts set their own pricing for parking slots. Parkd charges a service fee on each booking. '
                          'Payments are processed through the Parkd platform and are subject to our payment terms. '
                          'Hosts are responsible for any applicable taxes on earnings from their listings.',
                    ),

                    _TermsSection(
                      number: '5',
                      title: 'Cancellations and Refunds',
                      body:
                          'Hosts must honour confirmed bookings. Repeated cancellations may result in listing suspension. '
                          'Refund eligibility for drivers is determined by Parkd\'s cancellation policy, '
                          'which may vary depending on how far in advance the cancellation is made.',
                    ),

                    _TermsSection(
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
            ),

            // Agree checkbox + publish button
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                          activeColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Parkd Terms and Conditions',
                            style: AppTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Publish',
                    onPressed: _agreed ? widget.onPublish : null,
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

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $title',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
