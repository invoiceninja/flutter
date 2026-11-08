import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/billing_shared/detail/signed_document_pill.dart';

import '../../../_localization_helper.dart';

/// The DocuNinja "Signed Document" pill beside a billing document's status
/// pill (React's green badge): shown only for a signed document while
/// DocuNinja is on, and a tap opens the (signed) PDF.
void main() {
  group('showSignedDocumentPill', () {
    const on = Company(id: 'c', enableModules: true);
    const off = Company(id: 'c');
    const signed = {'dn_completed': true};

    bool show(
      Map<String, dynamic>? sync,
      Company? company, {
      bool plan = true,
    }) => showSignedDocumentPill(sync, company, planActive: plan);

    test('needs a signed document and DocuNinja active', () {
      expect(show(signed, on), isTrue);
      expect(show({'dn_completed': false}, on), isFalse);
      expect(show(null, on), isFalse);
      // Off, the server serves an unsigned render, so the pill would lie.
      expect(show(signed, off), isFalse);
      expect(show(signed, null), isFalse);
      // So it does after the plan lapses, though `enable_modules` stays on.
      expect(show(signed, on, plan: false), isFalse);
    });
  });

  testWidgets("shows React's label in the paid colours and opens the PDF", (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(child: SignedDocumentPill(onTap: () => opened++)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed Document'), findsOneWidget);
    final pill = tester.widget<StatusPill>(find.byType(StatusPill));
    expect(pill.fgColor, InTheme.light.paid);
    expect(pill.bgColor, InTheme.light.paidSoft);

    await tester.tap(find.text('Signed Document'));
    expect(opened, 1);
  });
}
