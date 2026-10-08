import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';

void main() {
  group('parseCssColor', () {
    test('parses 6-digit hex', () {
      expect(parseCssColor('#FF0000'), const Color(0xFFFF0000));
      expect(parseCssColor('#6B7280'), const Color(0xFF6B7280));
    });
    test('parses 3-digit hex shorthand', () {
      expect(parseCssColor('#F0F'), const Color(0xFFFF00FF));
    });
    test('parses 8-digit hex (with alpha)', () {
      expect(parseCssColor('#80FF0000'), const Color(0x80FF0000));
    });
    test('parses rgb()', () {
      expect(parseCssColor('rgb(0, 128, 255)'), const Color(0xFF0080FF));
    });
    test('parses rgba()', () {
      final c = parseCssColor('rgba(255, 0, 0, 0.5)');
      expect(c.a, closeTo(0.5, 0.01));
      expect((c.r * 255).round(), 255);
    });
    test('returns fallback on unparseable input', () {
      expect(
        parseCssColor('not a color', fallback: const Color(0xFF123456)),
        const Color(0xFF123456),
      );
      expect(parseCssColor(null), const Color(0xFF000000));
      expect(parseCssColor(''), const Color(0xFF000000));
    });
  });

  group('parsePx', () {
    test('handles px-suffixed and bare numbers', () {
      expect(parsePx('24px'), 24.0);
      expect(parsePx('24'), 24.0);
      expect(parsePx(24), 24.0);
      expect(parsePx(24.5), 24.5);
    });
    test('returns null for unparseable input', () {
      expect(parsePx('24em'), isNull);
      expect(parsePx('auto'), isNull);
      expect(parsePx(null), isNull);
      expect(parsePx(''), isNull);
    });
  });

  group('parseTextAlign / parseAlignment', () {
    test('parseTextAlign maps the four keys', () {
      expect(parseTextAlign('left'), TextAlign.left);
      expect(parseTextAlign('center'), TextAlign.center);
      expect(parseTextAlign('right'), TextAlign.right);
      expect(parseTextAlign('justify'), TextAlign.justify);
      expect(parseTextAlign(null), TextAlign.left);
    });
    test('parseAlignment uses centerLeft / center / centerRight', () {
      expect(parseAlignment('left'), Alignment.centerLeft);
      expect(parseAlignment('center'), Alignment.center);
      expect(parseAlignment('right'), Alignment.centerRight);
    });
  });

  group('parseFontWeight + parseFontStyle', () {
    test('common names + numeric strings', () {
      expect(parseFontWeight('bold'), FontWeight.bold);
      expect(parseFontWeight('700'), FontWeight.bold);
      expect(parseFontWeight('400'), FontWeight.normal);
      expect(parseFontWeight('900'), FontWeight.w900);
      expect(parseFontWeight(null), FontWeight.normal);
    });
    test('parseFontStyle italic vs normal', () {
      expect(parseFontStyle('italic'), FontStyle.italic);
      expect(parseFontStyle('oblique'), FontStyle.italic);
      expect(parseFontStyle('normal'), FontStyle.normal);
      expect(parseFontStyle(null), FontStyle.normal);
    });
  });

  group('parseObjectFit', () {
    test('maps the standard values', () {
      expect(parseObjectFit('contain'), BoxFit.contain);
      expect(parseObjectFit('cover'), BoxFit.cover);
      expect(parseObjectFit('fill'), BoxFit.fill);
      expect(parseObjectFit('scale-down'), BoxFit.scaleDown);
      expect(parseObjectFit(null), BoxFit.contain);
    });
  });

  group('parseTableRegionBorders', () {
    test('builds a Border honoring per-side toggles', () {
      final b = parseTableRegionBorders({
        'color': '#E5E7EB',
        'width': 2,
        'sides': {'top': true, 'right': false, 'bottom': true, 'left': false},
      });
      expect(b, isNotNull);
      expect(b!.top.color, const Color(0xFFE5E7EB));
      expect(b.top.width, 2.0);
      expect(b.right, BorderSide.none);
      expect(b.bottom.color, const Color(0xFFE5E7EB));
      expect(b.left, BorderSide.none);
    });
    test('a missing region is every side, as the server draws it', () {
      // `resolveTableRegionBorders`: not an array, or an empty one, is all
      // four sides at 1px #E5E7EB. The page used to draw none.
      for (final region in [null, <String, dynamic>{}]) {
        final b = parseTableRegionBorders(region)!;
        for (final side in [b.top, b.right, b.bottom, b.left]) {
          expect(side.width, 1.0);
          expect(side.color, const Color(0xFFE5E7EB));
        }
      }
    });
    test('a side left out is on; only `false` turns one off', () {
      // The editor used to turn a side off by removing its key, which the
      // server reads as on — off on the page, drawn in the PDF.
      final b = parseTableRegionBorders({
        'sides': {'top': true, 'left': false},
      })!;
      expect(b.top.width, 1.0);
      expect(b.right.width, 1.0, reason: 'left out');
      expect(b.bottom.width, 1.0, reason: 'left out');
      expect(b.left, BorderSide.none);
    });
    test('a zero width draws nothing', () {
      expect(parseTableRegionBorders({'width': 0}), isNull);
    });
    test('returns null when all sides are off', () {
      expect(
        parseTableRegionBorders({
          'color': '#000',
          'width': 1,
          'sides': {
            'top': false,
            'right': false,
            'bottom': false,
            'left': false,
          },
        }),
        isNull,
      );
    });
    test('uses fallback width=1 when width is missing', () {
      final b = parseTableRegionBorders({
        'color': '#E5E7EB',
        'sides': {'top': true},
      });
      expect(b?.top.width, 1.0);
    });
  });

  group('propMap / propMapList', () {
    test('propMap returns the nested map or null', () {
      expect(
        propMap({
          'a': {'k': 1},
        }, 'a'),
        {'k': 1},
      );
      expect(propMap({'a': 'not a map'}, 'a'), isNull);
      expect(propMap({}, 'a'), isNull);
    });
    test('propMapList filters out non-maps', () {
      expect(
        propMapList({
          'a': [
            {'k': 1},
            'noise',
            {'k': 2},
          ],
        }, 'a'),
        [
          {'k': 1},
          {'k': 2},
        ],
      );
      expect(propMapList({}, 'a'), isEmpty);
    });
  });

  group('resolveCellTypography (Phase 8h cascade)', () {
    test('subMap wins over field which wins over block fallback', () {
      final cell = resolveCellTypography(
        subMap: {'fontSize': '18px', 'color': '#FF0000'},
        field: {'fontSize': '14px', 'fontWeight': 'bold', 'color': '#00FF00'},
        blockFontSize: 10,
        blockFontWeight: FontWeight.normal,
        blockFontStyle: FontStyle.normal,
        blockColor: const Color(0xFF000000),
      );
      // subMap overrides for fontSize + color
      expect(cell.fontSize, 18);
      expect(cell.color, const Color(0xFFFF0000));
      // field wins where subMap is silent
      expect(cell.fontWeight, FontWeight.bold);
      // block fallback wins where neither set
      expect(cell.fontStyle, FontStyle.normal);
    });

    test('block fallback applies when both subMap and field are silent', () {
      final cell = resolveCellTypography(
        subMap: null,
        field: const {},
        blockFontSize: 12,
        blockFontWeight: FontWeight.w600,
        blockFontStyle: FontStyle.italic,
        blockColor: const Color(0xFF112233),
      );
      expect(cell.fontSize, 12);
      expect(cell.fontWeight, FontWeight.w600);
      expect(cell.fontStyle, FontStyle.italic);
      expect(cell.color, const Color(0xFF112233));
    });

    test('subMap fontStyle italic comes through', () {
      final cell = resolveCellTypography(
        subMap: {'fontStyle': 'italic'},
        field: const {},
        blockFontSize: 12,
        blockFontWeight: FontWeight.normal,
        blockFontStyle: FontStyle.normal,
        blockColor: const Color(0xFF000000),
      );
      expect(cell.fontStyle, FontStyle.italic);
    });

    test('cellStyleMap returns the nested map or null', () {
      expect(
        cellStyleMap({
          'labelStyle': {'color': '#FFF'},
        }, 'labelStyle'),
        {'color': '#FFF'},
      );
      expect(cellStyleMap({'labelStyle': 'not-a-map'}, 'labelStyle'), isNull);
      expect(cellStyleMap(const {}, 'valueStyle'), isNull);
    });
  });
}
