import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/support/support_config.dart';
import '../../core/support/web_sheet.dart';
import '../../l10n/l10n.dart';
import '../update/update_providers.dart';
import 'settings_providers.dart';

final supportConfigProvider = Provider<SupportConfig>(
  (ref) => const SupportConfig.fromEnvironment(),
);

/// The settings page's support rows: contact by mail, the privacy policy and
/// the crash report and usage statistics switches. Empty when the build has none of them.
class SupportSection extends ConsumerWidget {
  const SupportSection({super.key, required this.header});

  /// Builds the section title in the settings page's style.
  final Widget Function(String title) header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(supportConfigProvider);
    final reporter = ref.watch(crashReporterProvider);
    final analytics = ref.watch(usageAnalyticsProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final privacy = config.privacyPolicy(languageCode);
    if (config.email.isEmpty &&
        privacy == null &&
        !reporter.available &&
        !analytics.available) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header(l10n.settingsSupport),
        if (config.email.isNotEmpty)
          ListTile(
            key: const Key('contact'),
            leading: const Icon(Icons.mail_outline),
            title: Text(l10n.contactUs),
            subtitle: Text(config.email),
            onTap: () => _contact(context, ref, config),
          ),
        if (privacy != null)
          ListTile(
            key: const Key('privacy-policy'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, privacy),
          ),
        if (reporter.available)
          SwitchListTile(
            key: const Key('crash-reports'),
            value: ref.watch(settingsProvider.select((s) => s.crashReports)),
            onChanged: ref.read(settingsProvider.notifier).setCrashReports,
            title: Text(l10n.crashReports),
            subtitle: Text(l10n.crashReportsHelp),
          ),
        if (analytics.available)
          SwitchListTile(
            key: const Key('usage-analytics'),
            value: ref.watch(settingsProvider.select((s) => s.usageAnalytics)),
            onChanged: ref.read(settingsProvider.notifier).setUsageAnalytics,
            title: Text(l10n.usageAnalytics),
            subtitle: Text(l10n.usageAnalyticsHelp),
          ),
      ],
    );
  }

  Future<void> _contact(
    BuildContext context,
    WidgetRef ref,
    SupportConfig config,
  ) async {
    final l10n = context.l10n;
    final info = await ref.read(packageInfoProvider);
    final mail = config.contactMail(
      subject: l10n.contactSubject,
      body: contactBody(
        prompt: l10n.contactBodyPrompt,
        version: '${info.version} (${info.buildNumber})',
        os: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      ),
    );
    if (mail == null || !context.mounted) return;
    await _open(context, mail);
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.linkOpenFailed;
    // Web pages open in a sheet over the app; mail goes to the mail app.
    final opened = uri.scheme.startsWith('http')
        ? await openWebSheet(context, uri)
        : await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          ).catchError((_) => false);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text('$failed\n$uri')));
    }
  }
}

/// The prefilled mail: room to write first, then what support needs to know.
String contactBody({
  required String prompt,
  required String version,
  required String os,
}) => '$prompt\n\n\n\n---\nApp: $version\nOS: $os\n';
