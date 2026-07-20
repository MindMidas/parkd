import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/notification_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(notificationBannersMutedProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'In-app alerts', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Notification events still appear in your inbox when banners are muted.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mute in-app banners'),
              subtitle: const Text('Hide pop-ups while Parkd is open.'),
              value: muted,
              activeThumbColor: AppColors.onPrimary,
              activeTrackColor: AppColors.primaryBlue,
              onChanged: ref
                  .read(notificationBannersMutedProvider.notifier)
                  .setMuted,
            ),
          ],
        ),
      ),
    );
  }
}
