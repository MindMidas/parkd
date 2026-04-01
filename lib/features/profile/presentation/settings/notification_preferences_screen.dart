import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/notification_popup_muted_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(notificationPopupsMutedProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Notification preferences',
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Turn off banner pop-ups when new notifications arrive.',
                style: AppTypography.bodyMuted,
              ),
              value: muted,
              activeThumbColor: AppColors.onPrimary,
              activeTrackColor: AppColors.primaryBlue,
              onChanged: (v) {
                ref.read(notificationPopupsMutedProvider.notifier).setMuted(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
