import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/listing.dart';
import '../core/models/reservation_row.dart';

enum MessageDeepLinkRole { host, driver }

class MessageDeepLinkIntent {
  const MessageDeepLinkIntent({
    required this.role,
    required this.reservation,
    required this.listing,
    this.conversationId,
    required this.peerDisplayName,
    required this.activeFlow,
    this.openBookingDetailsOnTop = false,
  });

  final MessageDeepLinkRole role;
  final ReservationRow reservation;
  final Listing listing;
  final String? conversationId;
  final String peerDisplayName;
  final bool activeFlow;

  /// Host: after Active bookings → listing → chat, push [BookingDetailsScreen] on top.
  final bool openBookingDetailsOnTop;
}

class MessageDeepLinkNotifier extends Notifier<MessageDeepLinkIntent?> {
  @override
  MessageDeepLinkIntent? build() => null;

  void emit(MessageDeepLinkIntent intent) => state = intent;

  void clear() => state = null;
}

final messageDeepLinkProvider =
    NotifierProvider<MessageDeepLinkNotifier, MessageDeepLinkIntent?>(
  MessageDeepLinkNotifier.new,
);
