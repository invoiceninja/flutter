import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_due_note.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';

import '../../../../_localization_helper.dart';

/// The line under a billing document's figures. The card around it needs the
/// whole app (it resolves the party's currency) and is exercised by the five
/// `*_detail_screen_test.dart`; the wording and the one red are pinned here,
/// where the day count is exact.
void main() {
  final invoiceKeys = BillingDocType.invoice.dueNoteLabelKeys!;
  final quoteKeys = BillingDocType.quote.dueNoteLabelKeys!;

  Future<Text> pumpLine(
    WidgetTester tester,
    BillingDocDueNote note,
    ({String upcoming, String late}) keys,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: BillingDocDueLine(note: note, labelKeys: keys),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<Text>(find.byType(Text));
  }

  testWidgets('an invoice still ahead of its date says how long is left', (
    tester,
  ) async {
    final line = await pumpLine(
      tester,
      const BillingDocDueNote(BillingDocDueState.upcoming, 5),
      invoiceKeys,
    );
    expect(line.data, 'Due: 5 Days');
    expect(line.style?.color, InTheme.light.ink2);
  });

  testWidgets('one day is "1 Day" — the unit is the bundle\'s own noun', (
    tester,
  ) async {
    // The bundles have no plural forms, so there is no "1 days" to print:
    // the count is paired with `day` or `days`.
    expect(
      (await pumpLine(
        tester,
        const BillingDocDueNote(BillingDocDueState.upcoming, 1),
        invoiceKeys,
      )).data,
      'Due: 1 Day',
    );
    expect(
      (await pumpLine(
        tester,
        const BillingDocDueNote(BillingDocDueState.late, 1),
        invoiceKeys,
      )).data,
      'Past Due: 1 Day',
    );
  });

  testWidgets('due today says so', (tester) async {
    final line = await pumpLine(
      tester,
      const BillingDocDueNote(BillingDocDueState.today, 0),
      invoiceKeys,
    );
    expect(line.data, 'Due: Today');
    expect(line.style?.color, InTheme.light.ink2, reason: 'today is not late');
  });

  testWidgets('a late invoice is "Past Due", in the overdue ink', (
    tester,
  ) async {
    final line = await pumpLine(
      tester,
      const BillingDocDueNote(BillingDocDueState.late, 12),
      invoiceKeys,
    );
    // `past_due`, never `overdue`: the French translation of `overdue` reads
    // "unpaid".
    expect(line.data, 'Past Due: 12 Days');
    expect(line.style?.color, InTheme.light.overdue);
    expect(line.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('a quote expires rather than falls due', (tester) async {
    expect(
      (await pumpLine(
        tester,
        const BillingDocDueNote(BillingDocDueState.upcoming, 14),
        quoteKeys,
      )).data,
      'Expires: 14 Days',
    );
    final expired = await pumpLine(
      tester,
      const BillingDocDueNote(BillingDocDueState.late, 3),
      quoteKeys,
    );
    expect(expired.data, 'Expired: 3 Days');
    expect(expired.style?.color, InTheme.light.overdue);
  });
}
