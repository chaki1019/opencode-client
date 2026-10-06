import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/push/computer_plugin.dart';

const _relay = 'https://relay.test';
const _key = 'k';

Map<String, Object?> _plugin(Map<String, Object?> source, {String? error}) => {
  'id': 'opencode-mobile-push',
  'source': source,
  'features': {'server': true},
  'state': error == null
      ? {'status': 'active'}
      : {'status': 'failed', 'error': error},
};

Map<String, Object?> _doc(List<Object?> plugins) => {
  'type': 'document',
  'path': '/Users/me/.config/opencode/opencode.json',
  'info': {'plugins': plugins},
};

ComputerPluginStatus _status({
  List<Map<String, Object?>> plugins = const [],
  List<Map<String, Object?>> config = const [],
}) => checkComputerPlugin(
  plugins: [for (final p in plugins) ServerPlugin.tryParse(p)!],
  config: ComputerConfig.fromEntries(config),
  relayUrl: _relay,
  key: _key,
).status;

void main() {
  test('nothing on the computer is missing', () {
    expect(_status(), ComputerPluginStatus.missing);
    // Other plugins don't count.
    expect(
      _status(
        plugins: [
          {
            'source': {'type': 'package', 'target': 'opencode-wakatime'},
            'features': {},
            'state': {'status': 'active'},
          },
        ],
      ),
      ComputerPluginStatus.missing,
    );
  });

  test('the npm package with this key is active', () {
    expect(
      _status(
        plugins: [
          _plugin({'type': 'package', 'target': 'opencode-mobile-push@0.2.0'}),
        ],
        config: [
          _doc([
            {
              'package': 'opencode-mobile-push',
              'options': {'relay': '$_relay/', 'key': _key},
            },
          ]),
        ],
      ),
      ComputerPluginStatus.active,
    );
  });

  test('a copied file loaded from the plugins folder is active', () {
    expect(
      _status(
        plugins: [
          _plugin({
            'type': 'local',
            'path':
                '/Users/me/.config/opencode/plugins/opencode-mobile-push.js',
          }),
        ],
      ),
      ComputerPluginStatus.active,
    );
  });

  test('another key in opencode.json is reported', () {
    expect(
      _status(
        plugins: [
          _plugin({'type': 'package', 'target': 'opencode-mobile-push'}),
        ],
        config: [
          _doc([
            {
              'package': 'opencode-mobile-push',
              'options': {'relay': _relay, 'key': 'old'},
            },
          ]),
        ],
      ),
      ComputerPluginStatus.otherKey,
    );
  });

  test('another key for this relay can be shared, one for another cannot', () {
    final shared = 'S' * 43;
    ComputerPluginCheck check(String relay, String key) => checkComputerPlugin(
      plugins: const [],
      config: ComputerConfig.fromEntries([
        _doc([
          {
            'package': 'opencode-mobile-push',
            'options': {'relay': relay, 'key': key},
          },
        ]),
      ]),
      relayUrl: _relay,
      key: _key,
    );
    expect(check('$_relay/', shared).sharedKey, shared);
    expect(check('https://elsewhere.test', shared).sharedKey, isNull);
    // Too short for the relay to accept.
    expect(check(_relay, 'old').sharedKey, isNull);
  });

  test('a load failure carries its error', () {
    final check = checkComputerPlugin(
      plugins: [
        ServerPlugin.tryParse(
          _plugin({
            'type': 'package',
            'target': 'opencode-mobile-push',
          }, error: 'install failed'),
        )!,
      ],
      config: const ComputerConfig(),
      relayUrl: _relay,
      key: _key,
    );
    expect(check.status, ComputerPluginStatus.failed);
    expect(check.error, 'install failed');
  });

  test('configured but not loaded asks for a restart', () {
    expect(
      _status(
        config: [
          _doc([
            {
              'package': 'opencode-mobile-push',
              'options': {'relay': _relay, 'key': _key},
            },
          ]),
        ],
      ),
      ComputerPluginStatus.notLoaded,
    );
  });

  test('the settings file fills in what opencode.json leaves out', () {
    final config = ComputerConfig.fromEntries([
      _doc(['opencode-mobile-push']),
    ]);
    expect(config.directories, ['/Users/me/.config/opencode']);
    expect(config.needsSettings, isTrue);

    final filled = config.withSettings(
      PushSettingsFile.tryParse('{"key": " ${'K' * 43} "}'),
    );
    expect(filled.entries.single.relay, defaultPushRelayUrl);
    expect(filled.entries.single.key, 'K' * 43);
    final check = checkComputerPlugin(
      plugins: const [],
      config: filled,
      relayUrl: defaultPushRelayUrl,
      key: _key,
    );
    expect(check.status, ComputerPluginStatus.otherKey);
    expect(check.sharedKey, 'K' * 43);

    // Unreadable: the relay still defaults, the key stays unknown.
    expect(config.withSettings(null).entries.single.key, isNull);
    expect(PushSettingsFile.tryParse('not json'), isNull);
  });

  test('a copied plugin file counts its settings file on its own', () {
    final plugin = ServerPlugin.tryParse(
      _plugin({
        'type': 'local',
        'path': '/Users/me/.config/opencode/plugins/opencode-mobile-push.js',
      }),
    )!;
    const config = ComputerConfig();
    expect(pushSettingsDirectories(config, [plugin]), [
      '/Users/me/.config/opencode',
    ]);
    final filled = config.withSettings(
      const PushSettingsFile(relay: _relay, key: 'k'),
      loadedFromFolder: true,
    );
    expect(
      checkComputerPlugin(
        plugins: [plugin],
        config: filled,
        relayUrl: _relay,
        key: _key,
      ).status,
      ComputerPluginStatus.active,
    );
  });

  test('an unpinned plugin behind npm can be updated, a pinned one cannot', () {
    ComputerPluginCheck check(
      String target, {
      String? version,
      bool outdated = false,
      String? latest,
    }) => checkComputerPlugin(
      plugins: [
        ServerPlugin.tryParse({
          'id': 'opencode-mobile-push',
          'source': {
            'type': 'package',
            'target': target,
            'version': ?version,
            if (outdated) 'outdated': true,
          },
          'features': {'server': true},
          'state': {'status': 'active'},
        })!,
      ],
      config: const ComputerConfig(),
      relayUrl: _relay,
      key: _key,
      latestVersion: latest,
    );

    final behind = check(
      'opencode-mobile-push',
      version: '0.2.0',
      latest: '0.3.0',
    );
    expect(behind.updateTarget, 'opencode-mobile-push');
    expect(behind.version, '0.2.0');
    expect(behind.latestVersion, '0.3.0');
    // OpenCode's own check counts even when npm can't be reached.
    expect(
      check('opencode-mobile-push@latest', outdated: true).updateTarget,
      'opencode-mobile-push@latest',
    );
    expect(
      check(
        'opencode-mobile-push',
        version: '0.3.0',
        latest: '0.3.0',
      ).updateTarget,
      isNull,
    );
    expect(
      check(
        'opencode-mobile-push@0.2.0',
        version: '0.2.0',
        latest: '0.3.0',
      ).updateTarget,
      isNull,
    );
  });
}
