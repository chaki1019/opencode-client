import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/crash/crash_reporter.dart';
import 'core/push/push_config.dart';
import 'features/ads/ads_providers.dart';
import 'features/ads/remove_ads.dart';
import 'features/push/push_providers.dart';
import 'features/settings/settings_providers.dart';
import 'features/update/update_gate.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final crashReporter = await startCrashReporting(
    const PushConfig.fromEnvironment().firebaseOptions,
  );
  runApp(
    ProviderScope(
      overrides: [crashReporterProvider.overrideWithValue(crashReporter)],
      child: const OpenCodeMobileApp(),
    ),
  );
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
    ref.watch(adsStartupProvider);
    // Kept alive from launch to receive redelivered purchases, without
    // rebuilding the app on each purchase state.
    ref.listen(removeAdsProvider, (_, _) {});
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
      builder: (context, child) => UpdateGate(child: child!),
    );
  }
}
