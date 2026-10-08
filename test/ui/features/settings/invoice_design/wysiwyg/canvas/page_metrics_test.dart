import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/page_metrics.dart';

void main() {
  group('designerPageSize', () {
    test('the sheets the server prints, at 96 dpi', () {
      expect(designerPageSize('A4', 'portrait'), const Size(794, 1123));
      expect(designerPageSize('Letter', 'portrait'), const Size(816, 1056));
      expect(designerPageSize('a5', 'PORTRAIT'), const Size(559, 794));
    });

    test('landscape turns the sheet', () {
      expect(designerPageSize('A4', 'landscape'), const Size(1123, 794));
      expect(designerPageSize('Letter', 'landscape'), const Size(1056, 816));
    });

    test(
      'a size the server does not know is A4 portrait, orientation and all',
      () {
        // Probed: `pageSize: B5, pageLayout: landscape` printed
        // `@page { size: A4 portrait }`.
        expect(designerPageSize('B5', 'landscape'), const Size(794, 1123));
        expect(designerPageSize('JIS-B4', 'portrait'), const Size(794, 1123));
        expect(designerPageSize('', 'landscape'), const Size(794, 1123));
      },
    );
  });

  group('sizes the server prints that the page used to get wrong', () {
    test('Ledger is 11 × 17in upright, like Tabloid', () {
      // The server emits `size: Ledger portrait`; drawn on its side the
      // page was the wrong shape for every design that used it.
      expect(designerPageSize('Ledger', 'portrait'), const Size(1056, 1632));
      expect(designerPageSize('Ledger', 'landscape'), const Size(1632, 1056));
    });

    test('A0 to A2 are their own sizes, not A4', () {
      final a4 = designerPageSize('A4', 'portrait');
      for (final size in ['A0', 'A1', 'A2']) {
        expect(designerPageSize(size, 'portrait'), isNot(a4), reason: size);
      }
      expect(
        designerPageSize('A2', 'portrait').width,
        closeTo(designerPageSize('A3', 'portrait').height, 2),
      );
    });
  });

  group('DesignerPageMetrics', () {
    test('the inset is margin plus padding, per side', () {
      final m = DesignerPageMetrics.of(
        const DocumentSettings(
          pageMarginLeft: 7,
          pagePaddingLeft: 30,
          pageMarginTop: 10,
          pagePaddingTop: 0,
          pageMarginRight: 0,
          pagePaddingRight: 20,
          pageMarginBottom: 5,
          pagePaddingBottom: 5,
        ),
      );
      expect(m.insetLeft, 37);
      expect(m.insetTop, 10);
      expect(m.insetRight, 20);
      expect(m.insetBottom, 10);
      expect(m.contentWidth, 794 - 37 - 20);
    });

    test('content is laid out wider by the body zoom', () {
      final m = DesignerPageMetrics.of(const DocumentSettings());
      // 794 - 30 - 30, then 80%.
      expect(m.contentWidth, 734);
      expect(m.layoutWidth, closeTo(734 / kDesignerBodyZoom, 0.001));
    });

    test('absurd margins never leave a page with no width to click on', () {
      final m = DesignerPageMetrics.of(
        const DocumentSettings(pageMarginLeft: 500, pageMarginRight: 500),
      );
      // The *insets* give way — a floor on the content width alone was
      // never consulted by the sheet's own padding, and the page went blank.
      expect(m.contentWidth, kMinDesignerContent);
      expect(m.insetLeft + m.insetRight + m.contentWidth, m.size.width);
      expect(m.insetLeft, m.insetRight);
    });

    test('nor one with no height', () {
      final m = DesignerPageMetrics.of(
        const DocumentSettings(pageMarginTop: 900, pageMarginBottom: 300),
      );
      expect(
        m.size.height - m.insetTop - m.insetBottom,
        closeTo(kMinDesignerContent, 0.001),
      );
      // Scaled, not flattened: the larger margin is still the larger.
      expect(m.insetTop, greaterThan(m.insetBottom));
    });

    test('ordinary margins are left exactly as set', () {
      final m = DesignerPageMetrics.of(
        const DocumentSettings(pageMarginLeft: 40, pageMarginRight: 10),
      );
      expect(m.insetLeft, 40 + 30);
      expect(m.insetRight, 10 + 30);
    });
  });
}
