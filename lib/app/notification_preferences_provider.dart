import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_shell_tab_provider.dart';

const _notificationBannersMutedKey = 'notification_banners_muted';

class NotificationBannersMutedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .read(sharedPreferencesProvider)
            .getBool(_notificationBannersMutedKey) ??
        false;
  }

  void setMuted(bool value) {
    state = value;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(_notificationBannersMutedKey, value),
    );
  }
}

final notificationBannersMutedProvider =
    NotifierProvider<NotificationBannersMutedNotifier, bool>(
      NotificationBannersMutedNotifier.new,
    );
