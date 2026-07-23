import 'package:flutter/material.dart';

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
        title: isPrivacy ? 'Privacy notice' : 'Terms of service',
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
                  ? 'How Parkd handles information'
                  : 'Conditions for using Parkd',
              style: AppTypography.headline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Effective July 21, 2026', style: AppTypography.bodyMuted),
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
      'Information processed',
      'Parkd may process account identifiers, profile fields, approximate and '
          'listing locations, uploaded images, reservations, messages, reviews, '
          'reports, device and network metadata, and payment references.',
    ),
    (
      'Service providers',
      'Supabase provides authentication, database, storage, and server functions. '
          'Stripe provides payment services. Mapbox provides map rendering. '
          'Cloudflare Turnstile helps protect public sign-up from automated abuse.',
    ),
    (
      'Retention and deletion',
      'Parkd retains information for as long as needed to provide the service, '
          'meet legal obligations, resolve disputes, and protect users. Account '
          'deletion can be requested from Account settings.',
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
      'Marketplace role',
      'Parkd helps drivers and hosts discover and arrange parking. Hosts are '
          'responsible for the accuracy, safety, legality, availability, and terms '
          'of their listings.',
    ),
    (
      'Reservations and payments',
      'Reservation prices and fees are shown before confirmation. Payments may be '
          'processed by Stripe. Cancellation, refund, payout, and dispute handling '
          'are subject to the policies presented during checkout.',
    ),
    (
      'Acceptable use',
      'Do not upload unlawful, harmful, identifying, or confidential content; '
          'attempt to access another user’s data; automate abusive traffic; or '
          'interfere with the service.',
    ),
    (
      'Moderation',
      'Content may be reported, hidden, blocked, suspended, or removed to '
          'protect the project and its visitors.',
    ),
    (
      'Availability',
      'Parkd may change, rate-limit, suspend, or discontinue features when needed '
          'for safety, maintenance, legal compliance, or service reliability.',
    ),
  ];
}
