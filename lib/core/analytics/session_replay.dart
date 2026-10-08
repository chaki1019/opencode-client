import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Records how the app is used (Microsoft Clarity): taps and screen
/// layouts, for heatmaps and session replays. Shares the usage statistics
/// switch with [UsageAnalytics]. The app is masked as a whole (see
/// [SessionReplayMask]), so recordings show layout and taps, never chat
/// content, code, server details or what is typed. Builds without a Clarity
/// project ID, debug builds and tests use [SessionReplay.none].
abstract class SessionReplay {
  const factory SessionReplay.none() = _NoSessionReplay;

  /// Reads the project ID from the `CLARITY_PROJECT_ID` build value; an empty
  /// or invalid one gives [SessionReplay.none].
  factory SessionReplay.fromEnvironment() {
    const projectId = String.fromEnvironment('CLARITY_PROJECT_ID');
    if (projectId.isEmpty || kDebugMode || kIsWeb) {
      return const SessionReplay.none();
    }
    final config = ClarityConfig(projectId: projectId, logLevel: LogLevel.None);
    if (!config.isProjectIdValid()) return const SessionReplay.none();
    return _ClaritySessionReplay(config);
  }

  /// Whether this build records at all.
  bool get available;

  /// Names each recorded screen after its route pattern, or null when
  /// nothing is recorded.
  NavigatorObserver? get observer;

  /// Starts or resumes recording, or pauses it. Clarity starts from a
  /// [context] under the app's [MediaQuery], so the first `true` starts it.
  /// Never throws.
  void setEnabled(BuildContext context, bool on);
}

class _NoSessionReplay implements SessionReplay {
  const _NoSessionReplay();

  @override
  bool get available => false;

  @override
  NavigatorObserver? get observer => null;

  @override
  void setEnabled(BuildContext context, bool on) {}
}

class _ClaritySessionReplay implements SessionReplay {
  _ClaritySessionReplay(this._config);

  final ClarityConfig _config;
  bool _started = false;

  @override
  bool get available => true;

  @override
  final NavigatorObserver observer = _ScreenNameObserver();

  @override
  void setEnabled(BuildContext context, bool on) {
    try {
      if (!on) {
        if (_started) Clarity.pause();
      } else if (!_started) {
        _started = Clarity.initialize(context, _config);
        // Analytics only: nothing recorded is used for ads.
        if (_started) Clarity.consent(false, true);
      } else {
        Clarity.resume();
      }
    } catch (error) {
      debugPrint('Session replay is off: $error');
    }
  }
}

/// Clarity names every Flutter screen after the host activity unless told
/// otherwise. Pages are named after their route pattern
/// (`/sessions/:sessionId`, see the router), so no IDs leave the device.
/// Sheets and dialogs keep the page beneath them as the screen.
class _ScreenNameObserver extends NavigatorObserver {
  void _show(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    Clarity.setCurrentScreenName(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);
}

/// Masks everything below it in session recordings, whatever masking mode
/// the Clarity project is set to: text shows as dots and images as blocks.
class SessionReplayMask extends StatelessWidget {
  const SessionReplayMask({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClarityMask(child: child);
}

/// Lifts [SessionReplayMask] for screens that show only the app's own text,
/// never anything from the user's servers.
class SessionReplayUnmask extends StatelessWidget {
  const SessionReplayUnmask({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClarityUnmask(child: child);
}
