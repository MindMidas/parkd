import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/main_shell_tab_provider.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../map/presentation/main_tab.dart';
import '../../providers/profile_providers.dart';
import '../../providers/notifications_providers.dart';
import '../settings/all_cards_screen.dart';
import '../settings/edit_profile_screen.dart';
import '../settings/notification_preferences_screen.dart';
import '../settings/security/security_screen.dart';
import 'notifications_screen.dart';
import 'support_screen.dart';

// Account tab — profile header, grouped tiles, sign out when you're done
class AccountTabScreen extends ConsumerWidget {
  const AccountTabScreen({super.key});

  static Future<void> _confirmAndSignOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Sign out?',
        message: 'You will need to sign in again to use your account.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Sign out',
        confirmDestructive: true,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    // Read before any await: sign-out can unmount this widget; ref is invalid after that
    final authRepo = ref.read(authRepositoryProvider);
    final shellTab = ref.read(mainShellTabIndexProvider.notifier);
    try {
      await authRepo.signOut();
    } on Exception catch (_) {}
    shellTab.setTab(MainTab.map);
    if (!context.mounted) {
      return;
    }
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final notificationCounts = ref.watch(myNotificationHubCountsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Account',
        showBack: false,
        centerTitle: true,
        backgroundColor: kAppHubTitleBar,
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHubMenuIntro(
                lead:
                    'Update your profile, manage payments, and set your '
                    'preferences.',
                header: _AccountHeader(profileAsync: profileAsync),
              ),
              AppHubMenuSection(
                title: 'Profile',
                topSpacing: AppSpacing.sm,
                children: [
                  AppNavTile(
                    showDividerAbove: true,
                    icon: Icons.account_circle_outlined,
                    label: 'Personal Information',
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  AppNavTile(
                    showDividerAbove: true,
                    showDividerBelow: true,
                    icon: Icons.credit_card_outlined,
                    label: 'Payment Preferences',
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const AllCardsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              AppHubMenuSection(
                title: 'Preferences',
                children: [
                  AppNavTile(
                    showDividerAbove: true,
                    icon: Icons.security_rounded,
                    label: 'Security',
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const SecuritySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  AppNavTile(
                    showDividerAbove: true,
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    badgeCount: notificationCounts.total,
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  AppNavTile(
                    showDividerAbove: true,
                    showDividerBelow: true,
                    icon: Icons.notifications_active_outlined,
                    label: 'In-app alerts',
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const NotificationPreferencesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              AppHubMenuSection(
                title: 'Support',
                children: [
                  AppNavTile(
                    showDividerAbove: true,
                    showDividerBelow: true,
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    AppPrimaryButton(
                      label: 'Sign out',
                      icon: Icons.logout_rounded,
                      onPressed: () => _confirmAndSignOut(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _DeleteAccountButton(),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg + scrollViewBottomInset(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends ConsumerStatefulWidget {
  const _DeleteAccountButton();

  @override
  ConsumerState<_DeleteAccountButton> createState() =>
      _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<_DeleteAccountButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: 'Delete account?',
        message:
            'Your profile and account content will be removed or anonymized. '
            'This cannot be undone.',
        cancelLabel: 'Keep',
        confirmLabel: 'Delete',
        confirmDestructive: true,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final shellTab = ref.read(mainShellTabIndexProvider.notifier);
    try {
      await ref.read(authRepositoryProvider).deleteCurrentAccount();
      shellTab.setTab(MainTab.map);
      if (mounted) context.go('/auth');
    } on Exception catch (_) {
      if (mounted) {
        AppMessenger.showError(
          context,
          'Account deletion could not be completed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      label: 'Delete account',
      icon: Icons.delete_outline_rounded,
      destructive: true,
      loading: _busy,
      onPressed: _busy ? null : _delete,
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.profileAsync});

  final AsyncValue<Profile?> profileAsync;

  @override
  Widget build(BuildContext context) {
    return profileAsync.when(
      data: (profile) {
        final name = profile?.displayName ?? 'User';
        final handle = profile?.username != null
            ? '@${profile!.username}'
            : null;
        return Column(
          children: [
            AppMenuProfileAvatar(
              imageProvider: profileAvatarImageProvider(profile),
              size: 96,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(name, style: AppTypography.profileDisplayName),
            if (handle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(handle, style: AppTypography.caption),
            ],
          ],
        );
      },
      loading: () => Column(
        children: [
          const SizedBox(
            width: 96,
            height: 96,
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Loading…', style: AppTypography.profileDisplayName),
        ],
      ),
      error: (_, _) => Column(
        children: [
          const AppMenuProfileAvatar(imageProvider: null, size: 96),
          const SizedBox(height: AppSpacing.md),
          Text('User', style: AppTypography.profileDisplayName),
        ],
      ),
    );
  }
}
