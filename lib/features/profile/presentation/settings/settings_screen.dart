import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/profile_providers.dart';
import '../../../home/presentation/home_map_screen.dart';
import 'all_cards_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Settings',
        showBack: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          // --- Avatar + name ---
          _SettingsHeader(profileAsync: profileAsync),
          const SizedBox(height: AppSpacing.xl),
          // --- Menu items ---
          _SettingsItem(
            icon: Icons.account_circle_outlined,
            label: 'Personal Information',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            },
          ),
          _SettingsItem(
            icon: Icons.credit_card_outlined,
            label: 'Payment Preferences',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AllCardsScreen(),
                ),
              );
            },
          ),
          _SettingsItem(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            showBottomBorder: true,
            onTap: () {
              // TODO: navigate to Notifications
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeMapScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header with avatar + verified badge + name + handle
// ---------------------------------------------------------------------------

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.profileAsync});

  final AsyncValue<Profile?> profileAsync;

  @override
  Widget build(BuildContext context) {
    return profileAsync.when(
      data: (profile) {
        final name = profile?.displayName ?? 'Lucas Scott';
        final handle =
            profile?.username != null ? '@${profile!.username}' : '@lucasscott3';
        return _buildContent(name, handle);
      },
      loading: () => _buildContent('Loading…', null),
      error: (_, _) => _buildContent('Lucas Scott', '@lucasscott3'),
    );
  }

  Widget _buildContent(String name, String? handle) {
    return Column(
      children: [
        // Avatar with verified badge
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(name, style: AppTypography.title),
        if (handle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(handle, style: AppTypography.caption),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings menu item with leading icon
// ---------------------------------------------------------------------------

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.showBottomBorder = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppDivider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minVerticalPadding: 14,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            icon,
            size: 22,
            color: AppColors.iconGrey,
          ),
          title: Text(label, style: AppTypography.body),
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.iconGrey,
          ),
          onTap: onTap,
        ),
        if (showBottomBorder) const AppDivider(),
      ],
    );
  }
}
