import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/attachment.dart';

PromptFile file(int size, {String name = 'a.png'}) => PromptFile(
  name: name,
  mime: PromptFile.mimeForName(name),
  bytes: Uint8List(size),
);

void main() {
  test('encodes as a data URL with the file name', () {
    final json = PromptFile(
      name: 'shot.png',
      mime: 'image/png',
      bytes: Uint8List.fromList(utf8.encode('hi')),
    ).toJson();
    expect(json, {'uri': 'data:image/png;base64,aGk=', 'name': 'shot.png'});
  });

  test('guesses image types from the extension', () {
    expect(PromptFile.mimeForName('IMG_1.JPG'), 'image/jpeg');
    expect(PromptFile.mimeForName('a.heic'), 'image/heic');
    expect(PromptFile.mimeForName('noext'), 'application/octet-stream');
  });

  test('enforces count, per-file and total limits', () {
    expect(PromptFile.checkLimits([], [file(10)]), isNull);
    expect(
      PromptFile.checkLimits(List.generate(10, (_) => file(1)), [file(1)]),
      isNotNull,
    );
    expect(
      PromptFile.checkLimits([], [file(PromptFile.maxFileBytes + 1)]),
      isNotNull,
    );
    expect(
      PromptFile.checkLimits(
        [file(9 * 1024 * 1024), file(9 * 1024 * 1024)],
        [file(9 * 1024 * 1024)],
      ),
      isNotNull,
    );
  });
}
