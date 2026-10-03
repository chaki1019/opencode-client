import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Short relative time, e.g. "3 minutes ago", "Yesterday", or a date.
String relativeTime(AppLocalizations l10n, DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 2) return l10n.yesterday;
  if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
  return DateFormat.yMd(l10n.localeName).format(time);
}

/// A USD amount such as "$0.02", or "<$0.01" for a tiny non-zero spend.
String formatCost(double cost) {
  if (cost > 0 && cost < 0.005) return r'<$0.01';
  return '\$${cost.toStringAsFixed(2)}';
}

/// A count with thousands separators for [locale], e.g. "59,412".
String formatCount(int count, String locale) =>
    NumberFormat.decimalPattern(locale).format(count);
