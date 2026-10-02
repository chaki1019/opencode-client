import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app/theme.dart';

void main() {
  test('screens slide in on both mobile platforms', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final builders = theme.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.android],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    }
  });
}
