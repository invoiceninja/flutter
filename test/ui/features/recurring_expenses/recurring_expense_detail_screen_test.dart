// The recurring expense record screen, assembled — the record layout end to
// end against a real `Services` graph and a real local database, with the
// network played by a `MockClient`. The harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_detail_screen.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_header.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

/// A running monthly schedule with nine runs left, last run in October.
Map<String, dynamic> _json({
  String id = 'r1',
  bool isDeleted = false,
  int archivedAt = 0,
  String amount = '54.99',
  int updatedAt = 1710000000,
}) => {
  'id': id,
  'number': '0007',
  'vendor_id': 'v1',
  'category_id': 'cat1',
  'project_id': 'p1',
  'currency_id': '1',
  'frequency_id': '5',
  'remaining_cycles': 9,
  'next_send_date': '2026-11-01',
  'last_sent_date': '2026-10-01',
  'status_id': '2',
  'amount': amount,
  'tax_name1': 'VAT',
  'tax_rate1': '20',
  'private_notes': 'Three seats.',
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'created_at': 1700000000,
  'updated_at': updatedAt,
};

RecurringExpenseApi _recurring({
  String id = 'r1',
  bool isDeleted = false,
  int archivedAt = 0,
}) => RecurringExpenseApi.fromJson(
  _json(id: id, isDeleted: isDeleted, archivedAt: archivedAt),
);

/// A draft nobody has scheduled: no vendor, no dates, endless.
final RecurringExpenseApi _draft = RecurringExpenseApi.fromJson({
  'id': 'r2',
  'number': '0008',
  'currency_id': '1',
  'frequency_id': '5',
  'status_id': '1',
  'amount': '20.00',
  'created_at': 1700000000,
  'updated_at': 1710000000,
});

Future<void> _seedLinked(Services s) async {
  await s.vendors.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const VendorApi(id: 'v1', name: 'Adobe'),
  );
  await s.expenseCategories.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ExpenseCategoryApi(id: 'cat1', name: 'Software'),
  );
  await s.projects.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ProjectApi(id: 'p1', name: 'Website Redesign'),
  );
}

/// What the app asked the server, and what the server says back.
class _Server {
  /// The record `GET /recurring_expenses/r1` returns — null leaves it
  /// unanswered. The schedule request is the very same URL.
  Map<String, dynamic>? record;

  /// Every request, whoever made it — the fixture's own background sync
  /// included.
  final List<http.Request> requests = [];

  Iterable<Uri> get recordAsks => requests
      .map((r) => r.url)
      .where((u) => u.path == '/api/v1/recurring_expenses/r1');

  Iterable<http.Request> naming(String id) =>
      requests.where((r) => '${r.url}'.contains(id) || r.body.contains(id));

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final record = this.record;
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/recurring_expenses/r1' &&
        record != null) {
      return jsonOk({'data': record});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

void _screenTest(
  String description,
  RecurringExpenseApi recurring,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  // Under the two-column breakpoint, so the single stack; wider than the
  // pane because the test font is far wider than the real one.
  Size size = const Size(800, 2400),
}) => recordScreenTest(
  description,
  seed: (services) async {
    await _seedLinked(services);
    await services.recurringExpenses.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: recurring,
    );
  },
  screen: () => RecurringExpenseDetailScreen(id: recurring.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
  size: size,
);

Finder _inHeader(String text) => find.descendant(
  of: find.byType(RecurringExpenseDetailHeader),
  matching: find.text(text),
);

Finder _headerLink(String label) => find.descendant(
  of: find.byType(RecurringExpenseDetailHeader),
  matching: find.byWidgetPredicate((w) => w is LinkText && w.label == label),
);

