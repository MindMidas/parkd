import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_display_fields.dart';
import 'app_divider.dart';
import 'app_listing_photo_frame.dart';

enum AppMenuLeadingType { profile, parking }

enum AppMenuRightKind { chevron, icon, pillIcon, amount, none }

class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    super.key,
    required this.title,
    this.subtitle,
    this.tertiary,
    this.leading,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.showTopDivider = false,
    this.showBottomDivider = false,
    this.rightKind = AppMenuRightKind.chevron,
    this.rightIcon = Icons.keyboard_arrow_right_rounded,
    this.rightAmount,
    this.rightAmountPrefix = '',
    this.rightAmountColor,
    this.rightAmountStyle = AppMoneyStyle.bodyStrong,
    this.leadingType,
    this.leadingImageProvider,
  });

  final String title;
  final String? subtitle;
  final String? tertiary;
  final Widget? leading;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showTopDivider;
  final bool showBottomDivider;
  final AppMenuRightKind rightKind;
  final IconData rightIcon;
  final double? rightAmount;
  final String rightAmountPrefix;
  final Color? rightAmountColor;
  final AppMoneyStyle rightAmountStyle;
  final AppMenuLeadingType? leadingType;
  final ImageProvider? leadingImageProvider;

  Widget? _buildLeading() {
    if (leading != null) return leading;
    if (leadingIcon != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.secondaryGrey.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(leadingIcon, size: 22, color: AppColors.iconGrey),
        ),
      );
    }
    if (leadingType == null) return null;

    switch (leadingType!) {
      case AppMenuLeadingType.profile:
        return AppMenuProfileAvatar(imageProvider: leadingImageProvider);
      case AppMenuLeadingType.parking:
        return AppMenuParkingAvatar(imageProvider: leadingImageProvider);
    }
  }

  Widget? _buildTrailing() {
    if (trailing != null) return trailing;
    switch (rightKind) {
      case AppMenuRightKind.none:
        return null;
      case AppMenuRightKind.chevron:
        return Icon(rightIcon, size: 22, color: AppColors.iconGrey);
      case AppMenuRightKind.icon:
        return Icon(rightIcon, size: 22, color: AppColors.iconGrey);
      case AppMenuRightKind.pillIcon:
        return AppMenuPillIconButton(
          onPressed: onTap ?? () {},
          icon: rightIcon,
        );
      case AppMenuRightKind.amount:
        if (rightAmount == null) return null;
        return AppMoneyText(
          rightAmount!,
          prefix: rightAmountPrefix,
          style: rightAmountStyle,
          color: rightAmountColor,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailingWidget = _buildTrailing();
    final lead = _buildLeading();
    final hasMeta =
        (subtitle != null && subtitle!.isNotEmpty) ||
        (tertiary != null && tertiary!.isNotEmpty);

    return Column(
      children: [
        if (showTopDivider) const AppDividerWide(),
        ListTile(
          minLeadingWidth: lead != null ? 64 : null,
          minVerticalPadding: hasMeta ? 10 : 12,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 2,
          ),
          splashColor: AppInk.splashSoft,
          hoverColor: AppInk.hover,
          leading: lead,
          title: Text(
            title,
            style: AppTypography.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: hasMeta
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (tertiary != null && tertiary!.isNotEmpty) ...[
                        if (subtitle != null && subtitle!.isNotEmpty)
                          const SizedBox(height: 2),
                        Text(
                          tertiary!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.iconGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                )
              : null,
          trailing:
              rightKind == AppMenuRightKind.amount && trailingWidget != null
              ? SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailingWidget,
                  ),
                )
              : trailingWidget,
          onTap: onTap,
        ),
        if (showBottomDivider) const AppDividerWide(),
      ],
    );
  }
}

class AppMenuPillIconButton extends StatelessWidget {
  const AppMenuPillIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.width = 48,
    this.height = 40,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBlue,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: width,
          height: height,
          child: Icon(icon, color: AppColors.onPrimary, size: 20),
        ),
      ),
    );
  }
}

class AppMenuProfileAvatar extends StatelessWidget {
  const AppMenuProfileAvatar({
    super.key,
    required this.imageProvider,
    this.fallbackIcon = Icons.person_rounded,
    this.size = 52,
    this.hostListingSolidPlaceholder = false,
  });

  /// Solid blue circle used on listing cards when there is no host photo (40dp or 36dp compact)
  factory AppMenuProfileAvatar.hostListingPlaceholder({
    Key? key,
    bool compact = false,
    ImageProvider? imageProvider,
  }) {
    return AppMenuProfileAvatar(
      key: key,
      imageProvider: imageProvider,
      size: compact ? 36 : 40,
      hostListingSolidPlaceholder: true,
    );
  }

  final ImageProvider? imageProvider;
  final IconData fallbackIcon;
  final double size;

  final bool hostListingSolidPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (hostListingSolidPlaceholder) {
      final iconSize = size <= 36 ? 20.0 : 22.0;
      return SizedBox(
        width: size,
        height: size,
        child: Material(
          color: AppColors.secondaryBlue,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: imageProvider != null
              ? Image(
                  image: imageProvider!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                )
              : Icon(fallbackIcon, size: iconSize, color: AppColors.onPrimary),
        ),
      );
    }

    return Material(
      elevation: 0,
      color: AppColors.secondaryBlue.withValues(alpha: 0.35),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.secondaryGrey, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size,
        height: size,
        child: imageProvider != null
            ? Image(
                image: imageProvider!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              )
            : Icon(
                fallbackIcon,
                color: AppColors.primaryBlue,
                size: size * 0.45,
              ),
      ),
    );
  }
}

class AppMenuParkingAvatar extends StatelessWidget {
  const AppMenuParkingAvatar({
    super.key,
    required this.imageProvider,

    /// Height of the 4:3 thumbnail; width follows [appListingPhotoFrameAspectRatio]
    this.size = 48,
  });

  final ImageProvider? imageProvider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppRadius.sm);
    final h = size;
    final w = h * appListingPhotoFrameAspectRatio;
    return Material(
      color: AppColors.secondaryBlue.withValues(alpha: 0.35),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: const BorderSide(color: AppColors.secondaryGrey, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: w,
        height: h,
        child: imageProvider != null
            ? Image(image: imageProvider!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  'P',
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.primaryBlue,
                    fontSize: h * 0.4,
                  ),
                ),
              ),
      ),
    );
  }
}
