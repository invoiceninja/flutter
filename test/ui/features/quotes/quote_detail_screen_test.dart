// The quote record screen, assembled. What the five billing documents share
// is exercised in `invoices/invoice_detail_screen_test.dart`; this is what is
// a quote's own.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/quotes/views/quote_detail_screen.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../billing_shared/detail/_billing_doc_fixtures.dart';

void _screenTest(
  String description,
  Map<String, dynamic> quote,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body,
) => recordScreenTest(
  description,
  seed: (services) async {
    await seedClient(services);
    await services.quotes.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: QuoteApi.fromJson(quote),
    );
  },
  screen: () => QuoteDetailScreen(id: quote['id'] as String),
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
  final strip = find.byType(EntityQuickActions<QuoteAction>);
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

Text _line(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byType(BillingDocDueLine),
    matching: find.byType(Text),
  ),
);

void main() {
  _screenTest(
    'a sent quote: it is waiting on a yes, so Approve and Convert lead',
    docJson(number: 'Q-0018'),
    (tester, screen) async {
      final header = find.byType(BillingDocRecordHeader);
      expect(
        find.descendant(of: header, matching: find.text('QUOTE')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('#Q-0018')),
        findsOneWidget,
      );
      // A quote's second date is how long it stands, not when it is due.
      expect(find.text('Valid Until: 2999-01-01'), findsOneWidget);
      expect(_tiles(tester), ['Approve', 'Convert', 'Email', 'PDF']);

      // One figure: a quote has an amount and nothing owed on it.
      expect(
        find.descendant(
          of: find.byType(StandingCard),
          matching: find.text('AMOUNT'),
        ),
        findsOneWidget,
      );
      expect(find.text('BALANCE DUE'), findsNothing);
      final line = _line(tester);
      expect(line.data, startsWith('Expires: '));
      expect(line.style?.color, InTheme.light.ink2);
    },
  );

  _screenTest(
    'a draft quote: getting it out comes first',
    docJson(status: '1', sent: false),
    (tester, screen) async {
      expect(_tiles(tester), ['Mark Sent', 'Email', 'PDF', 'Download']);
    },
  );

  _screenTest(
    'a quote past its valid-until date says it expired, in the overdue ink',
    docJson(due: '2000-02-01'),
    (tester, screen) async {
      final line = _line(tester);
      expect(line.data, startsWith('Expired: '));
      expect(line.style?.color, InTheme.light.overdue);
      // The server will not convert an expired quote, so that is no tile.
      expect(_tiles(tester), isNot(contains('Convert')));
    },
  );

  _screenTest(
    'an approved quote is no longer waiting, however old its date',
    docJson(status: '3', due: '2000-02-01'),
    (tester, screen) async {
      expect(find.byType(BillingDocDueLine), findsNothing);
      expect(_tiles(tester).first, 'Convert');
    },
  );

  test('the line is late exactly when the quote itself says it expired', () {
    for (final status in ['1', '2', '3', '4', '5', '-1']) {
      for (final due in ['2000-01-01', '2999-01-01']) {
        final quote = Quote.fromApi(
          QuoteApi.fromJson(docJson(status: status, due: due)),
        );
        expect(
          quoteAwaitsAnswer(quote) && due.startsWith('2000'),
          quote.isExpired,
          reason: 'status $status, due $due',
        );
      }
    }
  });

  _screenTest('a deleted quote is read-only', docJson(deleted: true), (
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
