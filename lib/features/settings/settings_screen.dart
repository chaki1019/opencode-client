import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/layout.dart';
import '../../l10n/l10n.dart';
import '../ads/ads_settings_section.dart';
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
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) notifier.setThemeMode(mode);
            },
            child: Column(
              children: [
                for (final (mode, label) in [
                  (ThemeMode.system, l10n.settingsFollowSystem),
                  (ThemeMode.light, l10n.themeLight),
                  (ThemeMode.dark, l10n.themeDark),
                ])
                  RadioListTile<ThemeMode>(
                    key: Key('theme-${mode.name}'),
                    value: mode,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          _SectionHeader(l10n.settingsLanguage),
          RadioGroup<String>(
            groupValue: settings.languageCode ?? '',
            onChanged: (code) => notifier.setLanguage(
              code == null || code.isEmpty ? null : code,
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  key: const Key('language-system'),
                  value: '',
                  title: Text(l10n.settingsFollowSystem),
                ),
                for (final MapEntry(key: code, value: name)
                    in _languages.entries)
                  RadioListTile<String>(
                    key: Key('language-$code'),
                    value: code,
                    title: Text(name),
                  ),
              ],
            ),
          ),
          _SectionHeader(l10n.settingsInteraction),
          SwitchListTile(
            key: const Key('haptics'),
            value: settings.haptics,
            onChanged: notifier.setHaptics,
            title: Text(l10n.settingsHaptics),
            subtitle: Text(l10n.settingsHapticsHelp),
          ),
          AdsSettingsSection(header: _SectionHeader.new),
          SupportSection(header: _SectionHeader.new),
        ],
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
