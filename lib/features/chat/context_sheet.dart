import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models/catalog.dart';
import '../../core/models/session.dart';
import '../../core/models/timeline.dart';
import '../../l10n/l10n.dart';
import '../connection/connection_providers.dart';
import 'chat_providers.dart';
import 'composer_providers.dart';

/// How full the model's context window is, from the latest reply.
class ContextUsage {
  const ContextUsage({this.tokens, this.model, this.option, this.lastActive});

  /// Tokens of the latest finished reply; null before the first one.
  final TokenUsage? tokens;
  final ModelRef? model;

  /// The catalog entry for [model], when the server lists it.
  final ModelOption? option;

  /// Epoch milliseconds of the latest reply.
  final double? lastActive;

  int? get limit => option?.contextLimit;

  /// 0..1, or null when the tokens or the limit are unknown.
  double? get fraction {
    final used = tokens?.total;
    final max = limit;
    if (used == null || max == null || max <= 0) return null;
    return (used / max).clamp(0.0, 1.0);
  }
}

final contextUsageProvider = Provider.autoDispose.family<ContextUsage, Session>(
  (ref, session) {
    final entries =
        ref.watch(timelineProvider(session.id)).value?.items ?? const [];
    AssistantEntry? last;
    for (final entry in entries.reversed) {
      if (entry is AssistantEntry && entry.tokens != null) {
        last = entry;
        break;
      }
    }
    final model =
        last?.model ?? ref.watch(sessionSettingsProvider(session)).model;
    final options =
        ref.watch(modelsProvider(session.location.directory)).value ??
        const <ModelOption>[];
    ModelOption? option;
    if (model != null) {
      for (final o in options) {
        if (o.providerID == model.providerID && o.id == model.id) {
          option = o;
          break;
        }
      }
    }
    return ContextUsage(
      tokens: last?.tokens,
      model: model,
      option: option,
      lastActive: last?.completed ?? last?.created,
    );
  },
);

/// The latest session record, for its running cost and token totals.
final sessionDetailsProvider = FutureProvider.autoDispose
    .family<Session?, String>((ref, sessionId) async {
      final client = ref.watch(connectionProvider)?.client;
      if (client == null) return null;
      return client.getSession(sessionId);
    });

/// A small ring in the app bar showing how full the context is. Opens the
/// usage sheet.
class ContextUsageButton extends ConsumerWidget {
  const ContextUsageButton({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(contextUsageProvider(session));
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      key: const Key('context-usage'),
      tooltip: context.l10n.usageTooltip,
      onPressed: () => showContextSheet(context, session),
      icon: UsageRing(
        fraction: usage.fraction ?? 0,
        size: 20,
        strokeWidth: 3,
        color: _ringColor(context, usage.fraction),
        trackColor: scheme.outlineVariant,
      ),
    );
  }
}

/// Running color while there is room, then warning and error tones as the
/// window fills up.
Color _ringColor(BuildContext context, double? fraction) {
  final scheme = Theme.of(context).colorScheme;
  if (fraction == null || fraction < 0.7) return AppColors.of(context).running;
  if (fraction < 0.9) return scheme.tertiary;
  return scheme.error;
}

Future<void> showContextSheet(BuildContext context, Session session) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ContextSheet(session: session),
      ),
    );

/// Tokens, cost and context usage of one session.
class ContextSheet extends ConsumerWidget {
  const ContextSheet({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = l10n.localeName;
    final usage = ref.watch(contextUsageProvider(session));
    final details = ref.watch(sessionDetailsProvider(session.id)).value;
    final current = details ?? session;
    final tokens = usage.tokens;
    final fraction = usage.fraction;
    String count(int n) => formatCount(n, locale);
    String percent(double f) => NumberFormat.percentPattern(locale).format(f);
    String date(double ms) =>
        DateFormat.yMMMd(locale)
            .add_Hm()
            .format(DateTime.fromMillisecondsSinceEpoch(ms.round()));
    const dash = '—';

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            l10n.usageTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UsageRing(
                    fraction: fraction ?? 0,
                    size: 56,
                    strokeWidth: 6,
                    color: _ringColor(context, fraction),
                    trackColor: scheme.outlineVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fraction == null ? dash : percent(fraction),
                          key: const Key('context-percent'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          tokens == null
                              ? l10n.usageNoReplies
                              : l10n.usageTokensUsed(count(tokens.total)),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (current.cost != null)
                          Text(
                            formatCost(current.cost!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Section(
            title: l10n.usageTitle,
            footer: tokens == null ? null : l10n.usageLastStepHelp,
            rows: [
              (
                l10n.usageProvider,
                usage.option?.providerName ?? usage.model?.providerID ?? dash,
              ),
              (l10n.usageModel, usage.option?.name ?? usage.model?.id ?? dash),
              (
                l10n.usageLimit,
                usage.limit == null ? dash : count(usage.limit!),
              ),
              (
                l10n.usageTotalTokens,
                tokens == null ? dash : count(tokens.total),
              ),
              (l10n.usagePercent, fraction == null ? dash : percent(fraction)),
              (
                l10n.usageInputTokens,
                tokens == null ? dash : count(tokens.input),
              ),
              (
                l10n.usageOutputTokens,
                tokens == null ? dash : count(tokens.output),
              ),
              (
                l10n.usageReasoningTokens,
                tokens == null ? dash : count(tokens.reasoning),
              ),
              (
                l10n.usageCacheTokens,
                tokens == null
                    ? dash
                    : '${count(tokens.cache.read)} / ${count(tokens.cache.write)}',
              ),
              (
                l10n.usageLastActivity,
                usage.lastActive == null ? dash : date(usage.lastActive!),
              ),
            ],
          ),
          _Section(
            title: l10n.sessionUsage,
            rows: [
              (
                l10n.sessionCost,
                current.cost == null ? dash : formatCost(current.cost!),
              ),
              if (current.tokens case final total?) ...[
                (l10n.usageTotalTokens, count(total.total)),
                (l10n.usageInputTokens, count(total.input)),
                (l10n.usageOutputTokens, count(total.output)),
                (l10n.usageReasoningTokens, count(total.reasoning)),
                (
                  l10n.usageCacheTokens,
                  '${count(total.cache.read)} / ${count(total.cache.write)}',
                ),
              ],
              (l10n.sessionCreated, date(current.time.created)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A titled group of label/value rows on a card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.footer});

  final String title;
  final List<(String, String)> rows;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(color: muted),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, (label, value)) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text(label)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

/// A circular gauge filled clockwise from the top.
class UsageRing extends StatelessWidget {
  const UsageRing({
    super.key,
    required this.fraction,
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        fraction: fraction,
        strokeWidth: strokeWidth,
        color: color,
        trackColor: trackColor,
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = trackColor);
    if (fraction <= 0) return;
    // Even a sliver of use shows as a visible dot.
    final sweep = math.max(fraction * 2 * math.pi, 0.01);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.trackColor != trackColor;
}
