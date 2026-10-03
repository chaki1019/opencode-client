import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_store.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// Starts from the defaults (system theme and language) and switches to the
/// stored values once they are read, so the first frame never waits on
/// storage.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  /// Set once the user changes something, so a slow initial read does not
  /// overwrite it.
  bool _changed = false;

  @override
  AppSettings build() {
    _store.load().then((stored) {
      if (!_changed && ref.mounted) state = stored;
    });
    return const AppSettings();
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  /// [code] is `ja`, `en`, or null to follow the device.
  Future<void> setLanguage(String? code) =>
      _update(state.copyWith(language: () => code));

  Future<void> setHaptics(bool on) => _update(state.copyWith(haptics: on));

  Future<void> _update(AppSettings settings) async {
    _changed = true;
    state = settings;
    await _store.save(settings);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
