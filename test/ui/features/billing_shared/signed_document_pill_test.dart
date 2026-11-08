import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/docuninja/docuninja_signed.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/billing_shared/detail/signed_document_pill.dart';

import '../../../_localization_helper.dart';

/// The DocuNinja "Signed Document" pill beside a billing document's status
/// pill (React's green badge): shown only for a signed document while
/// DocuNinja is on, and a tap opens the (signed) PDF.
void main() {
  group('docuNinjaPlanActive', () {
    AuthSession session({
      bool hosted = true,
      String plan = 'pro',
      String expires = '',
      int trialDaysLeft = -1,
    }) => AuthSession(
      baseUrl: 'https://invoicing.co',
      isHosted: hosted,
      accountId: 'a',
      companies: const [],
      currentCompanyId: 'c',
      plan: plan,
      planExpires: expires,
      trialDaysLeft: trialDaysLeft,
    );

    test('a hosted Pro, Enterprise or trial account, as the server has it', () {
      expect(docuNinjaPlanActive(session()), isTrue);
      expect(docuNinjaPlanActive(session(plan: 'enterprise')), isTrue);
      expect(docuNinjaPlanActive(session(plan: '', trialDaysLeft: 5)), isTrue);
    });

    test('not on a free or lapsed plan, self-hosted, or signed out', () {
      expect(docuNinjaPlanActive(session(plan: '')), isFalse);
      expect(docuNinjaPlanActive(session(expires: '2020-01-01')), isFalse);
      expect(docuNinjaPlanActive(session(hosted: false)), isFalse);
      expect(docuNinjaPlanActive(null), isFalse);
    });
  });

  test('the signed key ignores an unsynced edit; the stored key does not', () {
    final invoice = emptyInvoice().copyWith(
      id: 'i1',
      isDirty: true,
      invitations: const [
        Invitation(clientContactId: 'c'),
        Invitation(key: 'k'),
      ],
    );
    expect(invoice.storedPdfInvitationKey, isNull);
    expect(invoice.signedPdfInvitationKey, 'k');
    expect(
      invoice.copyWith(id: 'tmp_1').signedPdfInvitationKey,
      isNull,
      reason: 'an unsaved record has nothing stored',
    );
  });

  test('the signed file must still be among the record\'s documents', () {
    const sync = {'dn_completed': true, 'dn_document_hashed_id': 'd1'};
    expect(hasSignedFile(sync, ['d0', 'd1']), isTrue);
    expect(hasSignedFile(sync, ['d0']), isFalse);
    expect(hasSignedFile({'dn_completed': true}, ['d1']), isFalse);
    expect(hasSignedFile(null, ['d1']), isFalse);
  });

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
