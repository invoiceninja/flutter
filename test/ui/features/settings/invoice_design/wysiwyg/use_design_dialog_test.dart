import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/use_design_dialog.dart';

import '../../../../../_localization_helper.dart';

void main() {
  group('entitiesUsingDesign', () {
    const settings = CompanySettings(
      invoiceDesignId: 'd1',
      quoteDesignId: 'd2',
      creditDesignId: 'd1',
    );

    test('the document types whose default the design is', () {
      expect(entitiesUsingDesign(settings, 'd1'), ['invoice', 'credit']);
      expect(entitiesUsingDesign(settings, 'd2'), ['quote']);
      expect(entitiesUsingDesign(settings, 'd9'), isEmpty);
    });

    test('a design with no id is used nowhere', () {
      // An unset `*_design_id` must not match an unsaved design's ''.
      expect(entitiesUsingDesign(const CompanySettings(), ''), isEmpty);
      expect(entitiesUsingDesign(const CompanySettings(), null), isEmpty);
    });
  });

  group('planUseDesign', () {
    const before = CompanySettings(invoiceDesignId: 'old', quoteDesignId: 'q');

    test('sets the chosen types and leaves the others', () {
      final plan = planUseDesign(
        before,
        designId: 'new',
        entities: const ['invoice', 'purchase_order'],
        updateExisting: false,
      );
      expect(plan.settings.invoiceDesignId, 'new');
      expect(plan.settings.purchaseOrderDesignId, 'new');
      expect(plan.settings.quoteDesignId, 'q');
      expect(plan.settings.creditDesignId, before.creditDesignId);
      // Existing documents are left alone unless asked.
      expect(plan.outboxExtra, isNull);
    });

    test('existing documents follow through the update-all directive', () {
      final plan = planUseDesign(
        before,
        designId: 'new',
        entities: const ['invoice', 'quote'],
        updateExisting: true,
      );
      // The shape `CompanySyncDispatcher` pops off the company save.
      expect(plan.outboxExtra, {
        '_design_updates': [
          {'design_id': 'new', 'entity': 'invoice'},
          {'design_id': 'new', 'entity': 'quote'},
        ],
      });
    });

    test('nothing chosen writes nothing', () {
      final plan = planUseDesign(
        before,
        designId: 'new',
        entities: const [],
        updateExisting: true,
      );
      expect(plan.settings, before);
      expect(plan.outboxExtra, isNull);
    });
  });

  group('UseDesignDialog', () {
    Future<UseDesignChoice? Function()> open(
      WidgetTester tester, {
      List<String> entities = const ['invoice', 'quote'],
      Set<String> alreadyUsing = const {},
    }) async {
      UseDesignChoice? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          locale: const Locale('en'),
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await showDialog<UseDesignChoice>(
                      context: context,
                      builder: (_) => UseDesignDialog(
                        entities: entities,
                        alreadyUsing: alreadyUsing,
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('every type it applies to starts ticked; one can be unticked', (
      tester,
    ) async {
      final result = await open(tester);
      await tester.tap(find.text('Quotes'));
      await tester.pump();
      await tester.tap(find.text('Use this design'));
      await tester.pumpAndSettle();
      expect(result()!.entities, {'invoice'});
      expect(result()!.updateExisting, isFalse);
    });

    testWidgets('existing documents only when asked', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text('Also change existing documents to it'));
      await tester.pump();
      await tester.tap(find.text('Use this design'));
      await tester.pumpAndSettle();
      expect(result()!.entities, {'invoice', 'quote'});
      expect(result()!.updateExisting, isTrue);
    });

    testWidgets('a stray Enter changes nothing', (tester) async {
      // It switches what customers are sent, and it can open straight after
      // a ⌘S: the confirm must not be sitting under the Enter key.
      final result = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(UseDesignDialog), findsOneWidget);
      expect(result(), isNull);
    });

    testWidgets('nothing ticked: nothing to apply', (tester) async {
      final result = await open(tester, entities: const ['invoice']);
      await tester.tap(find.text('Invoices'));
      await tester.pump();
      await tester.tap(find.text('Use this design'));
      await tester.pumpAndSettle();
      // Still open — the button is disabled.
      expect(find.byType(UseDesignDialog), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(result(), isNull);
    });

    testWidgets('types that already use it are stated, not offered again', (
      tester,
    ) async {
      final result = await open(tester, alreadyUsing: const {'invoice'});
      expect(find.text('Already used for: Invoices'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Invoices'), findsNothing);
      await tester.tap(find.text('Use this design'));
      await tester.pumpAndSettle();
      expect(result()!.entities, {'quote'});
    });

    testWidgets('used everywhere it applies: only a way out', (tester) async {
      await open(tester, alreadyUsing: const {'invoice', 'quote'});
      expect(find.text('Already used for: Invoices, Quotes'), findsOneWidget);
      expect(find.text('Use this design'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
