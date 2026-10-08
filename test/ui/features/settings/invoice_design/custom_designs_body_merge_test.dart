import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/static/built_in_designs_catalog.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/bodies/custom_designs_body.dart';

/// Build a server-shaped [Design] row. Defaults to a built-in (`isCustom:
/// false`) since the dedupe rule under test pivots on whether ANY bundled
/// row is a built-in.
Design _d({
  required String id,
  required String name,
  bool isCustom = false,
  bool isFree = true,
}) => Design(
  id: id,
  name: name,
  isCustom: isCustom,
  isActive: true,
  isTemplate: false,
  isFree: isFree,
  entities: const ['invoice'],
  template: const DesignTemplate(),
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
);

void main() {
  group('mergeDesignRows (Phase 14 dedupe)', () {
    test('empty bundled → renders the static catalog as fallback', () {
      final rows = mergeDesignRows(const []);
      // Every static built-in should appear exactly once, no customs.
      expect(rows, hasLength(kBuiltInDesigns.length));
      for (final spec in kBuiltInDesigns) {
        final matching = rows.where((r) => r.id == spec.id);
        expect(matching, hasLength(1), reason: 'static ${spec.name}');
        expect(matching.single.isCustom, isFalse);
      }
    });

    test('bundled with built-ins whose IDs MATCH the catalog → one row each, '
        'server wins', () {
      final bundled = [
        for (final spec in kBuiltInDesigns) _d(id: spec.id, name: spec.name),
      ];
      final rows = mergeDesignRows(bundled);
      expect(rows, hasLength(kBuiltInDesigns.length));
      // Each row's underlying design is the bundled instance, not the
      // catalog stub — server is authoritative.
      for (final r in rows) {
        expect(r.design, isNotNull, reason: 'row ${r.name}');
      }
    });

    test('bundled with built-ins whose IDs DIVERGE from the catalog → '
        'still one row each, catalog suppressed', () {
      final bundled = [
        for (final spec in kBuiltInDesigns)
          // Different id, same name — simulates a self-hosted install
          // that re-issued IDs for the same built-in templates.
          _d(id: 'server-${spec.id}', name: spec.name),
      ];
      final rows = mergeDesignRows(bundled);
      expect(rows, hasLength(kBuiltInDesigns.length));
      // No row uses a static-catalog id.
      for (final r in rows) {
        expect(
          kBuiltInDesigns.any((s) => s.id == r.id),
          isFalse,
          reason: 'row ${r.name} should be the bundled (server) row',
        );
        expect(r.design, isNotNull);
      }
      // Names appear once each.
      final names = rows.map((r) => r.name).toList();
      expect(names.toSet().length, names.length, reason: 'no name duplicates');
    });

    test(
      'bundled with ONLY customs → static catalog still renders as fallback',
      () {
        final bundled = [_d(id: 'custom-1', name: 'My design', isCustom: true)];
        final rows = mergeDesignRows(bundled);
        // 11 static + 1 custom = 12 rows
        expect(rows, hasLength(kBuiltInDesigns.length + 1));
        expect(rows.where((r) => r.isCustom), hasLength(1));
      },
    );

    test('rows come out sorted alphabetically by name', () {
      final bundled = [
        _d(id: 's-z', name: 'Zebra'),
        _d(id: 's-a', name: 'Alpha'),
      ];
      final rows = mergeDesignRows(bundled);
      final names = rows.map((r) => r.name).toList();
      final sorted = [...names]..sort();
      expect(names, sorted);
    });

    test('bundled with TWO built-ins sharing a name but different ids → '
        'single row (last seen wins)', () {
      // Simulates the server returning the same built-in twice — e.g.
      // an original + a copy at a different id — which the by-id merge
      // alone would have rendered as two duplicate rows.
      final bundled = [
        _d(id: 'bold-original', name: 'Bold'),
        _d(id: 'bold-mirror', name: 'Bold'),
      ];
      final rows = mergeDesignRows(bundled);
      expect(rows, hasLength(1));
      expect(rows.single.id, 'bold-mirror');
    });

    test('built-in dedupe is case- and whitespace-insensitive', () {
      final bundled = [
        _d(id: 'a', name: 'Bold'),
        _d(id: 'b', name: ' bold '),
        _d(id: 'c', name: 'BOLD'),
      ];
      final rows = mergeDesignRows(bundled);
      expect(rows, hasLength(1), reason: 'all three keys collapse');
    });

    test('two custom designs with the same name keep both rows', () {
      // Customs must NOT collapse by name — the user may legitimately
      // want two designs called "Invoice v2".
      final bundled = [
        _d(id: 'c1', name: 'Invoice v2', isCustom: true),
        _d(id: 'c2', name: 'Invoice v2', isCustom: true),
      ];
      final rows = mergeDesignRows(bundled);
      expect(rows.where((r) => r.isCustom), hasLength(2));
    });
  });

  group('which editor a design opens in', () {
    // The server renders a design with blocks from the blocks alone and
    // ignores its HTML, so only the visual builder can edit one. The list used
    // to send every custom design to the HTML editor — the one way back into
    // a saved visual design opened the one editor that could not change it.
    test('a design with blocks is a visual design', () {
      final visual = _d(id: 'v', name: 'Visual', isCustom: true).copyWith(
        template: const DesignTemplate(
          blocks: [
            DesignBlock(
              id: 'text-1',
              type: 'text',
              gridPosition: GridPosition(x: 0, y: 0, w: 12, h: 2),
            ),
          ],
        ),
      );
      final html = _d(
        id: 'h',
        name: 'Html',
        isCustom: true,
      ).copyWith(template: const DesignTemplate(body: '<h1>hi</h1>'));
      final rows = mergeDesignRows([visual, html]);
      expect(rows.firstWhere((r) => r.id == 'v').isVisual, isTrue);
      expect(rows.firstWhere((r) => r.id == 'h').isVisual, isFalse);
    });

    test('a catalog row with no template loaded is not', () {
      expect(mergeDesignRows(const []).first.isVisual, isFalse);
    });
  });
}
