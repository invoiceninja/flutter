// A new document shows the settings-cascade defaults the server fills in for
// a blank field — the terms and footer muted in their fields, the payment
// terms under the due date — without writing them into the draft. A user saw
// empty fields and concluded the app ignored the company's defaults.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

import '../../shell/_shell_test_helpers.dart';
import '_billing_edit_harness.dart';

/// The helper line under the field labelled [label], or null without one.
String? helperOf(WidgetTester tester, String label) => tester
    .widgetList<InputDecorator>(find.byType(InputDecorator))
    .firstWhere((d) => d.decoration.labelText == label)
    .decoration
    .helperText;

void main() {
  const caption =
      'Showing the default. Edit it to change it for this '
      'document only.';

  for (final width in [390.0, 1440.0]) {
    testWidgets('invoice at ${width.toInt()} px: the defaults are shown, not '
        'saved', (tester) async {
      setWindow(tester, width);
      final fixture = await buildFixture(
        closeStreamsSynchronously: true,
        companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
      );
      addTearDown(fixture.dispose);
      final mounted = buildLayout(
        BillingDoc.invoice,
        fixture.services,
        showPdfTab: width >= 600,
      );
      addTearDown(mounted.vm.dispose);
      final vm = mounted.vm as BillingDocEditViewModel;
      await tester.pumpWidget(wrapWithShell(fixture.services, mounted.layout));
      await settle(tester);
      expect(find.text('Net 30'), findsNothing);

      vm.setCreateCascade({
        'invoice_terms': 'Pay within 30 days',
        'invoice_footer': 'Thank you',
        'payment_terms': '30',
      });
      await settle(tester);
      expect(find.text('Net 30'), findsOneWidget);

      // A partial without its own due date is what the payment terms date,
      // so the hint moves there.
      (vm as dynamic).setPartial('10');
      await settle(tester);
      expect(helperOf(tester, 'Due Date'), isNull);
      expect(helperOf(tester, 'Partial Due Date'), 'Net 30');
      (vm as dynamic).setPartial('');
      await settle(tester);
      expect(helperOf(tester, 'Due Date'), 'Net 30');

      if (width < 600) {
        final notes = tabBarLabels(tester).first.indexOf('Notes');
        await showTab(tester, notes);
        // Terms and footer, stacked.
        expect(find.text(caption), findsNWidgets(2));
      } else {
        // The notes card opens on its Terms tab.
        expect(find.text(caption), findsOneWidget);
      }
      expect(
        find.textContaining('Pay within 30 days', findRichText: true),
        findsOneWidget,
      );
      expect(vm.draft.terms, '');
      expect(vm.draft.footer, '');
      expect(vm.isDirty, isFalse);
      // Over the default itself it would clear the company setting, or copy a
      // client's default up to the company — so it is there, but off.
      final saves = tester.widgetList<TextButton>(
        find.widgetWithText(TextButton, 'Save as default'),
      );
      expect(saves, isNotEmpty);
      expect(saves.every((b) => b.onPressed == null), isTrue);

      // A date the user sets replaces the hint.
      vm.setDueDate(vm.draft.date);
      await settle(tester);
      expect(find.text('Net 30'), findsNothing);

      await unmount(tester, fixture);
    });
  }

  testWidgets('a quote states its validity in days, not as payment terms', (
    tester,
  ) async {
    setWindow(tester, 1440);
    final fixture = await buildFixture(
      closeStreamsSynchronously: true,
      companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
    );
    addTearDown(fixture.dispose);
    final mounted = buildLayout(
      BillingDoc.quote,
      fixture.services,
      showPdfTab: true,
    );
    addTearDown(mounted.vm.dispose);
    final vm = mounted.vm as BillingDocEditViewModel;
    await tester.pumpWidget(wrapWithShell(fixture.services, mounted.layout));
    await settle(tester);

    vm.setCreateCascade({'valid_until': '14', 'payment_terms': '30'});
    await settle(tester);
    expect(find.text('14 Days'), findsOneWidget);
    expect(find.textContaining('Net'), findsNothing);

    // `valid_until` 0 still dates the quote: its own date.
    vm.setCreateCascade({'valid_until': '0'});
    await settle(tester);
    expect(find.text('0 Days'), findsOneWidget);

    await unmount(tester, fixture);
  });
}
