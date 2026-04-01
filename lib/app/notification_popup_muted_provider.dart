import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_shell_tab_provider.dart';

const _kNotificationPopupsMuted = 'parkd_notification_popups_muted';

/// When true, new notifications still sync to the list but no floating snackbars.
class NotificationPopupsMutedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_kNotificationPopupsMuted) ?? false;
  }

  Future<void> setMuted(bool muted) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kNotificationPopupsMuted, muted);
    state = muted;
  }
}

final notificationPopupsMutedProvider =
    NotifierProvider<NotificationPopupsMutedNotifier, bool>(
  NotificationPopupsMutedNotifier.new,
);
