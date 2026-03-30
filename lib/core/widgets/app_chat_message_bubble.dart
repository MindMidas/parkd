import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// One chat line (mine vs theirs)
class AppChatMessageBubble extends StatelessWidget {
  const AppChatMessageBubble({
    super.key,
    required this.senderName,
    required this.message,
    required this.isMine,
  });

  final String senderName;
  final String message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style:
                AppTypography.captionStrong.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primaryBlue : AppColors.secondaryBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message,
              style: AppTypography.body.copyWith(
                color: isMine ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
