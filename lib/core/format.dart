/// Short Japanese relative time, e.g. "3分前", "昨日", "2026/09/01".
String relativeTime(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inHours < 1) return '${diff.inMinutes}分前';
  if (diff.inDays < 1) return '${diff.inHours}時間前';
  if (diff.inDays < 2) return '昨日';
  if (diff.inDays < 7) return '${diff.inDays}日前';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${time.year}/${two(time.month)}/${two(time.day)}';
}
