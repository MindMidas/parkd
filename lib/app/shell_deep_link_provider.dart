import 'package:flutter_riverpod/flutter_riverpod.dart';

// Request to open a reservation chat inside the main tab shell (keeps bottom nav).
class ShellMessageDeepLink {
  const ShellMessageDeepLink({
    required this.reservationId,
    required this.nonce,
  });

  final String reservationId;
  final int nonce;
}

class ShellDeepLinkNotifier extends Notifier<ShellMessageDeepLink?> {
  int _nonce = 0;

  @override
  ShellMessageDeepLink? build() => null;

  void openReservationMessages(String reservationId) {
    final id = reservationId.trim();
    if (id.isEmpty) return;
    state = ShellMessageDeepLink(reservationId: id, nonce: ++_nonce);
  }

  void clear() {
    if (state != null) state = null;
  }
}

final shellDeepLinkProvider =
    NotifierProvider<ShellDeepLinkNotifier, ShellMessageDeepLink?>(
      ShellDeepLinkNotifier.new,
    );
