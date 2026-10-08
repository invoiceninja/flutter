import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';

void main() {
  group('buildStarterTemplates', () {
    test('returns the starters, each under its own id', () {
      final starters = buildStarterTemplates();
      expect(starters.map((s) => s.id).toList(), [
        'standard',
        'bold',
        'minimal',
        'quote_friendly',
      ]);
    });

    test('no two starters are the same blocks in the same style', () {
      // A gallery of thumbnails is only a choice if the pictures differ:
      // three of these were once the library defaults in a different order.
      String fingerprint(DesignTemplateStarter s) => [
        for (final b in s.blocks)
          '${b.type}@${b.gridPosition.x},${b.gridPosition.y}'
              ':${b.properties['headerBg']}:${b.properties['fontSize']}',
      ].join('|');
      final prints = buildStarterTemplates().map(fingerprint).toSet();
      expect(prints, hasLength(buildStarterTemplates().length));
    });

    test('Bold takes the company colour, and a neutral one without it', () {
      Map<String, dynamic> table(String? accent) =>
          buildStarterTemplates(accent: accent)
              .firstWhere((s) => s.id == 'bold')
              .blocks
              .firstWhere((b) => b.type == 'table')
              .properties;
      expect(table('#2f7dc3')['headerBg'], '#2F7DC3');
      expect(table(null)['headerBg'], kStarterInk);
      // Not a hex colour the server could print: fall back, do not store it.
      expect(table('teal')['headerBg'], kStarterInk);
      expect(table('#2F7DC3')['headerColor'], '#FFFFFF');
    });

    test('a starter block keeps every default its style does not set', () {
      final table = buildStarterTemplates()
          .firstWhere((s) => s.id == 'minimal')
          .blocks
          .firstWhere((b) => b.type == 'table');
      expect(table.properties['alternateRows'], isFalse);
      // The columns, borders and padding are still the library's.
      expect(table.properties['columns'], isNotEmpty);
      expect(table.properties['padding'], '8px');
    });

    test('every starter ships a non-empty blocks list', () {
      for (final s in buildStarterTemplates()) {
        expect(s.blocks, isNotEmpty, reason: 'starter ${s.id} is empty');
      }
    });

    test('each starter includes the essential invoice blocks', () {
      // Phase-4 contract: starters cover at least logo + products table +
      // totals. Anything less and "Start from template" wouldn't beat
      // dragging blocks from the palette.
      const essentials = {'logo', 'table', 'total'};
      for (final s in buildStarterTemplates()) {
        final types = s.blocks.map((b) => b.type).toSet();
        expect(
          types.containsAll(essentials),
          isTrue,
          reason: 'starter ${s.id} is missing one of $essentials',
        );
      }
    });

    test('no row of a starter is wider than the page, or overlaps', () {
      for (final s in buildStarterTemplates()) {
        for (final row in rowsOf(s.blocks)) {
          var right = 0;
          for (final b in row) {
            final p = b.gridPosition;
            expect(
              p.x,
              greaterThanOrEqualTo(right),
              reason: 'starter ${s.id}: ${b.type} overlaps its neighbour',
            );
            right = p.x + p.w;
          }
          expect(right, lessThanOrEqualTo(kDesignerGridCols));
        }
      }
    });

    test('all blocks stay within the 12-column grid', () {
      for (final s in buildStarterTemplates()) {
        for (final b in s.blocks) {
          final p = b.gridPosition;
          expect(p.x, greaterThanOrEqualTo(0));
          expect(
            p.x + p.w,
            lessThanOrEqualTo(12),
            reason: 'starter ${s.id} ${b.type} bleeds past col 12',
          );
          expect(p.y, greaterThanOrEqualTo(0));
        }
      }
    });

    test('calling buildStarterTemplates again produces fresh block ids', () {
      // Each call must produce new UUIDs — otherwise picking the same
      // starter twice would collide on block ids in the canvas.
      final first = buildStarterTemplates();
      final second = buildStarterTemplates();
      final firstIds = first.expand((s) => s.blocks.map((b) => b.id)).toSet();
      final secondIds = second.expand((s) => s.blocks.map((b) => b.id)).toSet();
      // Some overlap is allowed in pathological randomness, but the vast
      // majority must differ — assert intersection size is small.
      final overlap = firstIds.intersection(secondIds);
      expect(
        overlap.length,
        lessThan(2),
        reason: 'block ids should be freshly generated per call',
      );
    });

    test('every block in a starter has the spec\'s default properties', () {
      // Templates ship via BlockSpec.newInstance so they pick up table
      // columns, total items, info-block fieldConfigs etc. without
      // hand-coding them.
      for (final s in buildStarterTemplates()) {
        for (final b in s.blocks) {
          if (b.type == 'table' || b.type == 'tasks-table') {
            expect(
              b.properties['columns'],
              isA<List<dynamic>>(),
              reason: 'starter ${s.id} table missing default columns',
            );
          }
          if (b.type == 'total') {
            expect(
              b.properties['items'],
              isA<List<dynamic>>(),
              reason: 'starter ${s.id} total missing default items',
            );
          }
          if (b.type.endsWith('-info') || b.type == 'invoice-details') {
            expect(
              b.properties['fieldConfigs'],
              isA<List<dynamic>>(),
              reason: 'starter ${s.id} ${b.type} missing fieldConfigs',
            );
          }
        }
      }
    });
  });

  group('starter blocks round-trip through annotateBlocksAsApi', () {
    // Smoke test that the same save-path the WYSIWYG VM uses will produce
    // a valid wire payload from any starter — catches accidental
    // mis-typed default properties.
    test('every starter annotates without throwing', () {
      for (final s in buildStarterTemplates()) {
        expect(
          () => annotateBlocksAsApi(s.blocks),
          returnsNormally,
          reason: 'starter ${s.id} fails annotation',
        );
      }
    });

    test('annotated blocks expose all four row-layout fields', () {
      for (final s in buildStarterTemplates()) {
        final annotated = annotateBlocksAsApi(s.blocks);
        for (final api in annotated) {
          expect(api.rowAlign, isNotNull);
          expect(api.rowWidth, isNotNull);
          expect(api.colStart, isNotNull);
          expect(api.colSpan, isNotNull);
        }
      }
    });
  });
}
