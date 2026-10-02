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
