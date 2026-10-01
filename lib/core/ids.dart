import 'dart:math';

/// Generates OpenCode-style ascending IDs (`msg_…`).
///
/// The format is the prefix, 12 hex digits of `(epochMillis << 12 | counter)`
/// truncated to 48 bits, then 14 random base62 characters. IDs created later
/// sort after earlier ones, which the server relies on for ordering.
class OpenCodeIds {
  OpenCodeIds({Random? random, int Function()? clock})
    : _random = random ?? Random.secure(),
      _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const _base62 =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  final Random _random;
  final int Function() _clock;
  int _lastTimestamp = 0;
  int _counter = 0;

  String message() => _ascending('msg');

  String _ascending(String prefix) {
    final timestamp = _clock();
    if (timestamp != _lastTimestamp) {
      _lastTimestamp = timestamp;
      _counter = 0;
    }
    _counter++;
    final value = BigInt.from(timestamp) << 12 | BigInt.from(_counter & 0x0FFF);
    final time = (value & ((BigInt.one << 48) - BigInt.one))
        .toRadixString(16)
        .padLeft(12, '0');
    final random = List.generate(
      14,
      (_) => _base62[_random.nextInt(_base62.length)],
    ).join();
    return '${prefix}_$time$random';
  }
}
