import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as tabs;
import 'package:url_launcher/url_launcher.dart';

/// Opens a web page in a browser sheet that slides up over the app: a
/// Safari page sheet on iOS, a partial Custom Tab on Android. Falls back to
/// the default browser when the sheet can't be shown. False when nothing
/// could open the page.
Future<bool> openWebSheet(BuildContext context, Uri uri) async {
  final scheme = Theme.of(context).colorScheme;
  final height = MediaQuery.sizeOf(context).height;
  try {
    await tabs.launchUrl(
      uri,
      customTabsOptions: tabs.CustomTabsOptions.partial(
        configuration: tabs.PartialCustomTabsConfiguration.bottomSheet(
          initialHeight: height * 0.9,
          cornerRadius: 16,
        ),
        colorSchemes: tabs.CustomTabsColorSchemes.defaults(
          toolbarColor: scheme.surface,
        ),
        showTitle: true,
      ),
      safariVCOptions: tabs.SafariViewControllerOptions.pageSheet(
        configuration: const tabs.SheetPresentationControllerConfiguration(
          detents: {tabs.SheetPresentationControllerDetent.large},
          prefersGrabberVisible: true,
        ),
        dismissButtonStyle: tabs.SafariViewControllerDismissButtonStyle.close,
      ),
    );
    return true;
  } catch (_) {
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
  }
}
