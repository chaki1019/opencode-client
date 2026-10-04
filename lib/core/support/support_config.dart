/// Build-time support settings, passed with
/// `--dart-define-from-file=app.env.json` (see docs/support.md). Rows whose
/// value is missing are not shown.
class SupportConfig {
  const SupportConfig({this.email = '', this.siteUrl = ''});

  const SupportConfig.fromEnvironment()
    : email = const String.fromEnvironment('SUPPORT_EMAIL'),
      siteUrl = const String.fromEnvironment('SITE_URL');

  /// Where "Contact us" sends mail.
  final String email;

  /// The public site holding the privacy policy (`/ja/privacy/` and
  /// `/en/privacy/`).
  final String siteUrl;

  Uri? privacyPolicy(String languageCode) => _page(languageCode, 'privacy/');

  /// The guide to the ways of reaching a server (`/ja/connect/`,
  /// `/en/connect/`).
  Uri? connectGuide(String languageCode) => _page(languageCode, 'connect/');

  Uri? _page(String languageCode, String path) {
    if (siteUrl.isEmpty) return null;
    final base = siteUrl.endsWith('/') ? siteUrl : '$siteUrl/';
    return Uri.parse(base)
        .resolve('${languageCode == 'ja' ? 'ja' : 'en'}/$path');
  }

  /// A new mail to support with [subject] and [body] filled in.
  Uri? contactMail({required String subject, required String body}) {
    if (email.isEmpty) return null;
    // Encoded by hand: Uri's query encoding turns spaces into `+`, which
    // mail apps show as is.
    return Uri.parse(
      'mailto:$email'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
  }
}
