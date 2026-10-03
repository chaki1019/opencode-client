import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-wide preferences that do not depend on any server.
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system, this.languageCode});

  final ThemeMode themeMode;

  /// `ja`, `en`, or null to follow the device language.
  final String? languageCode;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppSettings copyWith({ThemeMode? themeMode, String? Function()? language}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        languageCode: language == null ? languageCode : language(),
      );
}

/// Keeps [AppSettings] next to the other stored data, so the app needs no
/// second storage plugin.
class SettingsStore {
  SettingsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'settings.v1';

  final FlutterSecureStorage _storage;

  Future<AppSettings> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AppSettings(
      themeMode:
          ThemeMode.values.where((m) => m.name == json['theme']).firstOrNull ??
          ThemeMode.system,
      languageCode: json['language'] as String?,
    );
  }

  Future<void> save(AppSettings settings) => _storage.write(
    key: _key,
    value: jsonEncode({
      'theme': settings.themeMode.name,
      'language': ?settings.languageCode,
    }),
  );
}
