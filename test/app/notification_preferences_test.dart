import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/app/main_shell_tab_provider.dart';
import 'package:parkd/app/notification_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists the in-app banner preference', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(notificationBannersMutedProvider), isFalse);
    container.read(notificationBannersMutedProvider.notifier).setMuted(true);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(notificationBannersMutedProvider), isTrue);
    expect(preferences.getBool('notification_banners_muted'), isTrue);
  });
}
