import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/support/support_config.dart';
import 'package:opencode_mobile/features/settings/support_section.dart';

void main() {
  test('nothing is offered without build settings', () {
    const config = SupportConfig();
    expect(config.privacyPolicy('ja'), isNull);
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
    }
  });

  test('the contact mail keeps spaces and line breaks', () {
    const config = SupportConfig(email: 'help@example.com');
    final mail = config.contactMail(
      subject: 'OpenCode Mobile へのお問い合わせ',
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
      'OpenCode Mobile へのお問い合わせ',
    );
  });
}
