import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'features/push/push_providers.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/l10n.dart';

void main() {
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const ProviderScope(child: OpenCodeMobileApp()));
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final (package, file) in [
    ('IBM Plex Sans', 'OFL-IBMPlexSans.txt'),
    ('JetBrains Mono', 'OFL-JetBrainsMono.txt'),
  ]) {
    final text = await rootBundle.loadString('assets/fonts/$file');
    yield LicenseEntryWithLineBreaks([package], text);
  }
}

class OpenCodeMobileApp extends ConsumerWidget {
  const OpenCodeMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushCoordinatorProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'OpenCode Mobile',
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