Finder _inStanding(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

Finder _card(String title) => find.widgetWithText(DashboardCardShell, title);

/// A quick-action tile, by its label — the fixed bar can spell the same word
/// when it has room to spread.
Finder _tile(String label) => find.descendant(
  of: find.byType(EntityQuickActions<RecurringExpenseAction>),
  matching: find.text(label),
);

void main() {
  _screenTest(
    'a running schedule: identity, actions, standing, profile, tabs',
    _recurring(),
    (tester, screen) async {
      // The number is the name; who, what kind and how often are the line
      // under it.
      expect(_inHeader('#0007'), findsOneWidget);
      await screen.untilFound(_headerLink('Adobe'), 'the linked names');
      expect(_headerLink('Software'), findsOneWidget);
      expect(_inHeader('Monthly'), findsOneWidget);

      // It is running, so the one thing to do to the schedule is stop it.
      expect(
        find.byType(EntityQuickActions<RecurringExpenseAction>),
        findsOneWidget,
      );
      expect(_tile('Stop'), findsOneWidget);
      expect(_tile('Start'), findsNothing);
      expect(_tile('Clone'), findsOneWidget);
      expect(_tile('+ Expense'), findsOneWidget);

      // Standing: what a run costs, when the next one is, that it is
      // running, and what is worth saying besides.
      expect(_inStanding('AMOUNT'), findsOneWidget);
      expect(_inStanding(r'$54.99'), findsOneWidget);
      expect(_inStanding('NEXT SEND DATE'), findsOneWidget);
      expect(_inStanding('2026-11-01'), findsOneWidget);
      expect(_inStanding('Active'), findsOneWidget);
      expect(_inStanding('Remaining Cycles'), findsOneWidget);
      expect(_inStanding('9'), findsOneWidget);
      expect(_inStanding(r'$11.00'), findsOneWidget);

      // The profile: the same cards an expense has, plus when it last ran.
      expect(_card('Details'), findsOneWidget);
      expect(find.text('Website Redesign'), findsOneWidget);
      expect(find.text('Last Sent Date'), findsOneWidget);
      expect(find.text('2026-10-01'), findsOneWidget);
      expect(_card('Taxes'), findsOneWidget);
      expect(find.text('Three seats.'), findsOneWidget);

      // Documents, then the Schedule. No Overview — it is all above the
      // strip — and no feed this screen never had.
      final documents = tester.getTopLeft(find.text('Documents')).dx;
      final schedule = tester.getTopLeft(find.text('Schedule')).dx;
      expect(documents, lessThan(schedule));
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Comments'), findsNothing);
      expect(find.byType(EntityDocumentsTab), findsOneWidget);
    },
  );

  _screenTest(
    'a draft offers Start, and draws no date it does not have',
    _draft,
    (tester, screen) async {
      expect(_inHeader('#0008'), findsOneWidget);
      expect(_inHeader('Monthly'), findsOneWidget);

      expect(_tile('Start'), findsOneWidget);
      expect(_tile('Stop'), findsNothing);

      expect(_inStanding(r'$20.00'), findsOneWidget);
      expect(_inStanding('Draft'), findsOneWidget);
      // Never scheduled, endless, untaxed: one figure and the pill.
      expect(find.text('NEXT SEND DATE'), findsNothing);
      expect(find.text('Remaining Cycles'), findsNothing);
      expect(find.text('Tax'), findsNothing);
      expect(find.text('Last Sent Date'), findsNothing);
      expect(find.text('—'), findsNothing);

      expect(_card('Details'), findsOneWidget);
      expect(_card('Taxes'), findsNothing);
      expect(_card('Invoicing'), findsNothing);
    },
  );

  _screenTest(
    'a tile goes through the same confirmation the menu does',
    _recurring(),
    (tester, screen) async {
      await tester.tap(_tile('Stop'));
      await screen.untilFound(find.text('Are you sure?'), 'the prompt');
      // The prompt names the record.
      expect(find.text('#0007'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await screen.until(
        () => find.text('Are you sure?').evaluate().isEmpty,
        'the prompt to close',
      );
      // Nothing happened: it is still running.
      expect(_inStanding('Active'), findsOneWidget);
    },
  );

  group('the schedule', () {
    final server = _Server()
      ..record = {
        ..._json(),
        'recurring_dates': [
          {'send_date': '2026-12-01'},
          {'send_date': '2027-01-01'},
        ],
      };
    _screenTest(
      'is asked for when its tab is opened, not when the record is',
      _recurring(),
      (tester, screen) async {
        await screen.until(() => server.recordAsks.isNotEmpty, 'the re-check');
        await screen.quiet();
        // One request for the record: the quiet re-check. (The by-id fetch
        // and the schedule fetch are the same URL — `?show_dates=true` — so
        // they can only be told apart by counting.) Nothing was asked for a
        // tab nobody has opened.
        expect(server.recordAsks, hasLength(1));
        expect(find.text('2026-12-01'), findsNothing);

        await tester.tap(find.text('Schedule'));
        await screen.untilFound(find.text('2026-12-01'), 'the dates');
        expect(find.text('2027-01-01'), findsOneWidget);
        expect(find.text('Send Date'), findsOneWidget);
        expect(server.recordAsks, hasLength(2));
      },
      server: server,
      online: true,
    );
  });

  _screenTest(
    'a deleted schedule is read-only, and says so once',
    _recurring(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered — no tiles, no Edit.
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Clone'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(
        tester
            .widget<EntityDocumentsTab>(find.byType(EntityDocumentsTab))
            .readOnly,
        isTrue,
      );
    },
  );

  _screenTest(
    'an archived schedule says so and keeps its actions',
    _recurring(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      expect(_tile('Stop'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view gets the banner without Restore, and no tile '
    'for a change they may not make',
    _recurring(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      // Stopping it is an edit; cloning it is a create.
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Clone'), findsNothing);
      expect(find.text('+ Expense'), findsNothing);
      // The vendor is still named, as plain text.
      await screen.untilFound(_inHeader('Adobe'), 'the linked names');
      expect(_headerLink('Adobe'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_recurring_expense',
    ),
  );

  final unsynced = _Server();
  _screenTest(
    'an unsynced schedule gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _recurring(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Clone'), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isNotEmpty, reason: 'the server was reachable');
      expect(unsynced.naming('tmp_1'), isEmpty);
    },
    server: unsynced,
  );

  group('wide', () {
    _screenTest(
      'the profile cards share a level row, and the band ends on one line',
      _recurring(),
      (tester, screen) async {
        expect(tester.takeException(), isNull);
        final details = tester.getRect(_card('Details'));
        final taxes = tester.getRect(_card('Taxes'));
        expect(taxes.top, details.top);
        expect(taxes.bottom, details.bottom);
        expect(taxes.left, greaterThan(details.right));

        final standing = tester.getRect(find.byType(StandingCard));
        final header = tester.getRect(
          find.byType(RecurringExpenseDetailHeader),
        );
        expect(standing.top, header.top);
        final tile = tester.getRect(
          find
              .ancestor(of: _tile('Stop'), matching: find.byType(InkWell))
              .first,
        );
        expect(standing.bottom, moreOrLessEquals(tile.bottom, epsilon: 0.5));
      },
      size: const Size(1300, 1600),
    );
  });

  group('refresh', () {
    final server = _Server();
    _screenTest(
      'R re-fetches the record, with nothing clicked first',
      _recurring(),
      (tester, screen) async {
        await screen.quiet();
        final before = server.recordAsks.length;
        server.record = _json(amount: '64.99', updatedAt: 1710009999);

        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(
          () => server.recordAsks.length > before,
          'the refresh',
        );
        await screen.untilFound(find.text(r'$64.99'), 'the new amount');
      },
      server: server,
      online: true,
    );
  });
}
