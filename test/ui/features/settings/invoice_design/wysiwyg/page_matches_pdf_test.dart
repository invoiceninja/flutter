import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/designer_image.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/image_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/info_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/image_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/info_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/invoice_details_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/table_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/use_design_dialog.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A 1×1 transparent PNG.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  locale: const Locale('en'),
  theme: buildInTheme(InTheme.light),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// The places the page used to show something the PDF would not print —
/// each rule here was read off the server (`JsonToSectionsAdapter.php`,
/// `PdfBuilder.php`) and probed on the demo server.
void main() {
  late AppDatabase db;
  late DesignRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DesignRepository(db: db, api: _FakeDesignsApi());
  });

  tearDown(() async => db.close());

  WysiwygDesignViewModel vmWith(String type) {
    final vm = WysiwygDesignViewModel(repo: repo, companyId: 'co1');
    addTearDown(vm.dispose);
    vm.addBlock(blockSpecFor(type)!);
    return vm;
  }

  group('a length is never negative', () {
    testWidgets('"−" on an empty field stops at zero', (tester) async {
      final emitted = <String?>[];
      await tester.pumpWidget(
        _wrap(
          PxInput(labelKey: 'padding', value: null, onChanged: emitted.add),
        ),
      );
      // One press on a new text block's Padding wrote `-1px`: invalid CSS
      // for the server, and an assertion in `EdgeInsets` on the page.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();
      }
      expect(emitted, isNotEmpty);
      expect(emitted.toSet(), {'0px'});
    });

    testWidgets('a font size stops at its own floor', (tester) async {
      String? last;
      await tester.pumpWidget(
        _wrap(
          FontSizeInput(
            labelKey: 'font_size',
            value: '5px',
            onChanged: (v) => last = v,
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pump();
      }
      expect(last, '4px');
    });
  });

  group('table borders', () {
    // They start closed (rarely touched) — and stay as last left, for the
    // whole process, so this opens only what is not already open.
    Future<void> openBorders(WidgetTester tester) async {
      if (find.byType(FilterChip).evaluate().isNotEmpty) return;
      await tester.ensureVisible(find.text('BORDERS'));
      await tester.tap(find.text('BORDERS'));
      await tester.pump();
    }

    testWidgets('unticking a side stores false, which the server reads', (
      tester,
    ) async {
      final vm = vmWith('table');
      await tester.pumpWidget(
        _wrap(
          ListenableBuilder(
            listenable: vm,
            builder: (_, _) =>
                TableBlockProperties(vm: vm, block: vm.blocks.single),
          ),
        ),
      );
      await tester.pump();
      await openBorders(tester);
      final left = find.widgetWithText(FilterChip, 'Left').first;
      await tester.ensureVisible(left);
      expect(tester.widget<FilterChip>(left).selected, isTrue);
      await tester.tap(left);
      await tester.pump();

      final regions = [
        for (final key in ['headerBorders', 'rowBorders'])
          vm.blocks.single.properties[key] as Map?,
      ];
      final changed = regions.firstWhere(
        (r) => (r?['sides'] as Map?)?['left'] == false,
        orElse: () => null,
      );
      // Removing the key — what this did — is "on" to the server.
      expect(changed, isNotNull, reason: 'left must be stored as false');
      expect(
        parseTableRegionBorders(Map<String, dynamic>.from(changed!))!.left,
        BorderSide.none,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Left').first)
            .selected,
        isFalse,
      );
    });

    testWidgets('a side with no stored value shows as on', (tester) async {
      final vm = vmWith('table');
      final block = vm.blocks.single;
      vm.updateBlock(
        block.copyWith(
          properties: {
            ...block.properties,
            'rowBorders': {'sides': <String, dynamic>{}},
            'headerBorders': {'sides': <String, dynamic>{}},
          },
        ),
      );
      await tester.pumpWidget(
        _wrap(TableBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      await openBorders(tester);
      expect(find.byType(FilterChip), findsNWidgets(8));
      for (final chip in tester.widgetList<FilterChip>(
        find.byType(FilterChip),
      )) {
        expect(chip.selected, isTrue);
      }
    });

    testWidgets('"Show borders" — read by nothing — is not offered', (
      tester,
    ) async {
      final vm = vmWith('table');
      await tester.pumpWidget(
        _wrap(TableBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Show Borders'), findsNothing);
    });
  });

  group('a control the PDF ignores is not shown', () {
    testWidgets('company block: no title', (tester) async {
      final vm = vmWith('company-info');
      await tester.pumpWidget(
        _wrap(InfoBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Show title'), findsNothing);
    });

    testWidgets('client block: a title, and a prefix on its fields', (
      tester,
    ) async {
      final vm = vmWith('client-info');
      await tester.pumpWidget(
        _wrap(InfoBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Show title'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pump();
      expect(find.text('Prefix'), findsOneWidget);
      expect(find.text('Suffix'), findsOneWidget);
    });

    testWidgets('details block: no title, no prefix, no suffix', (
      tester,
    ) async {
      final vm = vmWith('invoice-details');
      await tester.pumpWidget(
        _wrap(InvoiceDetailsBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Show title'), findsNothing);
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pump();
      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Prefix'), findsNothing);
      expect(find.text('Suffix'), findsNothing);
    });

    testWidgets('and the page draws no title on a company block', (
      tester,
    ) async {
      final spec = blockSpecFor('company-info')!;
      DesignBlock block(String type) => DesignBlock(
        id: 'b-$type',
        type: type,
        gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 2),
        properties: {
          ...spec.defaultProperties,
          'showTitle': true,
          'title': 'A TITLE',
        },
      );
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              InfoBlock(
                block: block('company-info'),
                sample: DesignerSampleData.fallback,
              ),
            ],
          ),
        ),
      );
      expect(find.text('A TITLE'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          InfoBlock(
            block: block('client-info'),
            sample: DesignerSampleData.fallback,
          ),
        ),
      );
      expect(find.text('A TITLE'), findsOneWidget);
    });
  });

  group('a field added to the details block', () {
    Future<Map<String, dynamic>> add(
      WidgetTester tester, {
      required String search,
      required String row,
    }) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: 'co1',
        customFieldLabels: const {'invoice1': 'Project code'},
      );
      addTearDown(vm.dispose);
      vm.addBlock(blockSpecFor('invoice-details')!);
      final before =
          (vm.blocks.single.properties['fieldConfigs'] as List).length;
      await tester.pumpWidget(
        _wrap(
          ListenableBuilder(
            listenable: vm,
            builder: (_, _) =>
                InvoiceDetailsBlockProperties(vm: vm, block: vm.blocks.single),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Add Field'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, search);
      await tester.pump();
      await tester.tap(find.text(row).last);
      await tester.pumpAndSettle();
      final fields = vm.blocks.single.properties['fieldConfigs'] as List;
      expect(fields, hasLength(before + 1));
      return Map<String, dynamic>.from(fields.last as Map);
    }

    testWidgets('is labelled with a token the server translates', (
      tester,
    ) async {
      // It stored this app's translation key, which printed as `custom1`.
      final field = await add(tester, search: 'project', row: 'Project code');
      expect(field['variable'], r'$invoice.custom1');
      expect(field['label'], r'$invoice.custom1_label');
      // …and no prefix: the details block prints none.
      expect(field.containsKey('prefix'), isFalse);
      // The page reads that label as the PDF will print it.
      expect(
        replaceLabelVariables(
          field['label'] as String,
          (key) => key,
          customFieldLabels: const {'invoice1': 'Project code'},
        ),
        'Project code',
      );
    });

    testWidgets('uses the flat form the block\'s own rows use', (tester) async {
      final field = await add(tester, search: 'po_number', row: 'PO Number');
      expect(field['variable'], r'$po_number');
      expect(field['label'], r'$po_number_label');
    });

    testWidgets('terms is the server\'s `\$terms`', (tester) async {
      // `$invoice.terms` is not a variable the server has.
      final field = await add(tester, search: 'terms', row: 'Terms');
      expect(field['variable'], r'$terms');
      expect(field['label'], r'$terms_label');
    });
  });

  group('hide if empty', () {
    test('empty is blank, or a token nothing replaced', () {
      expect(resolvesEmpty(''), isTrue);
      expect(resolvesEmpty('   '), isTrue);
      expect(resolvesEmpty(r'$client.no_such_thing'), isTrue);
      expect(resolvesEmpty(r'Ref $unknown'), isTrue);
      // A literal typed in place of a variable prints.
      expect(resolvesEmpty('Dec 23, 2025'), isFalse);
      expect(resolvesEmpty(r'$ 12.00'), isFalse);
    });

    testWidgets('a row that does not say is hidden when empty', (tester) async {
      final block = DesignBlock(
        id: 'co',
        type: 'company-info',
        gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 2),
        properties: {
          'fieldConfigs': [
            {'id': 'a', 'label': 'name', 'variable': r'$company.name'},
            // No `hideIfEmpty`: on, as on the server.
            {'id': 'b', 'label': 'x', 'variable': r'$company.no_such_field'},
            {
              'id': 'c',
              'label': 'y',
              'variable': r'$company.no_such_field',
              'hideIfEmpty': false,
            },
          ],
        },
      );
      await tester.pumpWidget(
        _wrap(InfoBlock(block: block, sample: DesignerSampleData.fallback)),
      );
      expect(find.text('Your Company LLC'), findsOneWidget);
      expect(find.text(r'$company.no_such_field'), findsOneWidget);
    });

    testWidgets('a prefix prints as it is stored: trimmed', (tester) async {
      final block = DesignBlock(
        id: 'co',
        type: 'company-info',
        gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 2),
        properties: {
          'fieldConfigs': [
            {
              'id': 'a',
              'label': 'phone',
              'variable': r'$company.phone',
              'prefix': 'Tel: ',
            },
          ],
        },
      );
      await tester.pumpWidget(
        _wrap(InfoBlock(block: block, sample: DesignerSampleData.fallback)),
      );
      expect(find.text('Tel:(555) 987-6543'), findsOneWidget);
    });
  });

  group('an uploaded image', () {
    final dataUrl = 'data:image/png;base64,$_png';

    testWidgets('is drawn from memory — the network cannot fetch `data:`', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            height: 100,
            child: DesignerImage(
              source: dataUrl,
              placeholder: const Text('nothing'),
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect((image.image as MemoryImage).bytes, base64Decode(_png));
      expect(find.text('nothing'), findsNothing);
    });

    testWidgets('that is not an image, or no source at all, is the stand-in', (
      tester,
    ) async {
      for (final source in ['', '/logo180.png', 'data:nonsense']) {
        await tester.pumpWidget(
          _wrap(
            DesignerImage(source: source, placeholder: const Text('nothing')),
          ),
        );
        expect(find.text('nothing'), findsOneWidget, reason: '"$source"');
      }
    });

    testWidgets('on the page it is an image, and never its own text', (
      tester,
    ) async {
      final block = DesignBlock(
        id: 'img',
        type: 'image',
        gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 2),
        properties: {'source': dataUrl},
      );
      await tester.pumpWidget(
        _wrap(ImageBlock(block: block, sample: DesignerSampleData.fallback)),
      );
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      expect(find.textContaining('data:'), findsNothing);
    });

    testWidgets('leaves the address field empty in the panel', (tester) async {
      final vm = vmWith('image');
      final block = vm.blocks.single;
      vm.updateBlock(
        block.copyWith(properties: {...block.properties, 'source': dataUrl}),
      );
      await tester.pumpWidget(
        _wrap(ImageBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      // Megabytes of base64 in a text field, laid out every frame.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Image URL'))
            .controller!
            .text,
        '',
      );
      // …but the panel still shows the image, and still stores it.
      expect(find.byType(DesignerImage), findsOneWidget);
      expect(vm.blocks.single.properties['source'], dataUrl);
    });

    test('is not searched for colours', () {
      final big = 'data:image/png;base64,${'A' * 200000}#FF0000';
      expect(collectHexColors({'source': big, 'color': '#112233'}), [
        '#112233',
      ]);
    });
  });

  group('"Use this design" offers only types that have a default', () {
    test('a design\'s own list, narrowed', () {
      expect(designDefaultTypes(const ['quote', 'invoice']), [
        'invoice',
        'quote',
      ]);
      // Nothing listed is every type, not a dialog with nothing to tick.
      expect(designDefaultTypes(const []), kDesignDocumentTypes);
      // A statement has no default-design setting to write.
      expect(designDefaultTypes(const ['invoice', 'statement']), ['invoice']);
      expect(designDefaultTypes(const ['statement']), kDesignDocumentTypes);
    });
  });

  group('an imported file', () {
    test('with blocks is a visual design', () {
      final template = designTemplateFromJson(
        jsonEncode({
          'name': 'Exported',
          'design': {
            'body': '',
            'blocks': [
              {
                'id': 'a',
                'type': 'text',
                'gridPosition': {'x': 0, 'y': 0, 'w': 12, 'h': 1},
                'properties': {'content': 'Hello'},
              },
            ],
          },
        }),
      );
      expect(template!.blocks.single.properties['content'], 'Hello');
    });

    test('of HTML sections has none; one that is no design is refused', () {
      expect(
        designTemplateFromJson('{"design": {"body": "<p>x</p>"}}')!.blocks,
        isEmpty,
      );
      expect(designTemplateFromJson('{"name": "x"}'), isNull);
      expect(designTemplateFromJson('[1, 2]'), isNull);
      expect(designTemplateFromJson('not json'), isNull);
    });
  });
}
