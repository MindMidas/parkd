import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = document == LegalDocument.privacy;
    final sections = isPrivacy ? _privacySections : _termsSections;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: isPrivacy ? 'Privacy notice' : 'Demo terms',
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + scrollViewBottomInset(context),
          ),
          children: [
            Text(
              isPrivacy
                  ? 'How the Parkd portfolio demo handles information'
                  : 'Conditions for using the Parkd portfolio demo',
              style: AppTypography.headline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Effective July 20, 2026 · This is a non-commercial software '
              'demonstration, not a live parking marketplace.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in sections) ...[
              Text(section.$1, style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(section.$2, style: AppTypography.bodyMuted),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  static const _privacySections = <(String, String)>[
    (
      'Use test information only',
      'Do not submit real addresses, payment information, private messages, or '
          'other sensitive personal data. Stripe is configured in test mode and '
          'test card numbers must be used.',
    ),
    (
      'Information processed',
      'The demo may process account identifiers, profile fields, approximate and '
          'listing locations, uploaded images, reservations, messages, reviews, '
          'reports, device/network metadata, and test-payment references.',
    ),
    (
      'Service providers',
      'Supabase provides authentication, database, storage, and server functions. '
          'Stripe provides test payment interfaces. Mapbox provides map rendering. '
          'Vercel serves the compiled web application.',
    ),
    (
      'Retention and deletion',
      'Demo accounts and associated test content are scheduled for deletion or '
          'anonymization within ${AppEnvironment.demoDataRetentionHours} hours. '
          'Users can also request immediate deletion from Account settings.',
    ),
    (
      'Location safety',
      'Exact private parking details are intended to be shown only to authorized '
          'participants after a reservation is confirmed. Public discovery uses '
          'reduced-precision location data.',
    ),
  ];

  static const _termsSections = <(String, String)>[
    (
      'Portfolio demonstration',
      'Parkd is presented only to demonstrate software design and engineering. '
          'Listings are not offers for real parking and reservations do not create '
          'a commercial agreement.',
    ),
    (
      'No live payments',
      'Only Stripe test mode is permitted. No charge, refund, transfer, payout, '
          'or financial entitlement is created by using the demo.',
    ),
    (
      'Acceptable use',
      'Do not upload unlawful, harmful, identifying, or confidential content; '
          'attempt to access another user’s data; automate abusive traffic; or '
          'interfere with the service.',
    ),
    (
      'Moderation',
      'Demo content may be reported, hidden, blocked, suspended, or removed to '
          'protect the project and its visitors.',
    ),
    (
      'Availability',
      'The demo is provided as-is and may be reset, changed, rate-limited, or '
          'taken offline at any time.',
    ),
  ];
}
