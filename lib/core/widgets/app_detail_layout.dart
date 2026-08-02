// Detail pages: scroll body, host card, hero image. README.md
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/scroll_view_bottom_inset.dart';
import 'app_buttons.dart';
import 'app_page_route.dart';
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
    this.ratingLabel,
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
  final String? ratingLabel;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 56.0 : 64.0;
    final horizontalGap = compact ? AppSpacing.sm : AppSpacing.md;
    final cardPadding = compact
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          )
        : const EdgeInsets.all(AppSpacing.md);
    final actionText = actionLabel?.trim();
    final action =
        trailing ??
        ((actionText != null &&
                actionText.isNotEmpty &&
                onActionPressed != null)
            ? AppPrimaryButton(
                label: actionText,
                icon: actionIcon,
                onPressed: onActionPressed!,
                fullWidth: false,
              )
            : null);
    final rating = ratingLabel?.trim();

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
              if (rating != null && rating.isNotEmpty) ...[
                SizedBox(height: AppSpacing.xxs),
                Text(
                  rating,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: AppSpacing.sm), action],
      ],
    );

    final body = Padding(padding: cardPadding, child: row);

    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return AppDisplayTitledOutlineCard(title: trimmedTitle, child: body);
    }

    return AppDisplayOutlineCard(child: body);
  }
}

class AppDetailHeroImage extends StatelessWidget {
  const AppDetailHeroImage({
    super.key,
    required this.assetPath,
    this.height = 160,
    this.fullBleed = false,
    this.horizontalInset = AppSpacing.lg,
    this.enableFullscreen = false,
  });

  final String assetPath;
  final double height;
  final bool fullBleed;
  final double horizontalInset;
  final bool enableFullscreen;

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => _AppImageFullscreenView(assetPath: assetPath),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        assetPath,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: double.infinity,
            color: AppColors.secondaryBlue.withValues(alpha: 0.25),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.iconGrey,
              size: 40,
            ),
          );
        },
      ),
    );
    if (!enableFullscreen) return image;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: AppScrimIconLabelPill(
                icon: Icons.open_in_full_rounded,
                label: 'Expand',
                scrimColor: AppColors.scrimOnImage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!fullBleed) return _buildImage(context);

    final screenW = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: screenW,
        minWidth: screenW,
        maxHeight: height,
        minHeight: height,
        child: Transform.translate(
          offset: Offset(-horizontalInset, 0),
          child: SizedBox(
            width: screenW,
            height: height,
            child: _buildImage(context),
          ),
        ),
      ),
    );
  }
}

class _AppImageFullscreenView extends StatelessWidget {
  const _AppImageFullscreenView({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.overlayBackdrop,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.onOverlayMuted,
                      size: 56,
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
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.onPrimary,
                  ),
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

class AppDetailHeroNetworkImage extends StatelessWidget {
  const AppDetailHeroNetworkImage({
    super.key,
    required this.imageUrl,
    this.aspectRatio = appListingPhotoFrameAspectRatio,
    this.enableFullscreen = false,
  });

  final String imageUrl;
  final double aspectRatio;
  final bool enableFullscreen;

  void _openFullscreen(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) return;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => AppNetworkImageFullscreenScreen(imageUrl: url),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.secondaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.local_parking_rounded,
            size: 56,
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
          ),
        ),
      );
    }

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        key: ValueKey<String>(url),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.secondaryBlue.withValues(alpha: 0.15),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) => Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.secondaryBlue.withValues(alpha: 0.25),
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.iconGrey,
            size: 40,
          ),
        ),
      ),
    );

    final framed = AspectRatio(aspectRatio: aspectRatio, child: image);

    if (!enableFullscreen) return framed;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: image),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: AppScrimIconLabelPill(
                icon: Icons.open_in_full_rounded,
                label: 'Expand',
                scrimColor: AppColors.scrimOnImage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildImage(context);
}

// Full-screen zoomable network image (e.g. listing / reservation hero)
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.onPrimary,
                  ),
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
