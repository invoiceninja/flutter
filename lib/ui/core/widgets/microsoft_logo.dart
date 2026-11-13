import 'package:flutter/widgets.dart';

/// Microsoft's four-square logo, for the "Sign in / Sign up with Microsoft"
/// buttons. Drawn, sized and kept off the theme for the same reasons as
/// `GoogleLogo`: the colours are Microsoft's brand colours, fixed in light and
/// dark mode alike, and the squares ink the same share of the slot as the G
/// beside them.
class MicrosoftLogo extends StatelessWidget {
  const MicrosoftLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _MicrosoftLogoPainter()),
      ),
    );
  }
}

class _MicrosoftLogoPainter extends CustomPainter {
  const _MicrosoftLogoPainter();

  // Microsoft's logo on a 23-unit grid: four 10-unit squares, one unit apart,
  // inset one unit from the edge.
  static const _squares = <(double, double, Color)>[
    (1, 1, Color(0xFFF25022)),
    (12, 1, Color(0xFF7FBA00)),
    (1, 12, Color(0xFF00A4EF)),
    (12, 12, Color(0xFFFFB900)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ink = size.shortestSide * 0.75;
    canvas
      ..translate((size.width - ink) / 2, (size.height - ink) / 2)
      ..scale(ink / 23);
    for (final (x, y, color) in _squares) {
      canvas.drawRect(Rect.fromLTWH(x, y, 10, 10), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
