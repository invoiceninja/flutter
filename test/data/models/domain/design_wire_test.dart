import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_wire.dart';

Design _design(DesignTemplate template) => Design(
  id: 'd1',
  name: 'Probe',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: const ['invoice'],
  template: template,
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
);

DesignBlock _block(String type, Map<String, dynamic> properties) => DesignBlock(
  id: '$type-1',
  type: type,
  gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 2),
  properties: properties,
);

Map<String, dynamic> _wireDesign(Design d) =>
    (jsonDecode(jsonEncode(d.toApiJson())) as Map<String, dynamic>)['design']
        as Map<String, dynamic>;

void main() {
  group('blocks key — the server reads its presence, not its length', () {
    // `PdfService::isJsonDesign` is `isset($design['blocks'])`, true for `[]`:
    // an HTML design sent with an empty list rendered as a blank block design.
    test('an HTML design is sent without a blocks key', () {
      final wire = _wireDesign(
        _design(const DesignTemplate(body: '<h1>hello</h1>')),
      );
      expect(wire.containsKey('blocks'), isFalse);
      expect(wire['body'], '<h1>hello</h1>');
    });

    test('a block design keeps its blocks', () {
      final wire = _wireDesign(
        _design(
          DesignTemplate(
            blocks: [
              _block('text', const {'content': 'x'}),
            ],
          ),
        ),
      );
      expect(wire['blocks'], hasLength(1));
    });

    test('the local payload shape still round-trips an empty list', () {
      final json = const DesignTemplate(body: 'b').toApi().toJson();
      expect(DesignTemplateApi.fromJson(json).blocks, isEmpty);
    });
  });

  group('properties the server reads unguarded', () {
    test('a block with no properties still sends the key', () {
      final wire = _wireDesign(
        _design(DesignTemplate(blocks: [_block('divider', const {})])),
      );
      final block = (wire['blocks'] as List).single as Map<String, dynamic>;
      expect(block['properties'], isA<Map<String, dynamic>>());
    });

    test('a spacer whose height was cleared falls back to the default', () {
      expect(wireBlockProperties('spacer', const {}), {
        'height': kDefaultSpacerHeight,
      });
      expect(wireBlockProperties('spacer', const {'height': ' '}), {
        'height': kDefaultSpacerHeight,
      });
    });

    test('a numeric spacer height is made a length, not replaced', () {
      // `0` is a gap cell. Swapped for the default it printed 40px tall.
      expect(wireBlockProperties('spacer', const {'height': 0}), {
        'height': '0px',
      });
      expect(wireBlockProperties('spacer', const {'height': 24}), {
        'height': '24px',
      });
    });

    test('a block echoed with `properties: []` still parses', () {
      // PHP re-encodes an object with no keys as a list.
      final block = DesignBlockApi.fromJson(const {
        'id': 'b1',
        'type': 'divider',
        'gridPosition': {'x': 0, 'y': 0, 'w': 12, 'h': 1},
        'properties': <dynamic>[],
      });
      expect(block.properties, isEmpty);
      expect(
        DesignBlockApi.fromJson(const {
          'id': 'b2',
          'type': 'divider',
        }).properties,
        isNull,
      );
      expect(
        DesignBlockApi.fromJson(const {
          'id': 'b3',
          'type': 'text',
          'properties': {'content': 'x'},
        }).properties,
        {'content': 'x'},
      );
    });

    test('a spacer with a height is left alone', () {
      const props = {'height': '0px'};
      expect(identical(wireBlockProperties('spacer', props), props), isTrue);
    });
  });

  group('legacy label keys become the tokens the server translates', () {
    test('product table headers', () {
      final out = wireBlockProperties('table', {
        'columns': [
          {'id': 'product_key', 'header': 'item', 'field': 'item.product_key'},
          {'id': 'cost', 'header': 'unit_cost', 'field': 'item.cost'},
          {'id': 'x', 'header': 'Qty ordered', 'field': 'item.quantity'},
          {
            'id': 'y',
            'header': r'$product.line_total_label',
            'field': 'item.line_total',
          },
        ],
      });
      final headers = [
        for (final c in out['columns'] as List) (c as Map)['header'],
      ];
      expect(headers, [
        r'$product.item_label',
        r'$product.unit_cost_label',
        'Qty ordered',
        r'$product.line_total_label',
      ]);
    });

    test('a tasks table uses the task tokens for the shared keys', () {
      final out = wireBlockProperties('tasks-table', {
        'columns': [
          {'id': 'notes', 'header': 'description'},
          {'id': 'hours', 'header': 'hours'},
        ],
      });
      expect((out['columns'] as List).map((c) => (c as Map)['header']), [
        r'$task.description_label',
        r'$task.hours_label',
      ]);
    });

    test('untouched columns return the same map', () {
      final props = <String, dynamic>{
        'columns': [
          {'id': 'a', 'header': r'$product.item_label'},
        ],
      };
      expect(identical(wireBlockProperties('table', props), props), isTrue);
    });

    test('info block titles', () {
      expect(
        wireBlockProperties('client-info', const {'title': 'bill_to'})['title'],
        r'$bill_to_label',
      );
      expect(
        wireBlockProperties('company-info', const {
          'title': 'company_details',
        })['title'],
        r'$from_label',
      );
      expect(
        wireBlockProperties('client-info', const {
          'title': 'Invoice to',
        })['title'],
        'Invoice to',
      );
    });

    test('a text block is never rewritten', () {
      const props = {'content': 'bill_to', 'title': 'bill_to'};
      expect(identical(wireBlockProperties('text', props), props), isTrue);
    });
  });

  group('fields this model has no name for survive a save', () {
    // What the other client's builder writes — dropped on every Flutter save
    // until each level carried its leftovers.
    const serverJson = <String, dynamic>{
      'body': '',
      'builderGridVersion': 2,
      'customCss': '.x { color: red }',
      'layout': {'rowHeight': 10},
      'blocks': [
        {
          'id': 'text-1',
          'type': 'text',
          'gridPosition': {'x': 0, 'y': 0, 'w': 12, 'h': 2},
          'properties': {'content': 'hi'},
          'region': 'header',
        },
      ],
      'documentSettings': {
        'pageSize': 'A4',
        'pagination': {'enabled': true},
        'headerHeight': 80,
      },
    };

    test('a server payload round-trips to the wire with them in place', () {
      final template = DesignTemplate.fromApi(
        DesignTemplateApi.fromJson(serverJson),
      );
      expect(template.extra.keys, {
        'builderGridVersion',
        'customCss',
        'layout',
      });
      expect(template.blocks.single.extra, {'region': 'header'});
      expect(template.documentSettings!.extra.keys, {
        'pagination',
        'headerHeight',
      });

      final wire = _wireDesign(_design(template));
      expect(wire['builderGridVersion'], 2);
      expect(wire['customCss'], '.x { color: red }');
      expect(wire['layout'], {'rowHeight': 10});
      expect(wire.containsKey(kDesignExtraKey), isFalse);
      final block = (wire['blocks'] as List).single as Map<String, dynamic>;
      expect(block['region'], 'header');
      expect(block.containsKey(kDesignExtraKey), isFalse);
      final settings = wire['documentSettings'] as Map<String, dynamic>;
      expect(settings['pagination'], {'enabled': true});
      expect(settings['headerHeight'], 80);
      expect(settings.containsKey(kDesignExtraKey), isFalse);
    });

    test('they also survive the local payload round-trip', () {
      final first = DesignTemplate.fromApi(
        DesignTemplateApi.fromJson(serverJson),
      );
      // The Drift payload is `jsonEncode(template.toApi().toJson())`.
      final stored =
          jsonDecode(jsonEncode(first.toApi().toJson()))
              as Map<String, dynamic>;
      final second = DesignTemplate.fromApi(DesignTemplateApi.fromJson(stored));
      expect(second.extra, first.extra);
      expect(second.blocks.single.extra, first.blocks.single.extra);
      expect(second.documentSettings!.extra, first.documentSettings!.extra);
    });

    test('a known field can never be shadowed by a leftover', () {
      final wire = DesignTemplateApi.fromJson(const {
        'body': 'real',
        kDesignExtraKey: {'body': 'stale', 'customCss': 'x'},
      }).toWireJson();
      expect(wire['body'], 'real');
      expect(wire['customCss'], 'x');
    });

    test('every field the models serialize is one they recognise', () {
      // A field added to a model but not to its known-key set would be read
      // back as a leftover and sent twice.
      final json =
          jsonDecode(
                jsonEncode(
                  const DesignTemplateApi(
                    blocks: [
                      DesignBlockApi(
                        id: 'a',
                        type: 'text',
                        properties: {},
                        locked: true,
                        rowAlign: 'left',
                        rowWidth: '100%',
                        colStart: 1,
                        colSpan: 12,
                      ),
                    ],
                    documentSettings: DocumentSettingsApi(),
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final parsed = DesignTemplateApi.fromJson(json);
      expect(parsed.extra, isNull);
      expect(parsed.blocks.single.extra, isNull);
      expect(parsed.documentSettings!.extra, isNull);
    });
  });
}
