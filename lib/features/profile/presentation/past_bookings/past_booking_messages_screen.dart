import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import 'past_booking_conversation_screen.dart';

class PastBookingMessagesScreen extends StatelessWidget {
  const PastBookingMessagesScreen({
    super.key,
    required this.listingAddress,
  });

  final String listingAddress;

  static const _dummyConversations = <_ConversationPreview>[
    _ConversationPreview(
      name: 'Sophie Carter',
      lastMessage: 'Thanks again for the spot yesterday!',
    ),
    _ConversationPreview(
      name: 'Liam Johnson',
      lastMessage: 'Everything went smoothly. Appreciate it.',
    ),
    _ConversationPreview(
      name: 'Ava Thompson',
      lastMessage: 'I may book this location again next week.',
    ),
    _ConversationPreview(
      name: 'Noah Wilson',
      lastMessage: 'Great host, thank you!',
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PastBookingConversationScreen(
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
