import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/layout.dart';
import '../../core/storage/settings_store.dart';
import '../../l10n/l10n.dart';
import '../ads/ads_settings_section.dart';
import '../update/update_providers.dart';
import 'settings_providers.dart';
import 'support_section.dart';

/// Language names are shown in their own language, so they read the same
/// whichever language the app is in.
const _languages = {'ja': '日本語', 'en': 'English'};

/// App-wide settings: appearance, language, haptics, ads and support.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          readableSide(context),
          0,
          readableSide(context),
          24,
        ),
        children: [
          _SectionHeader(l10n.settingsAppearance),
          _Choices<ThemeMode>(
            keyPrefix: 'theme',
            selected: settings.themeMode,
            onChanged: notifier.setThemeMode,
            options: [
              (ThemeMode.system, ThemeMode.system.name, l10n.themeSystem),
              (ThemeMode.light, ThemeMode.light.name, l10n.themeLight),
              (ThemeMode.dark, ThemeMode.dark.name, l10n.themeDark),
            ],
          ),
          _SectionHeader(l10n.settingsLanguage),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownMenu<String>(
              key: const Key('language-menu'),
              initialSelection: settings.languageCode ?? '',
              expandedInsets: EdgeInsets.zero,
              requestFocusOnTap: false,
              onSelected: (code) => notifier.setLanguage(
                code == null || code.isEmpty ? null : code,
              ),
              dropdownMenuEntries: [
                DropdownMenuEntry(
                  value: '',
                  label: l10n.settingsFollowSystem,
                  labelWidget: Text(
                    l10n.settingsFollowSystem,
                    key: const Key('language-system'),
                  ),
                ),
                for (final MapEntry(key: code, value: name)
                    in _languages.entries)
                  DropdownMenuEntry(
                    value: code,
                    label: name,
                    labelWidget: Text(name, key: Key('language-$code')),
                  ),
              ],
            ),
          ),
          _SectionHeader(l10n.settingsHaptics),
          _Choices<HapticsLevel>(
            keyPrefix: 'haptics',
            selected: settings.haptics,
            onChanged: notifier.setHaptics,
            options: [
              for (final level in HapticsLevel.values)
                (
                  level,
                  level.name,
                  switch (level) {
                    HapticsLevel.off => l10n.hapticsOff,
                    HapticsLevel.light => l10n.hapticsLight,
                    HapticsLevel.strong => l10n.hapticsStrong,
                  },
                ),
            ],
          ),
          if (switch (settings.haptics) {
                HapticsLevel.off => null,
                HapticsLevel.light => l10n.hapticsLightHelp,
                HapticsLevel.strong => l10n.hapticsStrongHelp,
              }
              case final help?)
            Padding(
              key: const Key('haptics-help'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                help,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          AdsSettingsSection(header: _SectionHeader.new),
          SupportSection(header: _SectionHeader.new),
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            key: const Key('app-version'),
            title: Text(l10n.settingsVersion),
            subtitle: Text(ref.watch(appVersionProvider).value ?? ''),
          ),
          ListTile(
            key: const Key('app-os'),
            title: Text(l10n.settingsOs),
            subtitle: Text(
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line row of mutually exclusive options. Each segment gets the key
/// `$keyPrefix-$name` so tests can tap it.
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.keyPrefix,
    required this.selected,
    required this.onChanged,
    required this.options,
  });

  final String keyPrefix;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<(T, String, String)> options;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final (value, name, label) in options)
              ButtonSegment(
                value: value,
                label: Text(label, key: Key('$keyPrefix-$name')),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.single),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
