import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/reviews_providers.dart';

// Leave a 1–5 star review for the other party on a completed reservation.
class LeaveReviewScreen extends ConsumerStatefulWidget {
  const LeaveReviewScreen({
    super.key,
    required this.reservationId,
    required this.revieweeId,
    required this.revieweeDisplayName,
  });

  final String reservationId;
  final String revieweeId;
  final String revieweeDisplayName;

  @override
  ConsumerState<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends ConsumerState<LeaveReviewScreen> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _saving = false;
  String? _actionError;
  bool _ratingError = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _actionError = null;
      _ratingError = false;
    });
    if (_rating < 1) {
      setState(() => _ratingError = true);
      return;
    }
    final uid = ref.read(currentSessionProvider)?.user.id;
    if (uid == null) {
      setState(() => _actionError = 'Sign in to leave a review.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(reviewsRepositoryProvider).submitReview(
            reservationId: widget.reservationId,
            reviewerId: uid,
            revieweeId: widget.revieweeId,
            rating: _rating,
            comment: _comment.text,
          );
      ref.invalidate(myReviewForReservationProvider(widget.reservationId));
      ref.invalidate(profileByUserIdProvider(widget.revieweeId));
      if (!mounted) return;
      AppMessenger.showSuccess(context, 'Thanks for your review.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError = 'Could not submit your review. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.revieweeDisplayName.trim().isEmpty
        ? 'this person'
        : widget.revieweeDisplayName.trim();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Leave a review', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'How was your experience with $name?',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _rating = i;
                                    _ratingError = false;
                                    _actionError = null;
                                  }),
                            iconSize: 36,
                            icon: Icon(
                              i <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                      ],
                    ),
                    if (_ratingError) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const AppFormErrorCaption('Please select a star rating.'),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Comment (optional)',
                      controller: _comment,
                      keyboardType: TextInputType.multiline,
                      enabled: !_saving,
                      onChanged: (_) {
                        if (_actionError != null) {
                          setState(() => _actionError = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_actionError != null) ...[
                    AppInlineError(
                      message: _actionError!,
                      onDismiss: () => setState(() => _actionError = null),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppPrimaryButton(
                    label: 'Submit review',
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
