import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/messaging/app_messenger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
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
  }

  @override
  void dispose() {
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
    try {
      await ref.read(messagingRepositoryProvider).send(
            conversationId: cid,
            senderId: uid,
            text: text,
          );
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppChatMessageBubble(
                          senderName: name,
                          message: m.message,
                          isMine: mine,
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
