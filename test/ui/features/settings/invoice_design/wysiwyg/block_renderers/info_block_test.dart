import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/info_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';

import '../../../../../../_localization_helper.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  locale: const Locale('en'),
  theme: buildInTheme(InTheme.light),
  home: Scaffold(body: child),
);

DesignBlock _clientBlock({Map<String, dynamic>? overrides}) {
  final spec = blockSpecFor('client-info')!;
  final props = Map<String, dynamic>.from(spec.defaultProperties);
  if (overrides != null) props.addAll(overrides);
  return DesignBlock(
    id: 'ci-1',
    type: 'client-info',
    gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 4),
    properties: props,
  );
}

void main() {
  testWidgets('renders one row per fieldConfig with the substituted value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        InfoBlock(block: _clientBlock(), sample: DesignerSampleData.fallback),
      ),
    );
    await tester.pump();
    // Default client-info fields: name / address1 / city_state_postal /
    // phone / email — all populated by the Acme fixture.
    expect(find.text('Acme Corporation'), findsOneWidget);
    expect(find.text('123 Business Street'), findsOneWidget);
    expect(find.text('New York, NY 10001'), findsOneWidget);
    expect(find.text('(555) 123-4567'), findsOneWidget);
    expect(find.text('billing@acme.com'), findsOneWidget);
  });

  testWidgets('hideIfEmpty drops rows with empty resolved values', (
    tester,
  ) async {
    // Override one field to point at a sample field that resolves empty.
    final block = _clientBlock(
      overrides: {
        'fieldConfigs': [
          {
            'id': 'name',
            'label': 'client_name',
            'variable': r'$client.name',
            'hideIfEmpty': true,
          },
          {
            'id': 'shippingPhone',
            'label': 'phone',
            // No matching sample data — resolves to empty.
            'variable': r'$client.nonexistent_field',
            'hideIfEmpty': true,
          },
        ],
      },
    );
    await tester.pumpWidget(
      _wrap(InfoBlock(block: block, sample: DesignerSampleData.fallback)),
    );
    await tester.pump();
    expect(find.text('Acme Corporation'), findsOneWidget);
    // The empty field is dropped — no SizedBox.shrink leakage of text.
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('showTitle renders the translated title above the fields', (
    tester,
  ) async {
    final block = _clientBlock(
      overrides: {'showTitle': true, 'title': 'bill_to'},
    );
    await tester.pumpWidget(
      _wrap(InfoBlock(block: block, sample: DesignerSampleData.fallback)),
    );
    await tester.pump();
    // 'bill_to' translates to "Bill To" in en.json.
    expect(find.textContaining('Bill', findRichText: false), findsOneWidget);
  });

  testWidgets('prefix and suffix wrap the resolved value', (tester) async {
    final block = _clientBlock(
      overrides: {
        'fieldConfigs': [
          {
            'id': 'name',
            'label': 'client_name',
            'variable': r'$client.name',
            'prefix': '[',
            'suffix': ']',
          },
        ],
      },
    );
    await tester.pumpWidget(
      _wrap(InfoBlock(block: block, sample: DesignerSampleData.fallback)),
    );
    await tester.pump();
    expect(find.text('[Acme Corporation]'), findsOneWidget);
  });

  testWidgets(
    'invoice details: the longest value keeps its gap from the label',
    (tester) async {
      // The gap was a third table column pinned to zero width, so the row
      // with the longest value printed as "Due DateDec 23, 2025".
      final spec = blockSpecFor('invoice-details')!;
      final block = DesignBlock(
        id: 'details-1',
        type: 'invoice-details',
        gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 4),
        properties: {
          ...spec.defaultProperties,
          'labelValueGap': '12px',
          'fieldConfigs': [
            {'id': 'a', 'label': 'Due Date', 'variable': 'Dec 23, 2025'},
            {'id': 'b', 'label': 'No.', 'variable': '7'},
          ],
        },
      );
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            child: InvoiceDetailsBlock(
              block: block,
              sample: DesignerSampleData.fallback,
            ),
          ),
        ),
      );
      await tester.pump();
      for (final (label, value) in [
        ('Due Date', 'Dec 23, 2025'),
        ('No.', '7'),
      ]) {
        final labelRight = tester.getTopRight(find.text(label)).dx;
        final valueLeft = tester.getTopLeft(find.text(value)).dx;
        expect(
          valueLeft - labelRight,
          greaterThanOrEqualTo(12),
          reason: '$label / $value',
        );
      }
    },
  );
}
