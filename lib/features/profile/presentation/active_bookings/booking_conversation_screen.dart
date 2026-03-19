import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import 'booking_details_screen.dart';

class BookingConversationScreen extends StatelessWidget {
  const BookingConversationScreen({
    super.key,
    required this.guestName,
    required this.listingAddress,
  });

  final String guestName;
  final String listingAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: guestName,
        showBack: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingDetailsScreen(
                    guestName: guestName,
                    listingAddress: listingAddress,
                  ),
                ),
              );
            },
            child: Text(
              'View booking',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _MessageBubble(
                  senderName: guestName,
                  message: 'Hi! Is this spot available after 6 PM today?',
                  isMine: false,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _MessageBubble(
                  senderName: 'You',
                  message: 'Yes, it is available. You can book it now.',
                  isMine: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MessageBubble(
                  senderName: guestName,
                  message: 'Perfect, thanks! I will confirm shortly.',
                  isMine: false,
                ),
              ],
            ),
          ),
          const _MessageComposer(),
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

class _MessageComposer extends StatelessWidget {
  const _MessageComposer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.secondaryGrey),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.add_circle_rounded,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.send_rounded,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
