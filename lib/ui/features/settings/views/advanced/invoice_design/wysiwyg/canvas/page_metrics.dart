import 'dart:ui' show Size;

import 'package:admin/data/models/domain/design.dart';

/// The page the canvas draws, in CSS pixels — the same numbers the server's
/// PDF is laid out with (`docs/invoice-designer.md`).
///
/// A sheet is `size`. Its content box is `size` minus `margin + padding` per
/// side (the server folds both into the `@page` margin). The body is then
/// zoomed to 80%: block content is laid out [kDesignerBodyZoom] times wider
/// than the box and painted that much smaller, so a 16px font prints at 12.8.
class DesignerPageMetrics {
  const DesignerPageMetrics({
    required this.size,
    required this.insetLeft,
    required this.insetTop,
    required this.insetRight,
    required this.insetBottom,
  });

  factory DesignerPageMetrics.of(DocumentSettings settings) {
    final size = designerPageSize(settings.pageSize, settings.pageLayout);
    var left = _inset(settings.pageMarginLeft, settings.pagePaddingLeft);
    var right = _inset(settings.pageMarginRight, settings.pagePaddingRight);
    var top = _inset(settings.pageMarginTop, settings.pagePaddingTop);
    var bottom = _inset(settings.pageMarginBottom, settings.pagePaddingBottom);
    // Margins that leave no page: scale each pair back so something is left
    // to draw and to click. (The floor used to be on `contentWidth` alone,
    // which the sheet's own padding never consulted — the page went blank.)
    final acrossMax = size.width - kMinDesignerContent;
    if (left + right > acrossMax && left + right > 0) {
      final k = acrossMax / (left + right);
      left *= k;
      right *= k;
    }
    final downMax = size.height - kMinDesignerContent;
    if (top + bottom > downMax && top + bottom > 0) {
      final k = downMax / (top + bottom);
      top *= k;
      bottom *= k;
    }
    return DesignerPageMetrics(
      size: size,
      insetLeft: left,
      insetTop: top,
      insetRight: right,
      insetBottom: bottom,
    );
  }

  final Size size;
  final double insetLeft;
  final double insetTop;
  final double insetRight;
  final double insetBottom;

  /// Width of the content box on the sheet. Never less than
  /// [kMinDesignerContent]: [DesignerPageMetrics.of] limits the insets.
  double get contentWidth => size.width - insetLeft - insetRight;

  /// The width block content is laid out at — [contentWidth] before the
  /// body's zoom shrinks it.
  double get layoutWidth => contentWidth / kDesignerBodyZoom;

  static double _inset(int margin, int padding) {
    final v = (margin + padding).toDouble();
    return v < 0 ? 0 : v;
  }
}

/// The least of the sheet that margins may leave, in either direction.
const double kMinDesignerContent = 120;

/// `body { zoom: 80% }` in the server's template.
const double kDesignerBodyZoom = 0.8;

/// Sheet sizes at 96 dpi, portrait. The keys are the sizes the server prints.
const Map<String, Size> _kSheetSizes = {
  'a3': Size(1123, 1587),
  'a4': Size(794, 1123),
  'a5': Size(559, 794),
  'a6': Size(397, 559),
  'letter': Size(816, 1056),
  'legal': Size(816, 1344),
  'tabloid': Size(1056, 1632),
  // The same sheet. "Ledger" is often quoted as its landscape form, but the
  // server emits `size: Ledger portrait` — 11 × 17in — and turns it only for
  // a landscape layout, like every other size.
  'ledger': Size(1056, 1632),
  'a0': Size(3179, 4494),
  'a1': Size(2245, 3179),
  'a2': Size(1587, 2245),
};

/// Whether the server prints [pageSize] as itself. One it does not know it
/// prints as A4 portrait.
bool serverPrintsPageSize(String pageSize) =>
    _kSheetSizes.containsKey(pageSize.trim().toLowerCase());

/// The sheet for a stored `pageSize` / `pageLayout`.
///
/// A size the server does not know prints as **A4 portrait** — it drops the
/// orientation along with the size — and so does this.
Size designerPageSize(String pageSize, String pageLayout) {
  final sheet = _kSheetSizes[pageSize.trim().toLowerCase()];
  if (sheet == null) return _kSheetSizes['a4']!;
  return pageLayout.trim().toLowerCase() == 'landscape' ? sheet.flipped : sheet;
}
