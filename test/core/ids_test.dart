import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/ids.dart';

void main() {
  test('message IDs have the OpenCode shape', () {
    final id = OpenCodeIds().message();
    expect(id, matches(RegExp(r'^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$')));
  });

  test('IDs ascend within and across milliseconds', () {
    var now = 1700000000000;
    final ids = OpenCodeIds(random: Random(1), clock: () => now);
    final a = ids.message();
    final b = ids.message();
    now++;
    final c = ids.message();
    String time(String id) => id.substring(4, 16);
    expect(time(a).compareTo(time(b)), lessThan(0));
    expect(time(b).compareTo(time(c)), lessThan(0));
    // The time part encodes (millis << 12 | counter) in 48 bits.
    final expected =
        (BigInt.from(1700000000000) << 12 | BigInt.one) &
        ((BigInt.one << 48) - BigInt.one);
    expect(time(a), expected.toRadixString(16).padLeft(12, '0'));
  });
}
