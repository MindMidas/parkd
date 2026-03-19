import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../active_bookings/booking_details_screen.dart';

class PastBookingConversationScreen extends StatelessWidget {
  const PastBookingConversationScreen({
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
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _MessageBubble(
            senderName: guestName,
            message: 'Thanks again for the spot yesterday!',
            isMine: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _MessageBubble(
            senderName: 'You',
            message: 'Anytime. Glad it worked well for you.',
            isMine: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MessageBubble(
            senderName: guestName,
            message: 'I may book this location again next week.',
            isMine: false,
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
