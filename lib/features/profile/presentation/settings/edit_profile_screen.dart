import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/profile_providers.dart';
import '../../../home/presentation/home_map_screen.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Edit Profile',
        showBack: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            // --- Avatar + name ---
            _EditProfileHeader(profileAsync: profileAsync),
            const SizedBox(height: AppSpacing.xl),
            // --- Full Name ---
            _ProfileField(
              label: 'Full Name',
              icon: Icons.account_circle_outlined,
              value: 'Lucas Scott',
            ),
            // --- Email Address ---
            _ProfileField(
              label: 'Email Address',
              icon: Icons.email_outlined,
              value: 'lucasscott@gmail.com',
            ),
            // --- Phone Number ---
            _ProfileField(
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              value: '+000 00 00 000',
            ),
            // --- Birth Date ---
            const _BirthDateField(
              day: '28',
              month: 'September',
              year: '2000',
            ),
          ],
        ),
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
// Header with avatar + edit badge + name + handle
// ---------------------------------------------------------------------------

class _EditProfileHeader extends StatelessWidget {
  const _EditProfileHeader({required this.profileAsync});

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
    return Center(
      child: Column(
        children: [
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile field row (label + icon + value + divider)
// ---------------------------------------------------------------------------

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.iconGrey),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(value, style: AppTypography.body),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppDivider(),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Birth date field with day / month / year columns
// ---------------------------------------------------------------------------

class _BirthDateField extends StatelessWidget {
  const _BirthDateField({
    required this.day,
    required this.month,
    required this.year,
  });

  final String day;
  final String month;
  final String year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Birth Date',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day, style: AppTypography.body),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(month, style: AppTypography.body),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(year, style: AppTypography.body),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
