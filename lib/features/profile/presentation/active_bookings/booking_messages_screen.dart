import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import 'booking_conversation_screen.dart';

class BookingMessagesScreen extends StatelessWidget {
  const BookingMessagesScreen({
    super.key,
    required this.listingAddress,
  });

  final String listingAddress;

  static const _dummyConversations = <_ConversationPreview>[
    _ConversationPreview(
      name: 'Sophie Carter',
      lastMessage: 'Hi! Is this spot available after 6 PM today?',
    ),
    _ConversationPreview(
      name: 'Liam Johnson',
      lastMessage: 'Thanks, I am on my way now.',
    ),
    _ConversationPreview(
      name: 'Ava Thompson',
      lastMessage: 'Could I extend my booking by one hour?',
    ),
    _ConversationPreview(
      name: 'Noah Wilson',
      lastMessage: 'I parked successfully. Thank you!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: listingAddress,
        showBack: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: const AppSearchField(),
          ),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              itemCount: _dummyConversations.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final conversation = _dummyConversations[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondaryBlue,
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  title: Text(
                    conversation.name,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.mail_rounded,
                    color: AppColors.primaryBlue,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingConversationScreen(
                          guestName: conversation.name,
                          listingAddress: listingAddress,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPreview {
  const _ConversationPreview({
    required this.name,
    required this.lastMessage,
  });

  final String name;
  final String lastMessage;
}
