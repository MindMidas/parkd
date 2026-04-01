// Shared detail scaffold: scroll area, header, hero.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/scroll_view_bottom_inset.dart';
import 'app_buttons.dart';
import 'app_notification_badge.dart';
import 'app_display_fields.dart';
import 'app_listing_photo_frame.dart';
import 'app_listing_photo_spot_overlay.dart';
import 'app_menu_row.dart';

class AppDetailScrollBody extends StatelessWidget {
  const AppDetailScrollBody({
    super.key,
    required this.child,
    this.bottomScrollPadding = AppSpacing.lg,
  });

  final Widget child;
  final double bottomScrollPadding;

  @override
  Widget build(BuildContext context) {
    final bottom = scrollViewBottomInset(context);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          bottomScrollPadding + bottom,
        ),
        child: child,
      ),
    );
  }
}

class AppPersonInlineCard extends StatelessWidget {
  const AppPersonInlineCard({
    super.key,
    required this.displayName,
    required this.handle,
    this.avatarImageProvider,
    this.trailing,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon = Icons.mail_outline_rounded,
    this.title,
    this.compact = false,
    this.actionBadgeCount = 0,
  });

  final String displayName;
  final String handle;
  final ImageProvider? avatarImageProvider;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData actionIcon;
  final String? title;
  final bool compact;
  final int actionBadgeCount;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 56.0 : 64.0;
    final horizontalGap = compact ? AppSpacing.sm : AppSpacing.md;
    final cardPadding = compact
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs)
        : const EdgeInsets.all(AppSpacing.md);
    final actionText = actionLabel?.trim();
    final Widget? rawAction = trailing ??
        ((actionText != null && actionText.isNotEmpty && onActionPressed != null)
            ? AppPrimaryButton(
                label: actionText,
                icon: actionIcon,
                onPressed: onActionPressed!,
                fullWidth: false,
              )
            : null);
    final action = rawAction == null
        ? null
        : actionBadgeCount > 0
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  rawAction,
                  Positioned(
                    right: -4,
                    top: -6,
                    child: AppNotificationBadge(
                      count: actionBadgeCount,
                      compact: true,
                    ),
                  ),
                ],
              )
            : rawAction;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppMenuProfileAvatar(
          imageProvider: avatarImageProvider,
          size: avatarSize,
        ),
        SizedBox(width: horizontalGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong,
              ),
              SizedBox(height: AppSpacing.xxs),
              Text(
                handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: AppSpacing.sm),
          action,
        ],
      ],
    );

    final body = Padding(
      padding: cardPadding,
      child: row,
    );

    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return AppDisplayTitledOutlineCard(
        title: trimmedTitle,
        child: body,
      );
    }

    return AppDisplayOutlineCard(child: body);
  }
}

// Fullscreen pinch-zoom for a listing or trip photo
class AppNetworkImageFullscreenScreen extends StatelessWidget {
  const AppNetworkImageFullscreenScreen({
    super.key,
    required this.imageUrl,
    this.markerFraction,
  });

  final String imageUrl;

  final Offset? markerFraction;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return Scaffold(
      backgroundColor: AppColors.overlayBackdrop,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: url.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.onOverlayMuted,
                          size: 56,
                        ),
                      )
                    : markerFraction == null
                        ? Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.onOverlayMuted,
                                size: 56,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final maxW = constraints.maxWidth;
                              final maxH = constraints.maxHeight;
                              final ar = appListingPhotoFrameAspectRatio;
                              late final double boxW;
                              late final double boxH;
                              if (maxW / maxH > ar) {
                                boxH = maxH;
                                boxW = boxH * ar;
                              } else {
                                boxW = maxW;
                                boxH = boxW / ar;
                              }
                              return Center(
                                child: SizedBox(
                                  width: boxW,
                                  height: boxH,
                                  child: AppListingPhotoSpotOverlay(
                                    markerFraction: markerFraction,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return ColoredBox(
                                          color: AppColors.overlayBackdrop,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: AppColors.onOverlayMuted,
                                          size: 56,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Material(
                color: AppColors.overlayControlDim,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.onPrimary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
