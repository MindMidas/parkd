import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/active_trip_chat_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/chat_timeline.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../moderation/presentation/moderation_actions.dart';
import '../../profile/providers/notifications_providers.dart';
import '../providers/reservations_providers.dart';

// Live chat for one reservation (host or driver). Creates thread on first open if needed
class TripConversationScreen extends ConsumerStatefulWidget {
  const TripConversationScreen({
    super.key,
    required this.reservationId,
    this.initialConversationId,
    required this.peerDisplayName,
    required this.peerUserId,
    this.viewTripLabel,
    this.onViewTrip,
  });

  final String reservationId;
  final String? initialConversationId;
  final String peerDisplayName;
  final String peerUserId;

  final String? viewTripLabel;
  final VoidCallback? onViewTrip;

  @override
  ConsumerState<TripConversationScreen> createState() =>
      _TripConversationScreenState();
}

class _TripConversationScreenState
    extends ConsumerState<TripConversationScreen> {
  final _textController = TextEditingController();
  late final ActiveTripChatNotifier _activeTripChat;
  String? _conversationId;
  bool _ensuring = false;
  bool _sending = false;
  Object? _ensureError;
  String? _actionError;

  List<Widget> get _viewTripActions {
    final label = widget.viewTripLabel?.trim();
    final onTap = widget.onViewTrip;
    if (label == null || label.isEmpty || onTap == null) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: AppPrimaryButton(
          label: label,
          fullWidth: false,
          compact: true,
          onPressed: onTap,
          applyTitleCase: false,
        ),
      ),
    ];
  }

  List<Widget> get _appBarActions => [
    ..._viewTripActions,
    AppOverflowMenuButton(
      tooltip: 'Safety options',
      onSelected: _onSafetyAction,
      items: const [
        AppOverflowMenuItem(
          value: 'report',
          label: 'Report user',
          icon: Icons.flag_outlined,
        ),
        AppOverflowMenuItem(
          value: 'block',
          label: 'Block user',
          icon: Icons.block_rounded,
          destructive: true,
        ),
      ],
    ),
  ];

  Future<void> _onSafetyAction(String action) async {
    if (action == 'report') {
      await showParkdReportDialog(
        context: context,
        ref: ref,
        targetType: 'user',
        targetId: widget.peerUserId,
        targetLabel: 'user',
      );
      return;
    }
    if (action == 'block') {
      final blocked = await confirmAndBlockParkdUser(
        context: context,
        ref: ref,
        userId: widget.peerUserId,
        displayName: widget.peerDisplayName,
      );
      if (!blocked || !mounted) return;
      ref.invalidate(messagingInboxProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _activeTripChat = ref.read(activeTripChatProvider.notifier);
    _conversationId = widget.initialConversationId;
    ref.listenManual(myNotificationFeedProvider, (previous, next) {
      final hasUnreadForTrip =
          next.value?.latest.any(
            (row) => !row.isRead && row.reservationId == widget.reservationId,
          ) ??
          false;
      if (hasUnreadForTrip) _markReservationNotificationsRead();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTripChat.enter(widget.reservationId);
      _markReservationNotificationsRead();
    });
  }

  Future<void> _markReservationNotificationsRead() async {
    try {
      final cleared = await ref
          .read(notificationsRemoteProvider)
          .markReservationNotificationsRead(widget.reservationId);
      if (cleared > 0) ref.invalidate(myNotificationFeedProvider);
    } catch (_) {}
  }

  @override
  void dispose() {
    _activeTripChat.leave(widget.reservationId);
    _textController.dispose();
    super.dispose();
  }

  Future<void> _ensureConversation() async {
    if (_conversationId != null || _ensuring) return;
    setState(() {
      _ensuring = true;
      _ensureError = null;
    });
    try {
      final row = await ref
          .read(messagingRepositoryProvider)
          .ensureThread(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _conversationId = row.id;
        _ensuring = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ensuring = false;
        _ensureError = e;
      });
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _textController.text.trim();
    final cid = _conversationId;
    final uid = ref.read(currentSessionProvider)?.user.id;
    if (text.isEmpty || cid == null || uid == null) return;
    setState(() {
      _sending = true;
      _actionError = null;
    });
    _textController.clear();
    try {
      // The realtime stream delivers the new row, so no refresh here
      await ref
          .read(messagingRepositoryProvider)
          .send(conversationId: cid, senderId: uid, text: text);
    } catch (_) {
      if (!mounted) return;
      _textController.text = text;
      setState(() => _actionError = 'Could not send message.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = scrollViewBottomInset(context);

    if (_conversationId == null) {
      if (_ensureError != null) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppTopBar(title: widget.peerDisplayName, showBack: true),
          body: const AppPageStatus.error(
            title: 'Could not open conversation.',
          ),
        );
      }
      if (!_ensuring) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _ensureConversation(),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: widget.peerDisplayName,
          showBack: true,
          actions: _appBarActions,
        ),
        body: const AppPageStatus.loading(),
      );
    }

    final cid = _conversationId!;
    final messagesAsync = ref.watch(conversationMessagesProvider(cid));
    final uid = ref.watch(currentSessionProvider)?.user.id;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: widget.peerDisplayName,
        showBack: true,
        actions: _appBarActions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const AppPageStatus.loading(),
                error: (e, st) => const AppPageStatus.error(
                  title: 'Could not load messages.',
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No messages yet. Say hello.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm + bottom,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final previous = i == 0 ? null : messages[i - 1];
                      final next = i == messages.length - 1
                          ? null
                          : messages[i + 1];
                      final mine = uid != null && m.senderId == uid;
                      final showTimestamp = shouldShowChatTimestamp(
                        current: m.createdAt,
                        previous: previous?.createdAt,
                      );
                      final isTail = isChatBubbleTail(
                        senderId: m.senderId,
                        sentAt: m.createdAt,
                        nextSenderId: next?.senderId,
                        nextSentAt: next?.createdAt,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showTimestamp && m.createdAt != null)
                            AppChatTimestampDivider(
                              label: chatTimestampLabel(m.createdAt!),
                            ),
                          AppChatMessageBubble(
                            message: m.message,
                            isMine: mine,
                            isTail: isTail,
                            onLongPress: mine
                                ? null
                                : () => showParkdReportDialog(
                                    context: context,
                                    ref: ref,
                                    targetType: 'message',
                                    targetId: m.id,
                                    targetLabel: 'message',
                                  ),
                          ),
                          SizedBox(height: isTail ? AppSpacing.sm : 2),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            AppStickyFooter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_actionError != null) ...[
                    AppInlineError(
                      message: _actionError!,
                      onDismiss: () => setState(() => _actionError = null),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => null,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: const BorderSide(
                                color: AppColors.secondaryGrey,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: const BorderSide(
                                color: AppColors.secondaryGrey,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: const BorderSide(
                                color: AppColors.primaryBlue,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm + 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _ChatSendButton(
                        onPressed: (uid == null || _sending) ? null : _send,
                      ),
                    ],
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

class _ChatSendButton extends StatefulWidget {
  const _ChatSendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_ChatSendButton> createState() => _ChatSendButtonState();
}

class _ChatSendButtonState extends State<_ChatSendButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = (!reduceMotion && enabled && _pressed)
        ? AppMotion.pressScale
        : 1.0;

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.press,
        curve: AppMotion.emphasized,
        child: Material(
          color: enabled ? AppColors.primaryBlue : AppColors.primaryBlueMuted,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: AppColors.onPrimary.withValues(alpha: 0.28),
            highlightColor: AppColors.onPrimary.withValues(alpha: 0.12),
            onTap: enabled
                ? () {
                    AppFeedback.light(context);
                    widget.onPressed!();
                  }
                : null,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.send_rounded,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
