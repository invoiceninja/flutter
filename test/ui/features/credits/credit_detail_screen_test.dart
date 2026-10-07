// The credit record screen, assembled. What the five billing documents share
// is exercised in `invoices/invoice_detail_screen_test.dart`; this is what is
// a credit's own.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/credits/views/credit_detail_screen.dart';
import 'package:admin/ui/features/credits/widgets/credit_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../billing_shared/detail/_billing_doc_fixtures.dart';

void _screenTest(
  String description,
  Map<String, dynamic> credit,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body,
) => recordScreenTest(
  description,
  seed: (services) async {
    await seedClient(services);
    await services.credits.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: CreditApi.fromJson(credit),
    );
  },
  screen: () => CreditDetailScreen(id: credit['id'] as String),
  ready: () => find.byType(StandingCard),
  body: (tester, screen) async {
    await screen.untilFound(
      find.byType(BillingDocContactsCard),
      'the contacts',
    );
    await body(tester, screen);
  },
);

List<String> _tiles(WidgetTester tester) {
  final strip = find.byType(EntityQuickActions<CreditAction>);
  if (strip.evaluate().isEmpty) return const [];
  final texts =
      find
          .descendant(of: strip, matching: find.byType(Text))
          .evaluate()
          .map((e) => e.widget as Text)
          .toList()
        ..sort(
          (a, b) => tester
              .getTopLeft(find.byWidget(a))
              .dx
              .compareTo(tester.getTopLeft(find.byWidget(b)).dx),
        );
  return [for (final t in texts) t.data ?? ''];
}

Finder _inStanding(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

void main() {
  _screenTest(
    'a part-used credit: what it was, what is left, and what has been applied',
    docJson(number: 'CR-0003', status: '3', balance: '720.00', paid: '3000.00'),
    (tester, screen) async {
      expect(
        find.descendant(
          of: find.byType(BillingDocRecordHeader),
          matching: find.text('CREDIT'),
        ),
        findsOneWidget,
      );
      expect(_inStanding('AMOUNT'), findsOneWidget);
      expect(_inStanding('CREDIT REMAINING'), findsOneWidget);
      expect(_inStanding(r'$720.00'), findsOneWidget);
      // Applied is this document's "paid" — shown because it is not zero.
      expect(_inStanding('Applied'), findsOneWidget);
      expect(_inStanding(r'$3,000.00'), findsOneWidget);
      // A credit's date is not a deadline anyone is held to.
      expect(find.byType(BillingDocDueLine), findsNothing);
      // There is some left, so using it leads.
      expect(_tiles(tester), ['Apply', 'Email', 'PDF', 'Download']);
    },
  );

  _screenTest(
    'a used-up credit prints its zero and offers nothing to apply',
    docJson(status: '4', balance: '0', paid: '3720.00'),
    (tester, screen) async {
      expect(_inStanding(r'$0.00'), findsOneWidget);
      expect(_tiles(tester), isNot(contains('Apply')));
    },
  );

  _screenTest('a deleted credit is read-only', docJson(deleted: true), (
    tester,
    screen,
  ) async {
    expect(
      find.text('This record is deleted. Restore it to make changes.'),
      findsOneWidget,
    );
    expect(_tiles(tester), isEmpty);
  });
}
