import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/update/app_version.dart';
import 'package:opencode_mobile/core/update/update_checker.dart';

import '../../support/fake_adapter.dart';

void main() {
  AppVersion v(String text) => AppVersion.tryParse(text)!;

  test('versions compare part by part, ignoring build and pre-release', () {
    expect(v('1.2.3') < v('1.10.0'), isTrue);
    expect(v('1.2').compareTo(v('1.2.0')), 0);
    expect(v('1.2.3+45').compareTo(v('1.2.3')), 0);
    expect(v('2.0.0-beta').compareTo(v('2.0.0')), 0);
    expect(v('1.0.1') < v('1.0.0'), isFalse);
    expect(AppVersion.tryParse(''), isNull);
    expect(AppVersion.tryParse('abc'), isNull);
    expect(AppVersion.tryParse(null), isNull);
  });

  test('policy reads one platform and tolerates bad input', () {
    final json = {
      'ios': {'minimum': '1.2.0', 'storeUrl': 'https://apps.apple.com/app/id1'},
      'android': {'minimum': null, 'storeUrl': null},
    };
    final ios = UpdatePolicy.fromJson(json, 'ios');
    expect(ios.requiresUpdate(v('1.1.9')), isTrue);
    expect(ios.requiresUpdate(v('1.2.0')), isFalse);
    expect(ios.storeUrl, 'https://apps.apple.com/app/id1');
    expect(UpdatePolicy.fromJson(json, 'android').minimum, isNull);
    expect(UpdatePolicy.fromJson('nope', 'ios').minimum, isNull);
    expect(
      UpdatePolicy.fromJson({
        'ios': {'minimum': 3},
      }, 'ios').minimum,
      isNull,
    );
  });

  test('check URL prefers the override, then the relay', () {
    expect(updateCheckUrl(override: '', relayUrl: ''), isNull);
    expect(
      updateCheckUrl(override: '', relayUrl: 'https://relay.dev/'),
      'https://relay.dev/v1/app-version',
    );
    expect(
      updateCheckUrl(override: 'https://x.dev/v.json', relayUrl: 'https://r'),
      'https://x.dev/v.json',
    );
  });

  group('UpdateChecker', () {
    const url = 'https://relay.test/v1/app-version';

    UpdateChecker checker(Object route) =>
        UpdateChecker(url, dio: fakeDio(FakeAdapter({url: route})));

    test('reports an installed version below the minimum', () async {
      final result = await checker(
        FakeRoute.json({
          'android': {'minimum': '1.3.0', 'storeUrl': 'https://play/x'},
        }),
      ).check(installedVersion: '1.2.9', platform: 'android');
      expect(result!.minimum.toString(), '1.3.0');
      expect(result.installed.toString(), '1.2.9');
      expect(result.storeUrl, 'https://play/x');
    });

    test('lets the app run when up to date or the check fails', () async {
      final body = FakeRoute.json({
        'android': {'minimum': '1.3.0'},
      });
      expect(
        await checker(body)
            .check(installedVersion: '1.3.0', platform: 'android'),
        isNull,
      );
      expect(
        await checker(body).check(installedVersion: '1.0.0', platform: 'ios'),
        isNull,
      );
      expect(
        await checker(const FakeRoute(500, 'oops', contentType: 'text/plain'))
            .check(installedVersion: '1.0.0', platform: 'android'),
        isNull,
      );
      expect(
        await checker(const FakeRoute(200, '<html>', contentType: 'text/html'))
            .check(installedVersion: '1.0.0', platform: 'android'),
        isNull,
      );
    });
  });
}
