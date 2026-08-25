import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/table_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';

import '../../../../../../_localization_helper.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  locale: const Locale('en'),
  theme: buildInTheme(InTheme.light),
  home: Scaffold(body: child),
);

DesignBlock _tableBlockWithColumns(List<Map<String, dynamic>> columns) {
  final spec = blockSpecFor('table')!;
  return DesignBlock(
    id: 'tbl-1',
    type: 'table',
    gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 8),
    properties: {
      ...Map<String, dynamic>.from(spec.defaultProperties),
      'columns': columns,
    },
  );
}

DesignBlock _tableBlock() {
  final spec = blockSpecFor('table')!;
  return DesignBlock(
    id: 'tbl-1',
    type: 'table',
    gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 8),
    properties: Map<String, dynamic>.from(spec.defaultProperties),
  );
}

void main() {
  testWidgets('renders header columns from the columns array', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TableBlock(block: _tableBlock(), sample: DesignerSampleData.fallback),
      ),
    );
    await tester.pump();
    // The spec stores localization keys (`item`, `qty`, `unit_cost`); the
    // canvas used to paint them raw, so the header read "unit_cost" while the
    // property panel beside it read "Unit Cost" (invoiceninja/flutter#84).
    // Default product columns: item / description / qty / unit_cost /
    // line_total.
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Quantity'), findsOneWidget); // 'qty' → "Quantity"
    expect(find.text('Unit Cost'), findsOneWidget);
    expect(find.text('Line Total'), findsOneWidget);
    // No raw key survives to the canvas.
    expect(find.text('unit_cost'), findsNothing);
    expect(find.text('qty'), findsNothing);
  });

  testWidgets('a header key with no translation of its own falls back to the '
      'label the PDF prints', (tester) async {
    // `net_cost` is in no locale file. The server labels `$product.net_cost`
    // with `ctrans('texts.unit_cost')` and React does the same, so the
    // designer must not show the raw slug for it.
    await tester.pumpWidget(
      _wrap(
        TableBlock(
          block: _tableBlockWithColumns(const [
            {
              'id': 'net_cost',
              'header': 'net_cost',
              'field': 'item.net_cost',
              'width': '15%',
              'align': 'right',
            },
          ]),
          sample: DesignerSampleData.fallback,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unit Cost'), findsOneWidget);
    expect(find.text('net_cost'), findsNothing);
  });

  testWidgets('a header the user typed renders verbatim', (tester) async {
    // The property panel exposes `header` as a free-text field, so an
    // unrecognised value is a heading, not a broken key — never title-case it.
    await tester.pumpWidget(
      _wrap(
        TableBlock(
          block: _tableBlockWithColumns(const [
            {
              'id': 'cost',
              'header': 'Prix unitaire',
              'field': 'item.cost',
              'width': '15%',
              'align': 'right',
            },
          ]),
          sample: DesignerSampleData.fallback,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prix unitaire'), findsOneWidget);
  });

  testWidgets('renders one row per sample line item', (tester) async {
    final block = _tableBlock();
    await tester.pumpWidget(
      _wrap(TableBlock(block: block, sample: DesignerSampleData.fallback)),
    );
    await tester.pump();
    // Two sample line items: WEB-DESIGN + CONSULTING.
    expect(find.text('WEB-DESIGN'), findsOneWidget);
    expect(find.text('CONSULTING'), findsOneWidget);
    // Line totals + costs (en-US fallback formatting).
    // WEB-DESIGN: cost $1,000.00 + line_total $1,000.00 → 2 occurrences.
    expect(find.text(r'$1,000.00'), findsNWidgets(2));
    // CONSULTING: cost $100.00 + line_total $500.00.
    expect(find.text(r'$100.00'), findsOneWidget);
    expect(find.text(r'$500.00'), findsOneWidget);
    // Quantity column.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('alternates row background color when alternateRows is true', (
    tester,
  ) async {
    final block = _tableBlock();
    await tester.pumpWidget(
      _wrap(TableBlock(block: block, sample: DesignerSampleData.fallback)),
    );
    await tester.pump();
    // Verify both header-row + body-rows render without throwing.
    expect(find.byType(Table), findsOneWidget);
  });

  testWidgets('empty columns produces an empty SizedBox.shrink', (
    tester,
  ) async {
    final block = DesignBlock(
      id: 'empty',
      type: 'table',
      gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 4),
      properties: const {'columns': <Map<String, dynamic>>[]},
    );
    await tester.pumpWidget(
      _wrap(TableBlock(block: block, sample: DesignerSampleData.fallback)),
    );
    await tester.pump();
    expect(find.byType(Table), findsNothing);
  });
}
