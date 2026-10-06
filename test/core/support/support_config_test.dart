import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/support/support_config.dart';
import 'package:opencode_mobile/features/settings/support_section.dart';

void main() {
  test('nothing is offered without build settings', () {
    const config = SupportConfig();
    expect(config.privacyPolicy('ja'), isNull);
    expect(config.connectGuide('ja'), isNull);
    expect(config.contactMail(subject: 's', body: 'b'), isNull);
  });

  test('the privacy policy follows the app language', () {
    for (final site in ['https://x.pages.dev', 'https://x.pages.dev/']) {
      final config = SupportConfig(siteUrl: site);
      expect(
        config.privacyPolicy('ja').toString(),
        'https://x.pages.dev/ja/privacy/',
      );
      expect(
        config.privacyPolicy('en').toString(),
        'https://x.pages.dev/en/privacy/',
      );
      expect(
        config.connectGuide('ja').toString(),
        'https://x.pages.dev/ja/connect/',
      );
    }
  });

  test('the contact mail keeps spaces and line breaks', () {
    const config = SupportConfig(email: 'help@example.com');
    final mail = config.contactMail(
      subject: 'Pocket Agent へのお問い合わせ',
      body: contactBody(prompt: 'Hi there', version: '1.0.0 (1)', os: 'ios 18'),
    )!;
    expect(mail.scheme, 'mailto');
    expect(mail.path, 'help@example.com');
    expect(mail.query, isNot(contains('+')));
    expect(
      Uri.decodeComponent(mail.query.split('&body=').last),
      'Hi there\n\n\n\n---\nApp: 1.0.0 (1)\nOS: ios 18\n',
    );
    expect(
      Uri.decodeComponent(mail.query.split('&').first.substring(8)),
      'Pocket Agent へのお問い合わせ',
    );
  });

  test('builds without settings use the public site and address', () {
    const config = SupportConfig.fromEnvironment();
    expect(
      config.connectGuide('ja').toString(),
      'https://opencodemobile.app/ja/connect/',
    );
    expect(config.email, 'support@opencodemobile.app');
  });
}
