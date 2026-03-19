import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class ReservationConversationScreen extends StatelessWidget {
  const ReservationConversationScreen({
    super.key,
    required this.hostName,
  });

  final String hostName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: hostName,
        showBack: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _MessageBubble(
                  senderName: hostName,
                  message: 'Hi, everything is set for your booking today.',
                  isMine: false,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _MessageBubble(
                  senderName: 'You',
                  message: 'Great, thank you! I will arrive around 3 PM.',
                  isMine: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MessageBubble(
                  senderName: hostName,
                  message: 'Perfect. Let me know if you need anything.',
                  isMine: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
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
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
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
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

