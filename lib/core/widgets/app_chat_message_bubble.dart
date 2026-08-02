import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// One chat line (mine vs theirs). Consecutive messages from the same sender
// keep square inner corners so a run reads as a single block.
class AppChatMessageBubble extends StatelessWidget {
  const AppChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isTail = true,
    this.onLongPress,
  });

  final String message;
  final bool isMine;
  final bool isTail;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    const round = Radius.circular(AppRadius.card);
    const tail = Radius.circular(AppRadius.sm);
    final radius = BorderRadius.only(
      topLeft: round,
      topRight: round,
      bottomLeft: isMine || !isTail ? round : tail,
      bottomRight: isMine && isTail ? tail : round,
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        button: onLongPress != null,
        hint: onLongPress == null ? null : 'Long press to report message',
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primaryBlue : AppColors.secondaryBlue,
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
    );
  }
}

// Centered day / time separator between message groups.
class AppChatTimestampDivider extends StatelessWidget {
  const AppChatTimestampDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.md,
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
