import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/main_shell_tab_provider.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../app/main_tab.dart';
import '../../providers/profile_providers.dart';
import '../settings/all_cards_screen.dart';
import '../settings/edit_profile_screen.dart';
import '../settings/security/security_screen.dart';
import 'support_screen.dart';

// account tab, user pfp, the tiles, sign out when done
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
        message:
            'You will need to sign in again to use your account.',
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Center(
                  child: Text(
                    'Account',
                    style: AppTypography.hubTitle,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AccountHeader(profileAsync: profileAsync),
              const SizedBox(height: AppSpacing.lg),
              AppSettingsNavTile(
                icon: Icons.account_circle_outlined,
                label: 'Personal Information',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                },
              ),
              AppSettingsNavTile(
                icon: Icons.credit_card_outlined,
                label: 'Payment Preferences',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AllCardsScreen(),
                    ),
                  );
                },
              ),
              AppSettingsNavTile(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () {
                  // TODO: navigate to Notifications
                },
              ),
              AppSettingsNavTile(
                icon: Icons.security_rounded,
                label: 'Security',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SecuritySettingsScreen(),
                    ),
                  );
                },
              ),
              AppSettingsNavTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                showDividerBelow: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupportScreen(),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: AppPrimaryButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  onPressed: () => _confirmAndSignOut(context, ref),
                ),
              ),
              SizedBox(
                height: AppSpacing.lg + scrollViewBottomInset(context),
              ),
            ],
          ),
        ),
      ),
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
        final handle =
            profile?.username != null ? '@${profile!.username}' : null;
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
          const AppMenuProfileAvatar(
            imageProvider: null,
            size: 96,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('User', style: AppTypography.profileDisplayName),
        ],
      ),
    );
  }
}
