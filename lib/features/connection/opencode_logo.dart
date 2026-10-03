import 'package:flutter/material.dart';

/// The OpenCode logo mark, drawn from the official brand assets
/// (opencode.ai/brand, `opencode-logo-{light,dark}-square.svg`).
///
/// The mark is a 240x300 frame with a 120x180 window cut out of it, and a
/// 120x120 block sitting in the lower part of that window. Colors follow the
/// official light / dark variants.
class OpenCodeLogo extends StatelessWidget {
  const OpenCodeLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'OpenCode',
      image: true,
      child: CustomPaint(
        size: Size(height * 240 / 300, height),
        painter: _OpenCodeLogoPainter(
          frame: dark ? const Color(0xFFF1ECEC) : const Color(0xFF211E1E),
          block: dark ? const Color(0xFF4B4646) : const Color(0xFFCFCECD),
        ),
      ),
    );
  }
}

class _OpenCodeLogoPainter extends CustomPainter {
  const _OpenCodeLogoPainter({required this.frame, required this.block});

  final Color frame;
  final Color block;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 240, size.height / 300);
    canvas.drawRect(
      const Rect.fromLTRB(60, 120, 180, 240),
      Paint()..color = block,
    );
    final framePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTRB(0, 0, 240, 300))
      ..addRect(const Rect.fromLTRB(60, 60, 180, 240));
    canvas.drawPath(framePath, Paint()..color = frame);
  }

  @override
  bool shouldRepaint(_OpenCodeLogoPainter oldDelegate) =>
      frame != oldDelegate.frame || block != oldDelegate.block;
}
