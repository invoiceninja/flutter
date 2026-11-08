import 'package:flutter/widgets.dart';

/// Google's four-colour "G", for the "Sign in / Sign up with Google" buttons.
///
/// Drawn rather than bundled: the app has no SVG renderer, and a painter stays
/// crisp at any size and text scale. The paths are Google's own 48×48 "G" from
/// its Sign-In branding kit, transcribed command for command.
///
/// [size] is the slot, the way an [Icon]'s size is: Material glyphs leave a
/// margin inside it (`Icons.apple` inks about 75% of its box), so the G is
/// drawn at [_inkFraction] of the slot, centred. Without that it filled its
/// whole box and looked a size larger than the Apple logo beside it.
///
/// The colours are Google's brand colours, which its branding guidelines fix
/// in light and dark mode alike — so, unlike every other colour in the app,
/// they deliberately live here rather than in `InTheme` and never theme.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GoogleLogoPainter()),
      ),
    );
  }
}

/// The share of the slot the G inks, matching `Icons.apple` (measured: 135 of
/// 180 px at size 180).
const double _inkFraction = 0.75;

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _red = Color(0xFFEA4335);
  static const _blue = Color(0xFF4285F4);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = size.shortestSide * _inkFraction;
    canvas
      ..translate((size.width - ink) / 2, (size.height - ink) / 2)
      ..scale(ink / 48);
    final paint = Paint()..isAntiAlias = true;

    // M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0
    // 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z
    final red = Path()
      ..moveTo(24, 9.5)
      ..relativeCubicTo(3.54, 0, 6.71, 1.22, 9.21, 3.6)
      ..relativeLineTo(6.85, -6.85)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..relativeLineTo(7.98, 6.19)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();

    // M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26
    // 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z
    final blue = Path()
      ..moveTo(46.98, 24.55)
      ..relativeCubicTo(0, -1.57, -0.15, -3.09, -0.38, -4.55)
      ..lineTo(24, 20)
      ..relativeLineTo(0, 9.02)
      ..relativeLineTo(12.94, 0)
      ..relativeCubicTo(-0.58, 2.96, -2.26, 5.48, -4.78, 7.18)
      ..relativeLineTo(7.73, 6)
      ..relativeCubicTo(4.51, -4.18, 7.09, -10.36, 7.09, -17.65)
      ..close();

    // M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19
    // C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z
    // (the `s` is expanded: its first control point mirrors the previous
    // curve's second, (9.77, 25.60), through (9.77, 24.00)).
    final yellow = Path()
      ..moveTo(10.53, 28.59)
      ..relativeCubicTo(-0.48, -1.45, -0.76, -2.99, -0.76, -4.59)
      ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
      ..relativeLineTo(-7.98, -6.19)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..relativeCubicTo(0, 3.88, 0.92, 7.54, 2.56, 10.78)
      ..relativeLineTo(7.97, -6.19)
      ..close();

    // M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16
    // 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z
    final green = Path()
      ..moveTo(24, 48)
      ..relativeCubicTo(6.48, 0, 11.93, -2.13, 15.89, -5.81)
      ..relativeLineTo(-7.73, -6)
      ..relativeCubicTo(-2.15, 1.45, -4.92, 2.3, -8.16, 2.3)
      ..relativeCubicTo(-6.26, 0, -11.57, -4.22, -13.47, -9.91)
      ..relativeLineTo(-7.98, 6.19)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();

    canvas
      ..drawPath(red, paint..color = _red)
      ..drawPath(blue, paint..color = _blue)
      ..drawPath(yellow, paint..color = _yellow)
      ..drawPath(green, paint..color = _green);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
