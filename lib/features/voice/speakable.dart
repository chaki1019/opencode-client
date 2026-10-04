import '../../core/models/timeline.dart';

/// Longest text handed to the voice at once. Android's engine refuses
/// input over about 4,000 characters.
const maxSpokenLength = 3000;

/// The text of the assistant's reply to the latest user message: every
/// text part of the assistant messages after it, in order.
String latestReplyText(List<TimelineEntry> entries) {
  final lastUser = entries.lastIndexWhere((e) => e is UserEntry);
  return [
    for (final entry in entries.skip(lastUser + 1))
      if (entry is AssistantEntry) assistantText(entry),
  ].where((t) => t.isNotEmpty).join('\n\n');
}

/// The visible text of one assistant message, without reasoning or tools.
String assistantText(AssistantEntry entry) => [
  for (final part in entry.content)
    if (part is TextContent && part.text.trim().isNotEmpty) part.text.trim(),
].join('\n\n');

/// [markdown] as plain sentences for reading aloud: code blocks become
/// [codeSkipped], and links, emphasis, headings, list markers and table
/// rules lose their symbols. Cut at [maxSpokenLength] with [truncated].
String speakableText(
  String markdown, {
  required String codeSkipped,
  required String truncated,
}) {
  var text = markdown
      .replaceAll(RegExp(r'```[\s\S]*?(```|$)'), '\n$codeSkipped\n')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*>[ \t]?', multiLine: true), '')
      .replaceAll(RegExp(r'^[ \t]*([-*+]|\d+[.)])[ \t]+', multiLine: true), '')
      .replaceAll(
        RegExp(r'^[ \t]*\|?[ \t:|-]+\|[ \t:|-]*$', multiLine: true),
        '',
      )
      .replaceAll('|', ' ')
      .replaceAll(RegExp(r'(\*\*|__|~~)'), '')
      .replaceAll(RegExp(r'(?<!\w)[*_](?=\S)|(?<=\S)[*_](?!\w)'), '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (text.length > maxSpokenLength) {
    text = '${text.substring(0, maxSpokenLength)}\n$truncated';
  }
  return text;
}
