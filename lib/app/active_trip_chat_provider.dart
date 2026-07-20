import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveTripChatNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void enter(String reservationId) => state = reservationId;

  void leave(String reservationId) {
    if (state == reservationId) state = null;
  }
}

final activeTripChatProvider =
    NotifierProvider<ActiveTripChatNotifier, String?>(
      ActiveTripChatNotifier.new,
    );
