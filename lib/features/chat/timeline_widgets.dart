import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/models/timeline.dart';
import '../../core/paging.dart';

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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  entry.text,
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                for (final file in entry.files)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
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
                            style: TextStyle(color: scheme.onPrimaryContainer),
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
            final TextContent c when c.text.trim().isNotEmpty => MarkdownBody(
              data: c.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                code: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
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
          const SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
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
    return ExpansionTile(
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
    );
  }
}

class ToolCallView extends StatelessWidget {
  const ToolCallView({super.key, required this.tool});

  final ToolContent tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (tool.status) {
      ToolStatus.completed => (Icons.check_circle_outline, Colors.green),
      ToolStatus.error => (Icons.error_outline, theme.colorScheme.error),
      ToolStatus.running ||
      ToolStatus.pending => (Icons.timelapse, theme.colorScheme.outline),
    };
    final detail = tool.errorMessage ?? tool.output;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        dense: true,
        shape: const Border(),
        leading: Icon(icon, color: color, size: 18),
        title: Text(tool.name, style: theme.textTheme.labelLarge),
        subtitle: tool.subject == null
            ? null
            : Text(
                tool.subject!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail != null && detail.isNotEmpty)
            MonospaceBlock(text: detail)
          else
            Text('出力なし', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class ShellEntryView extends StatelessWidget {
  const ShellEntryView({super.key, required this.entry});

  final ShellEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.isRunning
                      ? Icons.timelapse
                      : entry.succeeded
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 18,
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
    return ExpansionTile(
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
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
