import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static final Uri _supportMailto = Uri.parse(
    'mailto:support@parkd.app?subject=${Uri.encodeComponent('Parkd support')}',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Help & support',
        showBack: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Questions about bookings, hosting, or your account? Send us an email and we will get back to you.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: 'Email support',
                onPressed: () async {
                  final ok = await launchUrl(
                    _supportMailto,
                    mode: LaunchMode.platformDefault,
                  );
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open your email app.'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
