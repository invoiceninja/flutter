import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';

import '../../../../_localization_helper.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// Resolve [token] through the real localization, the way the chips do.
Future<TemplateVariableDisplay?> _describe(
  WidgetTester tester,
  String token,
  TemplateVariableScope scope, {
  TemplateVariableValue? value,
}) async {
  TemplateVariableDisplay? display;
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) {
          display = describeTemplateVariable(
            context,
            token,
            scope,
            value: value,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return display;
}

void main() {
  group('describeTemplateVariable', () {
    testWidgets('a catalogued token in scope reads its friendly label', (
      tester,
    ) async {
      final display = await _describe(
        tester,
        r'$company.name',
        TemplateVariableScope.invoice,
      );
      expect(display!.label, 'Company Name');
      expect(display.value, isNull);
      expect(display.warning, isNull);
      expect(display.monospace, isFalse);
    });

    testWidgets('a generic field is qualified by its group', (tester) async {
      final display = await _describe(
        tester,
        r'$company.address1',
        TemplateVariableScope.invoice,
      );
      expect(display!.label, 'Company · Street');
    });

    testWidgets('the label follows the scope', (tester) async {
      expect(
        (await _describe(
          tester,
          r'$number',
          TemplateVariableScope.quote,
        ))!.label,
        'Quote Number',
      );
    });

    testWidgets('a token the template\'s engine lacks warns "Not available"', (
      tester,
    ) async {
      final display = await _describe(
        tester,
        r'$payment_button',
        TemplateVariableScope.payment,
      );
      expect(display!.label, 'Pay Now');
      expect(display.warning, 'Not available');
    });

    testWidgets('an uncatalogued token without a probe stays plain text', (
      tester,
    ) async {
      expect(
        await _describe(tester, r'$not_listed', TemplateVariableScope.invoice),
        isNull,
      );
    });

    testWidgets('a probe outranks the catalog', (tester) async {
      final resolved = await _describe(
        tester,
        r'$company.name',
        TemplateVariableScope.invoice,
        value: const TemplateVariableResolved('Acme Ltd'),
      );
      expect(resolved!.value, 'Acme Ltd');

      final empty = await _describe(
        tester,
        r'$po_number',
        TemplateVariableScope.invoice,
        value: const TemplateVariableEmpty(),
      );
      expect(empty!.value, '');

      final unknown = await _describe(
        tester,
        r'$compnay.name',
        TemplateVariableScope.invoice,
        value: const TemplateVariableUnknown(),
      );
      expect(unknown!.warning, 'Not recognized');
      expect(unknown.label, r'$compnay.name');
      expect(unknown.monospace, isTrue);

      final uncatalogued = await _describe(
        tester,
        r'$invoice.date',
        TemplateVariableScope.invoice,
        value: const TemplateVariableResolved('Sep 11, 2026'),
      );
      expect(uncatalogued!.label, r'$invoice.date');
      expect(uncatalogued.value, 'Sep 11, 2026');
    });
  });

  group('TemplateVariableChip', () {
    testWidgets('label only: not lowercased, no second slot', (tester) async {
      await tester.pumpWidget(
        _host(
          const TemplateVariableChip(
            display: TemplateVariableDisplay(
              token: r'$po_number',
              label: 'PO Number',
            ),
          ),
        ),
      );
      expect(find.text('PO Number'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('label + value, and an em dash for an empty value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              TemplateVariableChip(
                display: TemplateVariableDisplay(
                  token: r'$company.name',
                  label: 'Company Name',
                  value: 'Acme Ltd',
                ),
              ),
              TemplateVariableChip(
                display: TemplateVariableDisplay(
                  token: r'$po_number',
                  label: 'PO Number',
                  value: '',
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Acme Ltd'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('a warning is amber with an icon, never the overdue red', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TemplateVariableChip(
            display: TemplateVariableDisplay(
              token: r'$nope',
              label: r'$nope',
              monospace: true,
              warning: 'Not recognized',
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(TemplateVariableChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, InTheme.light.warningSoft);
      expect(decoration.color, isNot(InTheme.light.overdueSoft));
    });

    testWidgets('an editable chip carries the ▾ cue; an inert one does not', (
      tester,
    ) async {
      const display = TemplateVariableDisplay(
        token: r'$number',
        label: 'Invoice Number',
      );
      await tester.pumpWidget(
        _host(const TemplateVariableChip(display: display, editable: true)),
      );
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      await tester.pumpWidget(
        _host(const TemplateVariableChip(display: display)),
      );
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('fits a 14 × 1.4 line at the default size', (tester) async {
      await tester.pumpWidget(
        _host(
          const TemplateVariableChip(
            display: TemplateVariableDisplay(
              token: r'$number',
              label: 'Invoice Number',
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(TemplateVariableChip)).height,
        lessThanOrEqualTo(14 * 1.4 + 1),
      );
    });
  });
}
