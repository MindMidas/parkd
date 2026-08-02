import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/app/main_shell_tab_provider.dart';
import 'package:parkd/features/map/presentation/main_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MainTab', () {
    test('maps stable route query values in both directions', () {
      expect(MainTab.fromQuery('map'), MainTab.map);
      expect(MainTab.fromQuery('hosting'), MainTab.hosting);
      expect(MainTab.fromQuery('account'), MainTab.account);
      expect(MainTab.fromQuery('unknown'), MainTab.map);
      expect(MainTab.toQuery(MainTab.reservations), 'reservations');
      expect(MainTab.toQuery(99), 'map');
    });
  });

  group('MainShellTabNotifier', () {
    test('restores and clamps a persisted tab index', () async {
      SharedPreferences.setMockInitialValues({'main_shell_tab_index': 99});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      expect(container.read(mainShellTabIndexProvider), MainTab.account);
    });

    test('updates state and persists a valid selection', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      container
          .read(mainShellTabIndexProvider.notifier)
          .setTab(MainTab.reservations);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(mainShellTabIndexProvider), MainTab.reservations);
      expect(preferences.getInt('main_shell_tab_index'), MainTab.reservations);
    });
  });
}
