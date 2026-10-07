import 'package:flutter/material.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';

/// Parses a category's stored `#rrggbb` into a [Color]. Null for anything
/// else — a blank field, a three-digit shorthand, a name — so a caller draws
/// no swatch rather than a wrong one.
///
/// The app's one hex parser (`parseHexColor`), not a second copy of it.
Color? expenseCategoryColor(String raw) => parseHexColor(raw);

/// The category's colour as a small rounded square — never a circle or a
/// pill, per the design system's shape rule — with a hairline border so a
/// colour close to the surface it sits on still has an edge.
class ExpenseCategorySwatch extends StatelessWidget {
  const ExpenseCategorySwatch({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(InRadii.r1 / 2),
        border: Border.all(color: context.inTheme.border),
      ),
    );
  }
}
