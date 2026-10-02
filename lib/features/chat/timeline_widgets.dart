import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../app/theme.dart';
import '../../core/models/prompts.dart';
import '../../core/models/timeline.dart';
import '../../core/paging.dart';
import '../live/live_widgets.dart';
import 'composer_providers.dart';
import 'expand_downward.dart';
import 'prompt_widgets.dart';

class TimelineEntryView extends StatelessWidget {
  const TimelineEntryView({super.key, required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) => switch (entry) {
    final UserEntry e => UserMessageBubble(entry: e),
    final AssistantEntry e => AssistantMessageView(entry: e),
    final CompactionEntry e => CompactionView(entry: e),
    final ShellEntry e => ShellEntryView(entry: e),
    final ContextEntry e => ContextCaption(entry: e),
  };
}

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({super.key, required this.entry});

  final UserEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.text.isNotEmpty)
                  SelectableText(
                    entry.text,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                for (final file in entry.files)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: file.isImage && file.base64Data != null
                        ? _InlineImage(base64Data: file.base64Data!)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 16,
                                color: scheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  file.name ?? file.mime ?? 'file',
                                  style: TextStyle(
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An attached image, decoded once.
class _InlineImage extends StatefulWidget {
  const _InlineImage({required this.base64Data});

  final String base64Data;

  @override
  State<_InlineImage> createState() => _InlineImageState();
}

class _InlineImageState extends State<_InlineImage> {
  late Uint8List? _bytes = _decode();

  Uint8List? _decode() {
    try {
      return base64Decode(widget.base64Data);
    } on FormatException {
      return null;
    }
  }

  @override
  void didUpdateWidget(_InlineImage old) {
    super.didUpdateWidget(old);
    if (old.base64Data != widget.base64Data) _bytes = _decode();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const Icon(Icons.broken_image_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

/// A prompt the user sent that the server has not shown in the transcript
/// yet. An uncertain send is labelled rather than resent.
class PendingPromptBubble extends StatelessWidget {
  const PendingPromptBubble({
    super.key,
    required this.prompt,
    required this.onDismiss,
  });

  final PendingPrompt prompt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = switch (prompt.status) {
      PendingStatus.sending => '送信中…',
      PendingStatus.uncertain => '送信できたか確認中です。再送はしていません',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Opacity(
          opacity: 0.6,
          child: UserMessageBubble(
            entry: UserEntry(
              id: prompt.id,
              text: prompt.text,
              files: [
                for (final f in prompt.files)
                  AttachedFile(
                    name: f.name,
                    mime: f.mime,
                    base64Data: base64Encode(f.bytes),
                  ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(status, style: theme.textTheme.labelSmall),
            if (prompt.status != PendingStatus.sending)
              IconButton(
                tooltip: '表示から消す',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ],
    );
  }
}

class AssistantMessageView extends StatelessWidget {
  const AssistantMessageView({super.key, required this.entry});

  final AssistantEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = [?entry.agent, ?entry.model?.label].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final content in entry.content)
          switch (content) {
            final TextContent c when c.text.trim().isNotEmpty => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: MarkdownBody(
                data: c.text,
                selectable: true,
                styleSheet: _markdownStyle(context),
              ),
            ),
            TextContent() => const SizedBox.shrink(),
            final ReasoningContent c => ReasoningView(text: c.text),
            final ToolContent c => ToolCallView(tool: c),
          },
        if (entry.isStreaming && !_hasVisibleText(entry))
          const _ThinkingIndicator(),
        if (entry.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              entry.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption, style: theme.textTheme.labelSmall),
          ),
      ],
    );
  }
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final colors = AppColors.of(context);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
    code: theme.textTheme.bodySmall?.copyWith(
      fontFamily: AppFonts.mono,
      backgroundColor: colors.code,
    ),
    codeblockDecoration: BoxDecoration(
      color: colors.code,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colorScheme.outline, width: 2),
      ),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
    ),
  );
}

bool _hasVisibleText(AssistantEntry entry) => entry.content.any(
  (c) => c is ToolContent || (c is TextContent && c.text.trim().isNotEmpty),
);

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const LiveDot(size: 7),
          const SizedBox(width: 8),
          Text('考え中…', style: style),
        ],
      ),
    );
  }
}

