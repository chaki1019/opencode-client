import 'dart:convert';

/// The push plugin as OpenCode on the computer sees it, read from
/// `GET /api/plugin` and `GET /api/config`.
const pushPluginPackage = 'opencode-mobile-push';
const pushPluginFileName = 'opencode-mobile-push.js';

/// Where the plugin keeps its relay and pairing key when `opencode.json`
/// gives none, next to `opencode.json` itself. The plugin creates it with a
/// new key on first start.
const pushSettingsFileName = 'opencode-mobile-push.json';

/// The relay the plugin uses when none is configured.
const defaultPushRelayUrl = 'https://relay.opencodemobile.app';

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
    this.version,
    this.outdated = false,
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
      version: source['version'] is String ? source['version'] as String : null,
      outdated: source['outdated'] == true,
    );
  }

  final String? id;

  /// The npm target of a package plugin.
  final String? package;

  /// The file or folder of a local plugin.
  final String? path;
  final bool active;
  final String? error;

  /// The installed version of a package plugin, when OpenCode reports it.
  final String? version;

  /// OpenCode found a newer version of this package on npm. It checks at
  /// start and once a day, and installs one only when asked to update.
  final bool outdated;

  bool get isPush =>
      _pluginIds.contains(id) ||
      (package != null && _isPushPackage(package!)) ||
      (path != null && _pluginFiles.contains(_basename(path!)));
}

/// What `GET /api/config` says about the push plugin.
class ComputerConfig {
  const ComputerConfig({this.entries = const [], this.directories = const []});

  /// Reads the configuration documents and sources (lowest priority first).
  factory ComputerConfig.fromEntries(List<Object?> json) {
    final entries = <PushPluginEntry>[];
    final directories = <String>[];
    for (final item in json) {
      if (item is! Map) continue;
      if (item['type'] != 'document') continue;
      final dir = item['path'] is String
          ? _dirname(item['path'] as String)
          : null;
      if (dir != null && !directories.contains(dir)) directories.add(dir);
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
    return ComputerConfig(entries: entries, directories: directories);
  }

  final List<PushPluginEntry> entries;

  /// The folders holding the configuration documents, where the plugin's
  /// settings file can sit.
  final List<String> directories;

  /// Whether some entry leaves its relay or key to the settings file.
  bool get needsSettings =>
      entries.any((e) => e.relay == null || e.key == null);

  /// Fills in what the entries leave out the way the plugin does: from the
  /// settings file, else the public relay. With [loadedFromFolder] (the
  /// plugin runs without an `opencode.json` entry) the file alone counts.
  ComputerConfig withSettings(
    PushSettingsFile? settings, {
    bool loadedFromFolder = false,
  }) {
    PushPluginEntry fill(PushPluginEntry e) => e.relay != null && e.key != null
        ? e
        : PushPluginEntry(
            relay: e.relay ?? settings?.relay ?? defaultPushRelayUrl,
            key: e.key ?? settings?.key,
          );
    return ComputerConfig(
      entries: [
        for (final e in entries) fill(e),
        if (entries.isEmpty && loadedFromFolder && settings?.key != null)
          fill(const PushPluginEntry()),
      ],
      directories: directories,
    );
  }
}

/// The plugin's settings file (`opencode-mobile-push.json`).
class PushSettingsFile {
  const PushSettingsFile({this.relay, this.key});

  static PushSettingsFile? tryParse(String? text) {
    if (text == null) return null;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final map = json;
    String? field(String name) {
      final value = map[name];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return PushSettingsFile(relay: field('relay'), key: field('key'));
  }

  final String? relay;
  final String? key;
}

/// Folders that can hold the plugin's settings file: next to each
/// configuration document, and above the plugins folder a copied plugin
/// file was loaded from.
List<String> pushSettingsDirectories(
  ComputerConfig config,
  List<ServerPlugin> plugins,
) {
  final dirs = [...config.directories];
  for (final p in plugins) {
    final path = p.path;
    if (!p.isPush || path == null) continue;
    final dir = _dirname(_dirname(path) ?? '');
    if (dir != null && !dirs.contains(dir)) dirs.add(dir);
  }
  return dirs;
}

/// The plugin as declared in a configuration document.
class PushPluginEntry {
  const PushPluginEntry({this.relay, this.key});

  /// Null when the plugin takes it from the settings file (or, for the
  /// relay, uses the public one).
  final String? relay;
  final String? key;
}

enum ComputerPluginStatus {
  /// Loaded and running.
  active,

  /// OpenCode tried to load it and failed (see [ComputerPluginCheck.error]).
  failed,

  /// The plugin uses another relay or pairing key.
  otherKey,

  /// Set up, but OpenCode has not loaded it (yet).
  notLoaded,

  /// Not set up on the computer.
  missing,
}

class ComputerPluginCheck {
  const ComputerPluginCheck(
    this.status, {
    this.error,
    this.sharedKey,
    this.updateTarget,
    this.version,
    this.latestVersion,
  });

  final ComputerPluginStatus status;
  final String? error;

  /// The npm target to pass to OpenCode's plugin update when a newer
  /// version of the plugin is out; null when it is current or not a
  /// package.
  final String? updateTarget;

  /// The installed plugin version, when known.
  final String? version;

  /// The newest version on npm, when known.
  final String? latestVersion;

  /// With [ComputerPluginStatus.otherKey]: the pairing key the plugin uses
  /// with this relay. The computer's key is the one that counts, so this
  /// device switches to it.
  final String? sharedKey;
}

ComputerPluginCheck checkComputerPlugin({
  required List<ServerPlugin> plugins,
  required ComputerConfig config,
  required String relayUrl,
  required String key,
  String? latestVersion,
}) {
  final loaded = plugins.where((p) => p.isPush).toList();
  final package = loaded.where((p) => p.package != null).firstOrNull;
  // A pinned version ("opencode-mobile-push@0.3.0") stays as written, so
  // only an unpinned or "@latest" entry can be updated in place.
  final follows =
      package != null &&
      (!package.package!.contains('@', 1) ||
          package.package!.endsWith('@latest'));
  final behind =
      package != null &&
      (package.outdated ||
          (latestVersion != null &&
              package.version != null &&
              latestVersion != package.version));
  ComputerPluginCheck result(
    ComputerPluginStatus status, {
    String? error,
    String? sharedKey,
  }) => ComputerPluginCheck(
    status,
    error: error,
    sharedKey: sharedKey,
    updateTarget: follows && behind ? package.package : null,
    version: package?.version,
    latestVersion: latestVersion,
  );

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

String? _dirname(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  return cut > 0 ? path.substring(0, cut) : null;
}

String _basename(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
  return parts.isEmpty ? '' : parts.last;
}
