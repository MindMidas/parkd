import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// True when a and b fall on the same calendar day in local time.
bool chatMessageSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String formatChatDayDividerLabel(DateTime at) {
  final d = at.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(d.year, d.month, d.day);
  if (messageDay == today) return 'Today';
  if (messageDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  if (d.year != now.year) {
    return DateFormat('EEE, MMM d, y').format(d);
  }
  return DateFormat('EEE, MMM d').format(d);
}

// Centered pill between messages when the calendar day changes.
class AppChatDayDivider extends StatelessWidget {
  const AppChatDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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

// One chat line (mine vs theirs)
class AppChatMessageBubble extends StatelessWidget {
  const AppChatMessageBubble({
    super.key,
    required this.senderName,
    required this.message,
    required this.isMine,
    this.showSenderHeader = true,
  });

  final String senderName;
  final String message;
  final bool isMine;

  // When false, hides the name row (use for consecutive messages from the same sender).
  final bool showSenderHeader;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSenderHeader) ...[
              Text(
                senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: isMine ? TextAlign.end : TextAlign.start,
                style: AppTypography.captionStrong
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Container(
              constraints: const BoxConstraints(maxWidth: 260),
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
      ),
    );
  }
}
