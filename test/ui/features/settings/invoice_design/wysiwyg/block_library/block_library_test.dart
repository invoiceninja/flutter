import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// Catalog-level smoke checks for every block spec. None of these assertions
/// exercise a renderer — they protect the *contract* that every spec is
/// addressable, has a stable type string, and carries a `defaultProperties`
/// map that can serialize to JSON. The block JSON is what the outbox/server
/// sees, so a non-serializable value is a real production bug.
void main() {
  test('every BlockType in the React contract is represented exactly once', () {
    const expected = <String>{
      'logo',
      'company-info',
      'text',
      'client-info',
      'client-shipping-info',
      'invoice-details',
      'public-notes',
      'footer',
      'terms',
      'image',
      'table',
      'tasks-table',
      'total',
      'divider',
      'spacer',
      'qrcode',
      'signature',
    };
    final types = kBlockLibrary.map((s) => s.type).toSet();
    expect(types, expected);
    expect(types.length, expected.length, reason: 'no duplicate specs');
  });

  test('blockSpecFor returns null for unknown types', () {
    expect(blockSpecFor('does-not-exist'), isNull);
    expect(blockSpecFor('logo'), isNotNull);
  });

  test('every spec serializes its defaultProperties via jsonEncode', () {
    for (final spec in kBlockLibrary) {
      // Throws on un-encodable values — typed objects, functions, etc.
      expect(
        () => jsonEncode(spec.defaultProperties),
        returnsNormally,
        reason: 'spec "${spec.type}" has non-serializable defaultProperties',
      );
    }
  });

  test('every spec has a positive default size that fits the 12-col grid', () {
    for (final spec in kBlockLibrary) {
      expect(
        spec.defaultWidth,
        inInclusiveRange(1, 12),
        reason: '${spec.type} defaultWidth out of range',
      );
      expect(
        spec.defaultHeight,
        greaterThan(0),
        reason: '${spec.type} defaultHeight not positive',
      );
    }
  });

  test('newBlockId generates "type-uuid"-shaped strings', () {
    final id = newBlockId('logo');
    expect(id, startsWith('logo-'));
    // Loose RFC4122-v4 shape: 8-4-4-4-12 hex blocks after the prefix.
    final uuidPart = id.substring('logo-'.length);
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(uuidPart),
      isTrue,
      reason: 'unexpected uuid shape: $uuidPart',
    );
  });

  test('newBlockId does not collide across many calls', () {
    final ids = {for (var i = 0; i < 200; i++) newBlockId('text')};
    expect(ids.length, 200);
  });

  test('table + tasks-table defaults include headerBorders and rowBorders', () {
    // Phase 1.5 #2 regression — React's DEFAULT_TABLE_REGION_BORDER_PROPS
    // must be present on both table-bearing block types.
    for (final type in const ['table', 'tasks-table']) {
      final spec = blockSpecFor(type)!;
      expect(
        spec.defaultProperties['headerBorders'],
        isA<Map<String, dynamic>>(),
        reason: '$type missing headerBorders',
      );
      expect(
        spec.defaultProperties['rowBorders'],
        isA<Map<String, dynamic>>(),
        reason: '$type missing rowBorders',
      );
      final sides =
          (spec.defaultProperties['headerBorders']
                  as Map<String, dynamic>)['sides']
              as Map<String, dynamic>;
      expect(sides['top'], isTrue);
      expect(sides['right'], isTrue);
      expect(sides['bottom'], isTrue);
      expect(sides['left'], isTrue);
    }
  });

  test('total spec items all carry show:true', () {
    final spec = blockSpecFor('total')!;
    final items = spec.defaultProperties['items'] as List<dynamic>;
    expect(items, hasLength(6));
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      expect(
        item['show'],
        isTrue,
        reason: 'item ${item['label']} missing show:true',
      );
    }
  });

  group('blockSpecFor (Phase 15a const map)', () {
    test('every kBlockLibrary type resolves to its own spec', () {
      for (final spec in kBlockLibrary) {
        expect(
          identical(blockSpecFor(spec.type), spec),
          isTrue,
          reason: 'spec ${spec.type} should be looked up by id',
        );
      }
    });

    test('unknown types resolve to null', () {
      expect(blockSpecFor('not-a-real-block'), isNull);
      expect(blockSpecFor(''), isNull);
    });
  });

  group('what the server prints', () {
    test('the tasks table is the one block it has no renderer for', () {
      // `JsonToSectionsAdapter::convertBlockToSection` has no `tasks-table`
      // arm: the block prints nothing. Flip this when the server gains one.
      expect(
        [
          for (final s in kBlockLibrary)
            if (!s.printed) s.type,
        ],
        ['tasks-table'],
      );
    });

    test('table columns and info titles are seeded with label tokens', () {
      // The server prints a header exactly as stored and translates only a
      // `$…_label` token — a bare key prints as the key.
      for (final type in ['table', 'tasks-table']) {
        final columns =
            blockSpecFor(type)!.defaultProperties['columns'] as List;
        for (final column in columns) {
          final header = (column as Map)['header'] as String;
          expect(
            header,
            matches(RegExp(r'^\$[\w.]+_label$')),
            reason: '$type column ${column['id']}',
          );
          expect(
            kLabelTranslationMap.containsKey(header),
            isTrue,
            reason: 'the canvas must be able to translate $header',
          );
        }
      }
      for (final type in [
        'client-info',
        'company-info',
        'client-shipping-info',
      ]) {
        final title = blockSpecFor(type)!.defaultProperties['title'] as String;
        expect(kLabelTranslationMap.containsKey(title), isTrue, reason: type);
      }
    });
  });
}
