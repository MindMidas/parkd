import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main_tab.dart';

const _mainShellTabStorageKey = 'main_shell_tab_index';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences override is required.'),
);

class MainShellTabNotifier extends Notifier<int> {
  late final SharedPreferences _prefs;

  @override
  int build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final saved = _prefs.getInt(_mainShellTabStorageKey);
    if (saved == null) return MainTab.map;
    return saved.clamp(0, MainTab.count - 1);
  }

  void setTab(int index) {
    final next = index.clamp(0, MainTab.count - 1);
    state = next;
    unawaited(_prefs.setInt(_mainShellTabStorageKey, next));
  }
}

final mainShellTabIndexProvider =
    NotifierProvider<MainShellTabNotifier, int>(MainShellTabNotifier.new);
