import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/features/chat/timeline_widgets.dart';
import 'package:opencode_mobile/features/files/files_providers.dart';
import 'package:opencode_mobile/features/files/files_screen.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    String path,
    FileContent content,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileContentProvider.overrideWith((ref, key) async => content),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FileViewerScreen(
            directory: '/repo',
            entry: FsEntry(path: path, isDirectory: false),
          ),
        ),
      ),
    );
    // Image and SVG decoding run outside the fake async zone.
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws an SVG instead of decoding it as a raster image', (
    tester,
  ) async {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">'
        '<rect width="10" height="10" fill="red"/></svg>';
    await open(
      tester,
      'logo.svg',
      FileContent(
        bytes: utf8.encode(svg),
        mimeType: 'image/svg+xml',
        text: svg,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the source of an SVG that cannot be drawn', (
    tester,
  ) async {
    const broken = '<svg><not closed';
    await open(
      tester,
      'broken.svg',
      FileContent(
        bytes: utf8.encode(broken),
        mimeType: 'image/svg+xml',
        text: broken,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(MonospaceBlock), findsOneWidget);
  });

  testWidgets('shows the size of an image format it cannot decode', (
    tester,
  ) async {
    await open(
      tester,
      'photo.heic',
      FileContent(bytes: List.filled(32, 7), mimeType: 'image/heic'),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('32'), findsOneWidget);
  });
}
