import 'package:flutter_riverpod/flutter_riverpod.dart';

/// While [TripConversationScreen] is visible, holds the reservation (and
/// conversation when known) so in-app message banners can be suppressed.
class ActiveTripChatForeground {
  const ActiveTripChatForeground({
    required this.reservationId,
    this.conversationId,
    required this.sessionToken,
  });

  final String reservationId;
  final String? conversationId;
  final int sessionToken;
}

class ActiveTripChatForegroundNotifier extends Notifier<ActiveTripChatForeground?> {
  int _seq = 0;

  @override
  ActiveTripChatForeground? build() => null;

  /// Returns a session token; pass it to [updateConversation] and [leave].
  int enter(String reservationId, {String? conversationId}) {
    final token = ++_seq;
    state = ActiveTripChatForeground(
      reservationId: reservationId,
      conversationId: conversationId,
      sessionToken: token,
    );
    return token;
  }

  void updateConversation(int sessionToken, String conversationId) {
    final s = state;
    if (s == null || s.sessionToken != sessionToken) return;
    state = ActiveTripChatForeground(
      reservationId: s.reservationId,
      conversationId: conversationId,
      sessionToken: sessionToken,
    );
  }

  void leave(int sessionToken) {
    if (state?.sessionToken == sessionToken) state = null;
  }
}

final activeTripChatForegroundProvider =
    NotifierProvider<ActiveTripChatForegroundNotifier, ActiveTripChatForeground?>(
  ActiveTripChatForegroundNotifier.new,
);
