// The recurring invoice record screen, assembled. What the five billing
// documents share is exercised in `invoices/invoice_detail_screen_test.dart`;
// this is what is a recurring invoice's own.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_detail_screen.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../billing_shared/detail/_billing_doc_fixtures.dart';

Map<String, dynamic> _recurring({
  String status = '2',
  String nextSend = '2999-02-01',
  String lastSent = '2000-03-01',
  int remainingCycles = -1,
  String autoBill = 'always',
  String dueDateDays = '15',
  bool deleted = false,
}) => {
  ...docJson(number: 'R-0005', status: status, deleted: deleted),
  'frequency_id': '5',
  'next_send_date': nextSend,
  'last_sent_date': lastSent,
  'remaining_cycles': remainingCycles,
  'auto_bill': autoBill,
  'due_date_days': dueDateDays,
};

void _screenTest(
  String description,
  Map<String, dynamic> recurring,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body,
) => recordScreenTest(
  description,
  seed: (services) async {
    await seedClient(services);
    await services.recurringInvoices.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: RecurringInvoiceApi.fromJson(recurring),
    );
  },
  screen: () => RecurringInvoiceDetailScreen(id: recurring['id'] as String),
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
  final strip = find.byType(EntityQuickActions<RecurringInvoiceAction>);
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
    'a running series: when it next goes out, how often, and the way to '
    'stop it',
    _recurring(),
    (tester, screen) async {
      final header = find.byType(BillingDocRecordHeader);
      expect(
        find.descendant(of: header, matching: find.text('RECURRING INVOICE')),
        findsOneWidget,
      );
      // It has no document date or due date of its own; the one date behind
      // it is when it last went out.
      expect(find.text('Last Sent Date: 2000-03-01'), findsOneWidget);
      expect(find.textContaining('Due Date: 2'), findsNothing);

      // The second figure is a date, not money.
      expect(_inStanding('AMOUNT'), findsOneWidget);
      expect(_inStanding('NEXT SEND DATE'), findsOneWidget);
      expect(_inStanding('2999-02-01'), findsOneWidget);
      expect(
        _inStanding('Frequency: Monthly · Remaining Cycles: Endless'),
        findsOneWidget,
      );
      // No deadline, so nothing here is ever "past due".
      expect(find.byType(BillingDocDueLine), findsNothing);

      // Running, so the switch reads Stop — and only Stop.
      expect(_tiles(tester), ['Stop', 'Email', 'PDF', 'Download']);

      // What is set on it that is not the default.
      expect(find.text('Day 15'), findsOneWidget);
      expect(find.text('Auto Bill'), findsOneWidget);
      expect(find.text('Enabled'), findsOneWidget);

      // The strip keeps its Schedule tab, after the document itself — and
      // the Overview now shows what each invoice in the series will carry.
      expect(
        tester.getTopLeft(find.text('Overview')).dx,
        lessThan(tester.getTopLeft(find.text('Schedule')).dx),
      );
      expect(find.text('Design'), findsOneWidget);
    },
  );

  _screenTest(
    'a draft series has nothing scheduled: one figure, and Start',
    _recurring(
      status: '1',
      nextSend: '',
      lastSent: '',
      remainingCycles: 12,
      autoBill: 'off',
      dueDateDays: 'terms',
    ),
    (tester, screen) async {
      expect(_inStanding('NEXT SEND DATE'), findsNothing);
      expect(
        _inStanding('Frequency: Monthly · Remaining Cycles: 12'),
        findsOneWidget,
      );
      expect(_tiles(tester), ['Start', 'Send Now', 'Email', 'PDF']);
      // The defaults are not rows.
      expect(find.text('Auto Bill'), findsNothing);
      expect(find.text('Due Date'), findsNothing);
    },
  );

  _screenTest('a deleted series is read-only', _recurring(deleted: true), (
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
