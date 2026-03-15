import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/profile_providers.dart';
import '../listings_menu/listings_menu_screen.dart';

class ProfileMenuScreen extends ConsumerWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                  'Profile',
                  style: AppTypography.title,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProfileHeader(profileAsync: profileAsync),
            const SizedBox(height: AppSpacing.lg),
            AppListItem(
              label: 'Listings',
              showTopBorder: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ListingsMenuScreen(),
                  ),
                );
              },
            ),
            const AppListItem(
              label: 'Reservations',
              showTopBorder: true,
            ),
            const AppListItem(
              label: 'Settings',
              showTopBorder: true,
              showBottomBorder: true,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profileAsync});

  final AsyncValue<Profile?> profileAsync;

  @override
  Widget build(BuildContext context) {
    return profileAsync.when(
      data: (profile) {
        final name = profile?.displayName ?? 'User';
        final handle = profile?.username != null ? '@${profile!.username}' : null;
        return Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.secondaryBlue,
                borderRadius: BorderRadius.circular(48),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 56,
                color: Colors.white,
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
      },
      loading: () => Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.secondaryBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(48),
            ),
            child: const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Loading…', style: AppTypography.title),
        ],
      ),
      error: (e, st) => Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.secondaryBlue,
              borderRadius: BorderRadius.circular(48),
            ),
            child: const Icon(Icons.person_rounded, size: 56, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('User', style: AppTypography.title),
        ],
      ),
    );
  }
}

