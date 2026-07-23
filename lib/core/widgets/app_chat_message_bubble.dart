import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// One chat line (mine vs theirs)
class AppChatMessageBubble extends StatelessWidget {
  const AppChatMessageBubble({
    super.key,
    required this.senderName,
    required this.message,
    required this.isMine,
    this.onLongPress,
  });

  final String senderName;
  final String message;
  final bool isMine;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.card),
      topRight: const Radius.circular(AppRadius.card),
      bottomLeft: Radius.circular(isMine ? AppRadius.card : AppRadius.sm),
      bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.card),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: AppTypography.captionStrong.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            button: onLongPress != null,
            hint: onLongPress == null ? null : 'Long press to report message',
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isMine
                      ? AppColors.primaryBlue
                      : AppColors.secondaryBlue,
                  borderRadius: radius,
                ),
                child: Text(
                  message,
                  style: AppTypography.body.copyWith(
                    color: isMine ? AppColors.onPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