/// Model reasoning, collapsed by default.
class ReasoningView extends StatelessWidget {
  const ReasoningView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ExpandDownward(
      builder: (context, onExpansionChanged) => ExpansionTile(
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.psychology_outlined, size: 18),
        title: Text('思考', style: theme.textTheme.labelLarge),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          Text(
            text.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class ToolCallView extends StatelessWidget {
  const ToolCallView({super.key, required this.tool});

  final ToolContent tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final (icon, color) = switch (tool.status) {
      ToolStatus.completed => (Icons.check, colors.success),
      ToolStatus.error => (Icons.close, scheme.error),
      ToolStatus.running => (Icons.more_horiz, colors.running),
      ToolStatus.pending => (Icons.more_horiz, scheme.outline),
    };
    final detail = tool.errorMessage ?? tool.output;
    final todos = TodoItem.isTodoTool(tool.name)
        ? TodoItem.fromToolInput(tool.input)
        : null;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: AppFonts.mono,
      fontSize: 12,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2, color: color),
            Expanded(
              child: ExpandDownward(
                builder: (context, onExpansionChanged) => ExpansionTile(
                  onExpansionChanged: onExpansionChanged,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  tilePadding: const EdgeInsets.only(left: 8, right: 4),
                  minTileHeight: 36,
                  title: Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: tool.name,
                                style: mono?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (tool.subject != null)
                                TextSpan(
                                  text: '  ${tool.subject}',
                                  style: mono?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  expandedAlignment: Alignment.centerLeft,
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (todos != null)
                      TodoList(todos: todos)
                    else if (detail != null && detail.isNotEmpty)
                      MonospaceBlock(text: detail)
                    else
                      Text('出力なし', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShellEntryView extends StatelessWidget {
  const ShellEntryView({super.key, required this.entry});

  final ShellEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      color: colors.code,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.isRunning
                      ? Icons.more_horiz
                      : entry.succeeded
                      ? Icons.check
                      : Icons.close,
                  size: 16,
                  color: entry.isRunning
                      ? colors.running
                      : entry.succeeded
                      ? colors.success
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: MonospaceBlock(text: '\$ ${entry.command}')),
              ],
            ),
            if (entry.output?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              MonospaceBlock(text: entry.output!),
            ],
          ],
        ),
      ),
    );
  }
}

class CompactionView extends StatelessWidget {
  const CompactionView({super.key, required this.entry});

  final CompactionEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExpandDownward(
      builder: (context, onExpansionChanged) => ExpansionTile(
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.compress, size: 18),
        title: Text(
          'ここまでの会話を要約しました',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        children: [
          if (entry.summary.isNotEmpty) MarkdownBody(data: entry.summary),
        ],
      ),
    );
  }
}

class ContextCaption extends StatelessWidget {
  const ContextCaption({super.key, required this.entry});

  final ContextEntry entry;

  @override
  Widget build(BuildContext context) {
    final label = switch (entry.kind) {
      'agent-switched' => 'エージェント: ${entry.text}',
      'model-switched' => 'モデル: ${entry.text}',
      'location-switched' => '場所: ${entry.text}',
      'skill' => 'スキル: ${entry.text}',
      _ => entry.text,
    };
    return Center(
      child: Text(
        label,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class MonospaceBlock extends StatelessWidget {
  const MonospaceBlock({super.key, required this.text, this.maxLines = 40});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final shown = lines.length > maxLines
        ? '${lines.take(maxLines).join('\n')}\n… (${lines.length - maxLines} 行省略)'
        : text;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SelectableText(
        shown,
        style: const TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }
}

class OlderHistoryIndicator extends StatelessWidget {
  const OlderHistoryIndicator({
    super.key,
    required this.paged,
    required this.onRetry,
  });

  final PagedItems<Object?> paged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (paged.loadMoreError != null) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: const Text('過去のメッセージを再読み込み'),
        ),
      );
    }
    if (!paged.hasMore) return const SizedBox(height: 8);
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
