import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/session_replay.dart';
import 'settings_providers.dart';

/// Wraps the whole app (MaterialApp's `builder`): masks it in session
/// recordings and starts or pauses recording with the usage statistics
/// switch. Waits for the stored switch first, so a user who turned it off is
/// never recorded while the settings load.
class SessionReplayScope extends ConsumerStatefulWidget {
  const SessionReplayScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionReplayScope> createState() => _SessionReplayScopeState();
}

class _SessionReplayScopeState extends ConsumerState<SessionReplayScope> {
  /// The switch as last changed after launch, which wins over the stored one.
  bool? _changed;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final replay = ref.read(sessionReplayProvider);
    if (!replay.available) return;
    ref.listenManual(settingsProvider.select((s) => s.usageAnalytics), (_, on) {
      _changed = on;
      if (_loaded) replay.setEnabled(context, on);
    });
    ref.read(settingsStoreProvider).load().then((stored) {
      if (!mounted) return;
      _loaded = true;
      replay.setEnabled(context, _changed ?? stored.usageAnalytics);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) => SessionReplayMask(child: widget.child);
}
