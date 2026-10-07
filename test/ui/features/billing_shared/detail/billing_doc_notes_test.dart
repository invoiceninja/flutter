import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_notes.dart';

import '../../../../_localization_helper.dart';
import '_billing_doc_fixtures.dart';

Invoice _invoice(Map<String, dynamic> overrides) =>
    Invoice.fromApi(InvoiceApi.fromJson({...docJson(), ...overrides}));

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('the private note', () {
    test('is content only when it holds words', () {
      expect(
        BillingDocPrivateNotesCard.hasContent(_invoice({'private_notes': 'x'})),
        isTrue,
      );
      // HTML on the wire: markup that renders as nothing is not a note.
      for (final empty in ['', '<p></p>', '<p><br></p>']) {
        expect(
          BillingDocPrivateNotesCard.hasContent(
            _invoice({'private_notes': empty}),
          ),
          isFalse,
          reason: '"$empty"',
        );
      }
    });

    testWidgets('shows the words, not the markup', (tester) async {
      await _pump(
        tester,
        BillingDocPrivateNotesCard(
          doc: _invoice({'private_notes': '<p>Call <b>Jane</b> first.</p>'}),
        ),
      );
      expect(find.text('Private Notes'), findsOneWidget);
      expect(find.text('Call Jane first.'), findsOneWidget);
    });
  });

  group('what prints on the document', () {
    testWidgets('public notes, terms, then footer — the order on the page', (
      tester,
    ) async {
      await _pump(
        tester,
        BillingDocPrintedNotesCard(
          doc: _invoice({
            'public_notes': 'Thanks.',
            'terms': 'Net 30.',
            'footer': 'Registered in Berlin.',
          }),
        ),
      );
      final notes = tester.getTopLeft(find.text('Thanks.')).dy;
      final terms = tester.getTopLeft(find.text('Net 30.')).dy;
      // The footer was never shown read-only before.
      final footer = tester.getTopLeft(find.text('Registered in Berlin.')).dy;
      expect(notes, lessThan(terms));
      expect(terms, lessThan(footer));
      expect(find.text('Public Notes'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
    });

    testWidgets('an empty field has no block, and its label is not printed', (
      tester,
    ) async {
      await _pump(
        tester,
        BillingDocPrintedNotesCard(
          doc: _invoice({
            'public_notes': '',
            'terms': 'Net 30.',
            'footer': '<p></p>',
          }),
        ),
      );
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Public Notes'), findsNothing);
      expect(find.text('Footer'), findsNothing);
    });

    test('the private note is not one of them', () {
      // It never prints, so a document with only a private note has nothing
      // to show under its totals.
      expect(
        BillingDocPrintedNotesCard.hasContent(
          _invoice({
            'private_notes': 'internal',
            'public_notes': '',
            'terms': '',
            'footer': '',
          }),
        ),
        isFalse,
      );
    });

    testWidgets('a page of terms is clamped, with the rest one tap away', (
      tester,
    ) async {
      final terms = List.filled(
        40,
        'Payment is due within thirty days.',
      ).join(' ');
      await _pump(
        tester,
        SizedBox(
          width: 400,
          child: BillingDocPrintedNotesCard(
            doc: _invoice({'public_notes': '', 'terms': terms, 'footer': ''}),
          ),
        ),
      );
      final clamped = tester.getSize(find.byType(BillingDocPrintedNotesCard));
      expect(find.text('More'), findsOneWidget);
      await tester.tap(find.text('More'));
      await tester.pump();
      expect(
        tester.getSize(find.byType(BillingDocPrintedNotesCard)).height,
        greaterThan(clamped.height),
      );
      expect(find.text('Less'), findsOneWidget);
    });
  });
}
