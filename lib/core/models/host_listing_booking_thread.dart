import 'conversation_row.dart';
import 'reservation_row.dart';

// Host-side inbox row: a booking at one of your listings, optional chat thread
class HostListingBookingThread {
  const HostListingBookingThread({
    required this.reservation,
    this.conversation,
    this.lastMessagePreview,
  });

  final ReservationRow reservation;
  final ConversationRow? conversation;
  final String? lastMessagePreview;
}
