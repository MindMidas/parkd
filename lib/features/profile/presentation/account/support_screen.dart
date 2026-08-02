import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

// Support and legal references. No unowned domain/email is advertised.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static final Uri _projectProfile = Uri.parse(
    'https://github.com/MindMidas/parkd',
  );

  String? _actionError;

  Future<void> _openRepository() async {
    setState(() => _actionError = null);
    final ok = await launchUrl(
      _projectProfile,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _actionError = 'Could not open the project repository.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Help & support', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'For support, issue reporting, and project information, use the '
                'Parkd repository below.',
                style: AppTypography.bodyMuted,
              ),
              if (_actionError != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInlineError(
                  message: _actionError!,
                  onDismiss: () => setState(() => _actionError = null),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: 'Open project repository',
                onPressed: _openRepository,
              ),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: 'Privacy notice',
                onPressed: () => context.push('/legal/privacy'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                label: 'Terms of service',
                onPressed: () => context.push('/legal/terms'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
