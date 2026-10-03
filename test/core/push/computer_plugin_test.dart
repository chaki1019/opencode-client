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
}
