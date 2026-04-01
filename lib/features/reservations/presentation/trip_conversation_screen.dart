import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/active_trip_chat_foreground_provider.dart';
import '../../../core/models/notification_row.dart';
import '../../../core/notifications/notification_hub_counts.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/notifications_providers.dart';
import '../providers/reservations_providers.dart';

class TripConversationScreen extends ConsumerStatefulWidget {
  const TripConversationScreen({
    super.key,
    required this.reservationId,
    this.initialConversationId,
    required this.peerDisplayName,
    this.viewTripLabel,
    this.onViewTrip,
  });

  final String reservationId;
  final String? initialConversationId;
  final String peerDisplayName;

  final String? viewTripLabel;
  final VoidCallback? onViewTrip;

  @override
  ConsumerState<TripConversationScreen> createState() =>
      _TripConversationScreenState();
}

class _TripConversationScreenState extends ConsumerState<TripConversationScreen> {
  final _textController = TextEditingController();
  String? _conversationId;
  bool _ensuring = false;
  Object? _ensureError;
  int? _foregroundSessionToken;

  List<Widget> get _viewTripActions {
    final label = widget.viewTripLabel?.trim();
    final onTap = widget.onViewTrip;
    if (label == null || label.isEmpty || onTap == null) return const [];
    return [
      AppCompactPrimaryTextButton(
        label: label,
        onPressed: onTap,
        labelStyle: AppTypography.textAction,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _conversationId = widget.initialConversationId;
    ref.listenManual<AsyncValue<List<NotificationRow>>>(
      myNotificationsProvider,
      (previous, next) {
        final rows = next.value;
        if (rows == null || !mounted) return;
        if (!_hasUnreadMessageNotificationForThisChat(rows)) return;
        _markThreadMessageNotificationsRead();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _foregroundSessionToken = ref
          .read(activeTripChatForegroundProvider.notifier)
          .enter(
            widget.reservationId,
            conversationId: _conversationId,
          );
      _markThreadMessageNotificationsRead();
    });
  }

  bool _hasUnreadMessageNotificationForThisChat(List<NotificationRow> rows) {
    final cid = _conversationId?.trim();
    final resId = widget.reservationId.trim();
    if (resId.isEmpty) return false;
    for (final n in rows) {
      if (n.isRead || n.type != 'message_received') continue;
      final nc = n.dataJson['conversation_id'];
      final ncStr = nc is String ? nc.trim() : null;
      if (cid != null &&
          cid.isNotEmpty &&
          ncStr != null &&
          ncStr == cid) {
        return true;
      }
      final nr = notificationReservationId(n);
      if (nr != null && nr == resId) return true;
    }
    return false;
  }

  Future<void> _markThreadMessageNotificationsRead() async {
    final uid = ref.read(currentSessionProvider)?.user.id;
    if (uid == null) return;
    try {
      await ref.read(notificationsRemoteProvider).markMessageNotificationsReadForThread(
            userId: uid,
            conversationId: _conversationId,
            reservationId: widget.reservationId,
          );
    } catch (_) {}
  }

  @override
  void dispose() {
    final tok = _foregroundSessionToken;
    if (tok != null) {
      ref.read(activeTripChatForegroundProvider.notifier).leave(tok);
    }
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
      final tok = _foregroundSessionToken;
      if (tok != null) {
        ref
            .read(activeTripChatForegroundProvider.notifier)
            .updateConversation(tok, row.id);
      }
      await _markThreadMessageNotificationsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ensuring = false;
        _ensureError = e;
      });
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    final cid = _conversationId;
    final uid = ref.read(currentSessionProvider)?.user.id;
    if (text.isEmpty || cid == null || uid == null) return;
    try {
      await ref.read(messagingRepositoryProvider).send(
            conversationId: cid,
            senderId: uid,
            text: text,
          );
      _textController.clear();
    } catch (_) {
      if (!mounted) return;
      AppMessenger.showError(context, 'Could not send message.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = scrollViewBottomInset(context);

    if (_conversationId == null) {
      if (_ensureError != null) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppTopBar(
            title: widget.peerDisplayName,
            showBack: true,
          ),
          body: const AppMutedBodyCenter(
            'Could not open conversation.',
            padding: EdgeInsets.all(AppSpacing.lg),
          ),
        );
      }
      if (!_ensuring) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConversation());
      }
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: widget.peerDisplayName,
          showBack: true,
          actions: _viewTripActions,
        ),
        body: const Center(child: CircularProgressIndicator()),
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
        actions: _viewTripActions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text('Could not load messages.', style: AppTypography.bodyMuted),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const AppMutedBodyCenter(
                      'No messages yet. Say hello.',
                      padding: EdgeInsets.all(AppSpacing.lg),
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
                      final mine = uid != null && m.senderId == uid;
                      final name = mine ? 'You' : widget.peerDisplayName;
                      final prev = i > 0 ? messages[i - 1] : null;
                      final showSenderHeader =
                          prev == null || prev.senderId != m.senderId;
                      final created = m.createdAt;
                      final showDayDivider = created != null &&
                          (prev == null ||
                              prev.createdAt == null ||
                              !chatMessageSameLocalDay(
                                prev.createdAt!,
                                created,
                              ));
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: showSenderHeader
                              ? AppSpacing.sm
                              : AppSpacing.xs,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDayDivider)
                              AppChatDayDivider(
                                label: formatChatDayDividerLabel(created),
                              ),
                            AppChatMessageBubble(
                              senderName: name,
                              message: m.message,
                              isMine: mine,
                              showSenderHeader: showSenderHeader,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md + bottom,
              ),
              child: AppChatMessageComposer(
                controller: _textController,
                onSend: _send,
                enabled: uid != null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
