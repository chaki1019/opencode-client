import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Widest a chat transcript and its input get, so lines stay readable on
/// tablets.
const double chatMaxWidth = 760;

/// Widest a form or settings list gets.
const double formMaxWidth = 560;

/// Side padding that centers content no wider than [maxWidth] in the
/// window, and is never less than [min].
double readableSide(
  BuildContext context, {
  double min = 0,
  double maxWidth = formMaxWidth,
}) => math.max(min, (MediaQuery.sizeOf(context).width - maxWidth) / 2);

/// Centers [child] and caps its width at [maxWidth].
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    this.maxWidth = chatMaxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
