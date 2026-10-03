import 'package:flutter/material.dart';

/// Placeholder transcript shown above the oldest loaded message while older
/// history may still load, so reaching the top shows message shapes rather
/// than a blank gap. About 40% of the screen tall.
class HistorySkeleton extends StatefulWidget {
  const HistorySkeleton({super.key});

  /// Share of the screen height the placeholder fills.
  static const double heightFactor = 0.4;

  @override
  State<HistorySkeleton> createState() => _HistorySkeletonState();
}

class _HistorySkeletonState extends State<HistorySkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.sizeOf(context).height * HistorySkeleton.heightFactor;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: ClipRect(
          child: FadeTransition(
            opacity: Tween(
              begin: 0.45,
              end: 1.0,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            // Anchored to the bottom so the shapes nearest the real
            // transcript are whole; the top ones are cut off.
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              maxHeight: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      const _Reply(lines: [0.92, 0.8, 0.55]),
                      const _Prompt(widthFactor: 0.55),
                      const _Reply(lines: [0.85, 0.4]),
                      const _Prompt(widthFactor: 0.35),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reply extends StatelessWidget {
  const _Reply({required this.lines});

  final List<double> lines;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: width,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
