import 'package:flutter/material.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/utils/formatting.dart';

/// Parsers that turn React-shaped CSS-string property values into typed
/// Flutter values. Every renderer reads `properties: Map<String, dynamic>`
/// and these helpers project the strings to `Color`, `double`, `TextAlign`,
/// `FontWeight`, `BoxFit`, and `Border` respectively. They are forgiving:
/// `null` / unparseable input falls through to a sensible default so a
/// malformed block doesn't crash the canvas.

/// `'#000000'` / `'#FFF'` / `'rgb(255, 0, 0)'` / `'rgba(255,0,0,.5)'` →
/// `Color`. Returns [fallback] (default: black) on parse failure.
Color parseCssColor(String? css, {Color fallback = const Color(0xFF000000)}) {
  if (css == null) return fallback;
  var s = css.trim();
  if (s.isEmpty) return fallback;

  if (s.startsWith('#')) {
    s = s.substring(1);
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length == 6) s = 'FF$s';
    if (s.length == 8) {
      final parsed = int.tryParse(s, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  final rgbMatch = RegExp(
    r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([0-9.]+)\s*)?\)$',
  ).firstMatch(s);
  if (rgbMatch != null) {
    final r = int.parse(rgbMatch.group(1)!).clamp(0, 255);
    final g = int.parse(rgbMatch.group(2)!).clamp(0, 255);
    final b = int.parse(rgbMatch.group(3)!).clamp(0, 255);
    final aStr = rgbMatch.group(4);
    final a = aStr == null
        ? 255
        : ((double.tryParse(aStr) ?? 1.0).clamp(0.0, 1.0) * 255).round();
    return Color.fromARGB(a, r, g, b);
  }
  return fallback;
}

/// `'24px'` / `'24'` / `24` / `24.5` → `double`. Returns `null` on parse
/// failure or unsupported units (em / rem / etc).
double? parsePx(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    if (s.endsWith('px')) {
      return double.tryParse(s.substring(0, s.length - 2));
    }
    return double.tryParse(s);
  }
  return null;
}

/// `'left'` / `'center'` / `'right'` / `'justify'` → `TextAlign`. Defaults
/// to [TextAlign.left].
TextAlign parseTextAlign(String? value) {
  switch (value) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    case 'justify':
      return TextAlign.justify;
    case 'left':
    default:
      return TextAlign.left;
  }
}

/// React `align` strings → Flutter `Alignment` for image-style positioning
/// where centering uses `centerLeft` / `center` / `centerRight`.
Alignment parseAlignment(String? value) {
  switch (value) {
    case 'center':
      return Alignment.center;
    case 'right':
      return Alignment.centerRight;
    case 'left':
    default:
      return Alignment.centerLeft;
  }
}

/// `'bold'` / `'normal'` / `'300'..'900'` → `FontWeight`. Falls back to
/// [FontWeight.normal].
FontWeight parseFontWeight(String? value) {
  switch (value) {
    case 'bold':
    case '700':
      return FontWeight.bold;
    case '100':
      return FontWeight.w100;
    case '200':
      return FontWeight.w200;
    case '300':
      return FontWeight.w300;
    case '400':
    case 'normal':
      return FontWeight.normal;
    case '500':
      return FontWeight.w500;
    case '600':
      return FontWeight.w600;
    case '800':
      return FontWeight.w800;
    case '900':
      return FontWeight.w900;
    default:
      return FontWeight.normal;
  }
}

/// `'italic'` / `'normal'` / `'oblique'` → `FontStyle`. Falls back to
/// [FontStyle.normal].
FontStyle parseFontStyle(String? value) =>
    (value == 'italic' || value == 'oblique')
    ? FontStyle.italic
    : FontStyle.normal;

/// `'contain'` / `'cover'` / `'fill'` / `'none'` / `'scale-down'` →
/// `BoxFit`. Defaults to [BoxFit.contain].
BoxFit parseObjectFit(String? value) {
  switch (value) {
    case 'cover':
      return BoxFit.cover;
    case 'fill':
      return BoxFit.fill;
    case 'none':
      return BoxFit.none;
    case 'scale-down':
      return BoxFit.scaleDown;
    case 'contain':
    default:
      return BoxFit.contain;
  }
}

/// Parse a `{color, width, sides: {top, right, bottom, left}}` map (used
/// by `table` / `tasks-table` blocks for `headerBorders` / `rowBorders`)
/// into a Flutter [Border], by the server's rules
/// (`resolveTableRegionBorders`): a missing region is every side at 1px
/// `#E5E7EB`, and **a side is drawn unless it is strictly `false`** — a
/// missing one is on. Null when no side would be drawn.
Border? parseTableRegionBorders(Map<String, dynamic>? raw) {
  final sides = raw?['sides'];
  final color = parseCssColor(
    raw?['color'] as String?,
    fallback: const Color(0xFFE5E7EB),
  );
  final width = (parsePx(raw?['width']) ?? 1.0).clamp(0.0, 20.0);
  if (width <= 0) return null;
  BorderSide sideFor(String key) => sides is Map && sides[key] == false
      ? BorderSide.none
      : BorderSide(color: color, width: width);
  final top = sideFor('top');
  final right = sideFor('right');
  final bottom = sideFor('bottom');
  final left = sideFor('left');
  if (top == BorderSide.none &&
      right == BorderSide.none &&
      bottom == BorderSide.none &&
      left == BorderSide.none) {
    return null;
  }
  return Border(top: top, right: right, bottom: bottom, left: left);
}

