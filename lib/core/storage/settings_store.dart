import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-wide preferences that do not depend on any server.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.haptics = true,
    this.crashReports = true,
    this.usageAnalytics = true,
  });

  final ThemeMode themeMode;

  /// `ja`, `en`, or null to follow the device language.
  final String? languageCode;

  /// Whether the app gives haptic feedback at key moments.
  final bool haptics;

  /// Whether crash reports may be sent.
  final bool crashReports;

  /// Whether usage statistics may be sent.
  final bool usageAnalytics;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? Function()? language,
    bool? haptics,
    bool? crashReports,
    bool? usageAnalytics,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    languageCode: language == null ? languageCode : language(),
    haptics: haptics ?? this.haptics,
    crashReports: crashReports ?? this.crashReports,
    usageAnalytics: usageAnalytics ?? this.usageAnalytics,
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
      haptics: json['haptics'] as bool? ?? true,
      crashReports: json['crashReports'] as bool? ?? true,
      usageAnalytics: json['usageAnalytics'] as bool? ?? true,
    );
  }

  Future<void> save(AppSettings settings) => _storage.write(
    key: _key,
    value: jsonEncode({
      'theme': settings.themeMode.name,
      'language': ?settings.languageCode,
      'haptics': settings.haptics,
      'crashReports': settings.crashReports,
      'usageAnalytics': settings.usageAnalytics,
    }),
  );
}
