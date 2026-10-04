/// The push plugin as OpenCode on the computer sees it, read from
/// `GET /api/plugin` and `GET /api/config`.
const pushPluginPackage = 'opencode-mobile-push';
const pushPluginFileName = 'opencode-mobile-push.js';

/// The relay refuses shorter keys.
const minPairingKeyLength = 32;

// Names used before the npm package was renamed.
const _pluginIds = {pushPluginPackage, 'opencode-push'};
const _pluginFiles = {pushPluginFileName, 'opencode-push.js'};

/// One entry of `GET /api/plugin`.
class ServerPlugin {
  const ServerPlugin({
    this.id,
    this.package,
    this.path,
    required this.active,
    this.error,
  });

  static ServerPlugin? tryParse(Object? json) {
    if (json is! Map) return null;
    final source = json['source'];
    final state = json['state'];
    if (source is! Map || state is! Map) return null;
    return ServerPlugin(
      id: json['id'] is String ? json['id'] as String : null,
      package: source['type'] == 'package' && source['target'] is String
          ? source['target'] as String
          : null,
      path: source['type'] == 'local' && source['path'] is String
          ? source['path'] as String
          : null,
      active: state['status'] == 'active',
      error: state['error'] is String ? state['error'] as String : null,
    );
  }

  final String? id;

  /// The npm target of a package plugin.
  final String? package;

  /// The file or folder of a local plugin.
  final String? path;
  final bool active;
  final String? error;

  bool get isPush =>
      _pluginIds.contains(id) ||
      (package != null && _isPushPackage(package!)) ||
      (path != null && _pluginFiles.contains(_basename(path!)));
}

/// What `GET /api/config` says about the push plugin.
class ComputerConfig {
  const ComputerConfig({this.entries = const []});

  /// Reads the configuration documents and sources (lowest priority first).
  factory ComputerConfig.fromEntries(List<Object?> json) {
    final entries = <PushPluginEntry>[];
    for (final item in json) {
      if (item is! Map) continue;
      if (item['type'] != 'document') continue;
      final info = item['info'];
      final plugins = info is Map ? info['plugins'] : null;
      if (plugins is! List) continue;
      for (final plugin in plugins) {
        if (plugin is String && _isPushPackage(plugin)) {
          entries.add(const PushPluginEntry());
        } else if (plugin is Map &&
            plugin['package'] is String &&
            _isPushPackage(plugin['package'] as String)) {
          final options = plugin['options'];
          String? option(String name) =>
              options is Map && options[name] is String
              ? options[name] as String
              : null;
          entries.add(
            PushPluginEntry(relay: option('relay'), key: option('key')),
          );
        }
      }
    }
    return ComputerConfig(entries: entries);
  }

  final List<PushPluginEntry> entries;
}

/// The plugin as declared in a configuration document.
class PushPluginEntry {
  const PushPluginEntry({this.relay, this.key});

  /// Null when relay and key come from the settings file instead.
  final String? relay;
  final String? key;
}

enum ComputerPluginStatus {
  /// Loaded and running.
  active,

  /// OpenCode tried to load it and failed (see [ComputerPluginCheck.error]).
  failed,

  /// `opencode.json` passes another relay or pairing key.
  otherKey,

  /// Set up, but OpenCode has not loaded it (yet).
  notLoaded,

  /// Not set up on the computer.
  missing,
}

class ComputerPluginCheck {
  const ComputerPluginCheck(this.status, {this.error, this.sharedKey});

  final ComputerPluginStatus status;
  final String? error;

  /// With [ComputerPluginStatus.otherKey]: the pairing key `opencode.json`
  /// passes for this relay, which this device can switch to so that it
  /// gets the same notifications as the device that set it up.
  final String? sharedKey;
}

ComputerPluginCheck checkComputerPlugin({
  required List<ServerPlugin> plugins,
  required ComputerConfig config,
  required String relayUrl,
  required String key,
}) {
  ComputerPluginCheck result(
    ComputerPluginStatus status, {
    String? error,
    String? sharedKey,
  }) => ComputerPluginCheck(status, error: error, sharedKey: sharedKey);

  final loaded = plugins.where((p) => p.isPush).toList();
  final explicit = config.entries.where((e) => e.key != null).toList();
  final matches = explicit.any(
    (e) => e.key == key && _sameRelay(e.relay, relayUrl),
  );
  final failed = loaded.where((p) => !p.active).firstOrNull;
  if (failed != null) {
    return result(ComputerPluginStatus.failed, error: failed.error);
  }
  if (explicit.isNotEmpty && !matches) {
    final shared = explicit
        .where((e) => _sameRelay(e.relay, relayUrl))
        .map((e) => e.key!.trim())
        .where((k) => k.length >= minPairingKeyLength)
        .firstOrNull;
    return result(ComputerPluginStatus.otherKey, sharedKey: shared);
  }
  if (loaded.isNotEmpty) return result(ComputerPluginStatus.active);
  if (config.entries.isNotEmpty) return result(ComputerPluginStatus.notLoaded);
  return result(ComputerPluginStatus.missing);
}

bool _isPushPackage(String target) {
  // "opencode-mobile-push" or "opencode-mobile-push@0.2.0".
  final at = target.lastIndexOf('@');
  return _pluginIds.contains(at > 0 ? target.substring(0, at) : target);
}

bool _sameRelay(String? a, String b) =>
    a != null &&
    a.replaceAll(RegExp(r'/+$'), '') == b.replaceAll(RegExp(r'/+$'), '');

String _basename(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
  return parts.isEmpty ? '' : parts.last;
}