/// Read a `Map<String, dynamic>?` property safely off a block's
/// `properties` map. Useful for nested shapes that may not be present.
Map<String, dynamic>? propMap(Map<String, dynamic> props, String key) {
  final v = props[key];
  if (v is Map<String, dynamic>) return v;
  return null;
}

/// Read the `labelStyle` / `valueStyle` sub-map from a fieldConfigs entry,
/// total item, or table column. Phase 7c editors save these as
/// `Map<String, dynamic>` with `fontSize` / `fontWeight` / `fontStyle` /
/// `color` keys.
Map<String, dynamic>? cellStyleMap(Map<String, dynamic> field, String key) {
  final v = field[key];
  if (v is Map<String, dynamic>) return v;
  return null;
}

/// Per-cell typography resolved via React's cascade
/// (`BlockRenderer.tsx`):
///   `subMap?.fontSize  || field.fontSize  || blockFallback`
///   `subMap?.fontWeight || field.fontWeight || blockFallback`
///   `subMap?.fontStyle  || field.fontStyle  || blockFallback`
///   `subMap?.color      || field.color      || blockFallback`
/// Used by Info / Invoice-Details / Table / Total renderers so per-row
/// `labelStyle` / `valueStyle` overrides set by the Phase 7c editors
/// actually appear on the canvas.
class CellTypography {
  const CellTypography({
    required this.fontSize,
    required this.fontWeight,
    required this.fontStyle,
    required this.color,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final Color color;

  TextStyle toTextStyle({double? height}) => TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height,
  );
}

CellTypography resolveCellTypography({
  Map<String, dynamic>? subMap,
  required Map<String, dynamic> field,
  required double blockFontSize,
  required FontWeight blockFontWeight,
  required FontStyle blockFontStyle,
  required Color blockColor,
}) {
  final fs =
      parsePx(subMap?['fontSize']) ??
      parsePx(field['fontSize']) ??
      blockFontSize;
  final weightStr =
      (subMap?['fontWeight'] as String?) ?? (field['fontWeight'] as String?);
  final fw = weightStr == null ? blockFontWeight : parseFontWeight(weightStr);
  final styleStr =
      (subMap?['fontStyle'] as String?) ?? (field['fontStyle'] as String?);
  final fst = styleStr == null ? blockFontStyle : parseFontStyle(styleStr);
  final colorStr = (subMap?['color'] as String?) ?? (field['color'] as String?);
  final col = colorStr == null
      ? blockColor
      : parseCssColor(colorStr, fallback: blockColor);
  return CellTypography(
    fontSize: fs,
    fontWeight: fw,
    fontStyle: fst,
    color: col,
  );
}

/// Read a `List<Map<String, dynamic>>?` property safely.
List<Map<String, dynamic>> propMapList(Map<String, dynamic> props, String key) {
  final v = props[key];
  if (v is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in v)
      if (item is Map<String, dynamic>) item,
  ];
}

/// What the designer's widgets take from around them: the company's
/// [Formatter], so amounts and dates read as they will on the PDF rather
/// than as en-US dollars, and the document everything is filled in with —
/// so an example value in the property panel is the value on the page.
class DesignerRenderScope extends InheritedWidget {
  const DesignerRenderScope({
    super.key,
    required this.formatter,
    this.sample,
    this.customFieldLabels,
    required super.child,
  });

  final Formatter? formatter;

  /// The names the company gave its custom fields, by slot (`invoice1`,
  /// `client2`) — what the server prints for `$invoice.custom1_label`. Null
  /// where nothing knows them.
  final Map<String, String>? customFieldLabels;

  /// Null where nothing set one: [sampleOf] then answers with the made-up
  /// document.
  final DesignerSampleData? sample;

  static Formatter? formatterOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesignerRenderScope>()
      ?.formatter;

  static DesignerSampleData? maybeSampleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignerRenderScope>()?.sample;

  static DesignerSampleData sampleOf(BuildContext context) =>
      maybeSampleOf(context) ?? DesignerSampleData.fallback;

  static Map<String, String>? customFieldLabelsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DesignerRenderScope>()
          ?.customFieldLabels;

  @override
  bool updateShouldNotify(DesignerRenderScope old) =>
      old.formatter != formatter ||
      !identical(old.sample, sample) ||
      !identical(old.customFieldLabels, customFieldLabels);
}

/// The size a block's text takes when it sets none of its own: the
/// document's, which the page puts in its `DefaultTextStyle` — as on the
/// server, where a block without a `font-size` inherits the body's.
double inheritedFontSize(BuildContext context) =>
    DefaultTextStyle.of(context).style.fontSize ?? 16;
