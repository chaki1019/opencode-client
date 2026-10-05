import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How much the app vibrates.
enum HapticsLevel {
  off,

  /// Send, reply finished, waiting on the user, failures and gestures.
  light,

  /// Also marks the moment the AI starts writing its reply.
  strong;

  /// Also reads the on/off value stored before there were levels.
  static HapticsLevel fromJson(Object? value) => switch (value) {
    false => off,
    String name => values.where((l) => l.name == name).firstOrNull ?? light,
    _ => light,
  };
}

/// App-wide preferences that do not depend on any server.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.haptics = HapticsLevel.light,
    this.crashReports = true,
  });

  final ThemeMode themeMode;

  /// `ja`, `en`, or null to follow the device language.
  final String? languageCode;

  /// How much haptic feedback the app gives.
  final HapticsLevel haptics;

  /// Whether crash reports may be sent.
  final bool crashReports;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? Function()? language,
    HapticsLevel? haptics,
    bool? crashReports,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: language == null ? languageCode : language(),
    haptics: haptics ?? this.haptics,
    crashReports: crashReports ?? this.crashReports,
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
      haptics: HapticsLevel.fromJson(json['haptics']),
      crashReports: json['crashReports'] as bool? ?? true,
    );
  }

  Future<void> save(AppSettings settings) => _storage.write(
    key: _key,
    value: jsonEncode({
      'theme': settings.themeMode.name,
      'language': ?settings.languageCode,
      'haptics': settings.haptics.name,
      'crashReports': settings.crashReports,
    }),
  );
}
