import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/active_trip_chat_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../moderation/presentation/moderation_actions.dart';
import '../../profile/providers/notifications_providers.dart';
import '../providers/reservations_providers.dart';

/// Live chat for one reservation (host or driver). Creates thread on first open if needed
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
  String? _conversationId;
  bool _ensuring = false;
  Object? _ensureError;
  DateTime? _lastSentAt;

  List<Widget> get _viewTripActions {
    final label = widget.viewTripLabel?.trim();
    final onTap = widget.onViewTrip;
    if (label == null || label.isEmpty || onTap == null) return const [];
    return [
      TextButton(
        onPressed: onTap,
        child: Text(label, style: AppTypography.textAction),
      ),
    ];
  }

  List<Widget> get _appBarActions => [
    ..._viewTripActions,
    PopupMenuButton<String>(
      tooltip: 'Safety options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: _onSafetyAction,
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'report',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Report user'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'block',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.block_rounded),
            title: Text('Block user'),
          ),
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
    _conversationId = widget.initialConversationId;
    ref.listenManual(myNotificationFeedProvider, (previous, next) {
      final hasUnreadForTrip =
          next.value?.latest.any(
            (row) => !row.isRead && row.reservationId == widget.reservationId,
          ) ??
          false;
      if (hasUnreadForTrip) _markMessageNotificationsRead();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeTripChatProvider.notifier).enter(widget.reservationId);
      _markMessageNotificationsRead();
    });
  }

  Future<void> _markMessageNotificationsRead() async {
    try {
      await ref
          .read(notificationsRemoteProvider)
          .markMessageNotificationsRead(widget.reservationId);
    } catch (_) {}
  }

  @override
  void dispose() {
    ref.read(activeTripChatProvider.notifier).leave(widget.reservationId);
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
      ref.invalidate(conversationMessagesProvider(row.id));
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
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(milliseconds: 750)) {
      return;
    }
    _lastSentAt = now;
    try {
      await ref
          .read(messagingRepositoryProvider)
          .send(conversationId: cid, senderId: uid, text: text);
      _textController.clear();
      ref.invalidate(conversationMessagesProvider(cid));
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
          appBar: AppTopBar(title: widget.peerDisplayName, showBack: true),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Could not open conversation.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted,
              ),
            ),
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
        actions: _appBarActions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text(
                    'Could not load messages.',
                    style: AppTypography.bodyMuted,
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'No messages yet. Say hello.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMuted,
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
                      final mine = uid != null && m.senderId == uid;
                      final name = mine ? 'You' : widget.peerDisplayName;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppChatMessageBubble(
                          senderName: name,
                          message: m.message,
                          isMine: mine,
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
              child: Row(
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
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.secondaryGrey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.secondaryGrey,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: uid == null ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: AppColors.onPrimary,
                    ),
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
