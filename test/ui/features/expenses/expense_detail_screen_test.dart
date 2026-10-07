// The expense record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/views/expense_detail_screen.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_header.dart';
import 'package:admin/ui/features/expenses/widgets/expense_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

/// A billable expense with everything on it: a vendor, a client, a category,
/// a project, tax on top, a payment, a note and a receipt.
Map<String, dynamic> _json({
  String id = 'e1',
  bool isDeleted = false,
  int archivedAt = 0,
  String invoiceId = '',
  String amount = '1000.00',
  int updatedAt = 1710000000,
}) => {
  'id': id,
  'number': '0012',
  'vendor_id': 'v1',
  'client_id': 'c1',
  'category_id': 'cat1',
  'project_id': 'p1',
  'invoice_id': invoiceId,
  'currency_id': '1',
  'date': '2026-10-03',
  'amount': amount,
  'tax_name1': 'VAT',
  'tax_rate1': '20',
  'should_be_invoiced': true,
  'payment_date': '2026-10-05',
  'transaction_reference': 'TXN-88213',
  'private_notes': 'Receipt is in the blue folder.',
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'created_at': 1700000000,
  'updated_at': updatedAt,
  'documents': [
    {'id': 'd1', 'name': 'receipt-0012.pdf', 'hash': 'h', 'type': 'pdf'},
  ],
};

ExpenseApi _expense({
  String id = 'e1',
  bool isDeleted = false,
  int archivedAt = 0,
  String invoiceId = '',
}) => ExpenseApi.fromJson(
  _json(
    id: id,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
    invoiceId: invoiceId,
  ),
);

/// An expense with nothing on it but an amount and a date.
final ExpenseApi _bare = ExpenseApi.fromJson({
  'id': 'e2',
  'number': '0013',
  'currency_id': '1',
  'date': '2026-10-06',
  'amount': '42.50',
  'created_at': 1700000000,
  'updated_at': 1710000000,
});

/// The records an expense points at, so their names resolve from the cache.
Future<void> _seedLinked(Services s) async {
  await s.vendors.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const VendorApi(id: 'v1', name: 'Staples'),
  );
  await s.clients.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ClientApi(
      id: 'c1',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
    ),
  );
  await s.expenseCategories.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ExpenseCategoryApi(
      id: 'cat1',
      name: 'Office Supplies',
    ),
  );
  await s.projects.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ProjectApi(id: 'p1', name: 'Website Redesign'),
  );
  await s.invoices.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const InvoiceApi(id: 'i1', number: '0042'),
  );
}

/// What the app asked the server, and what the server says back.
class _Server {
  /// The record `GET /expenses/e1` returns — null leaves it unanswered.
  Map<String, dynamic>? record;

  /// Every request, whoever made it — the fixture's own background sync
  /// (statics, tags, the sidebar's first pages) included.
  final List<http.Request> requests = [];

  Iterable<Uri> get recordAsks =>
      requests.map((r) => r.url).where((u) => u.path == '/api/v1/expenses/e1');

  /// Requests that name [id] anywhere — in the path, the query or the body
  /// (the activity feed is a POST that carries the record's id).
  Iterable<http.Request> naming(String id) =>
      requests.where((r) => '${r.url}'.contains(id) || r.body.contains(id));

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final record = this.record;
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/expenses/e1' &&
        record != null) {
      return jsonOk({'data': record});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The expense screen over an expense seeded into the local database.
void _screenTest(
  String description,
  ExpenseApi expense,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  // Under the two-column breakpoint, so the single stack — but wider than
  // the pane: the test font is far wider than the real one, and at 480 the
  // three-tab strip overflows and scrolls its first tab off the edge.
  Size size = const Size(800, 2400),
}) => recordScreenTest(
  description,
  seed: (services) async {
    await _seedLinked(services);
    await services.expenses.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: expense,
    );
  },
  screen: () => ExpenseDetailScreen(id: expense.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
  size: size,
);

Finder _inHeader(String text) => find.descendant(
  of: find.byType(ExpenseDetailHeader),
  matching: find.text(text),
);

/// A header entry drawn as a link (rather than plain text).
Finder _headerLink(String label) => find.descendant(
  of: find.byType(ExpenseDetailHeader),
  matching: find.byWidgetPredicate((w) => w is LinkText && w.label == label),
);

Finder _card(String title) => find.widgetWithText(DashboardCardShell, title);

void main() {
  _screenTest(
    'an active expense: identity, actions, standing, profile, tabs',
    _expense(),
    (tester, screen) async {
      // The number is the name; who, for whom, what kind and when are the
      // line under it — each name a link to its record.
      expect(_inHeader('#0012'), findsOneWidget);
      // (The names come off a watch of the local cache, a beat after the
      // record itself.)
      await screen.untilFound(_headerLink('Staples'), 'the linked names');
      expect(_headerLink('Acme Corporation'), findsOneWidget);
      expect(_headerLink('Office Supplies'), findsOneWidget);
      expect(_inHeader('2026-10-03'), findsOneWidget);

      // Billable and not yet billed: billing it leads the tiles.
      expect(find.byType(EntityQuickActions<ExpenseAction>), findsOneWidget);
      expect(find.text('+ Invoice'), findsOneWidget);
      expect(find.text('Add To Invoice'), findsWidgets);
      expect(find.text('Clone'), findsOneWidget);

      // Standing: the amount as entered, the gross beside it because tax is
      // added on top, the tax itself, and the status as the list's pill.
      final standing = find.byType(StandingCard);
      Finder inStanding(String text) =>
          find.descendant(of: standing, matching: find.text(text));
      expect(inStanding('AMOUNT'), findsOneWidget);
      expect(inStanding(r'$1,000.00'), findsOneWidget);
      expect(inStanding('GROSS AMOUNT'), findsOneWidget);
      expect(inStanding(r'$1,200.00'), findsOneWidget);
      expect(inStanding(r'$200.00'), findsOneWidget);
      expect(inStanding('Pending'), findsOneWidget);

      // The profile is simply there — nothing to open, and one card per
      // section of the edit form.
      expect(_card('Details'), findsOneWidget);
      expect(find.text('Website Redesign'), findsOneWidget);
      expect(_card('Invoicing'), findsOneWidget);
      expect(find.text('Should be invoiced'), findsOneWidget);
      expect(_card('Payment'), findsOneWidget);
      expect(find.text('TXN-88213'), findsOneWidget);
      expect(_card('Taxes'), findsOneWidget);
      expect(find.text(r'20% · $200.00'), findsOneWidget);
      expect(find.text('Receipt is in the blue folder.'), findsOneWidget);
      // The vendor, client and category are the header's; a card each for
      // them is what this screen used to be.
      expect(_card('Vendor'), findsNothing);
      expect(_card('Client'), findsNothing);

      // Comments and Activity lead the strip, and the screen opens on what is
      // not already above it: the receipt.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final documents = tester.getTopLeft(find.text('Documents')).dx;
      // One receipt, said the way every counted tab says it: a badge.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Documents'),
            matching: find.byType(InkWell),
          ),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(comments, lessThan(activity));
      expect(activity, lessThan(documents));
      expect(find.text('Overview'), findsNothing);
      expect(find.text('receipt-0012.pdf'), findsOneWidget);
      expect(
        tester
            .widget<EntityDocumentsTab>(find.byType(EntityDocumentsTab))
            .readOnly,
        isFalse,
      );

      // And the Comments tab offers a new comment — the control for the
      // deleted-expense test below, which expects exactly this to be gone.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('Add Comment'), 'the comments tab');
    },
  );

  _screenTest('an expense with nothing on it draws only what it has', _bare, (
    tester,
    screen,
  ) async {
    expect(_inHeader('#0013'), findsOneWidget);
    expect(_inHeader('2026-10-06'), findsOneWidget);

    final standing = find.byType(StandingCard);
    expect(
      find.descendant(of: standing, matching: find.text(r'$42.50')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: standing, matching: find.text('Logged')),
      findsOneWidget,
    );
    // No tax: no second figure, and no labelled nothing under the amount.
    expect(find.text('GROSS AMOUNT'), findsNothing);
    expect(find.text('Tax'), findsNothing);
    expect(find.text('—'), findsNothing);

    // One card, with the rows it has. No Invoicing, Payment or Taxes card
    // was given a place for nothing.
    expect(_card('Details'), findsOneWidget);
    expect(_card('Invoicing'), findsNothing);
    expect(_card('Payment'), findsNothing);
    expect(_card('Taxes'), findsNothing);
    expect(find.text('Notes'), findsNothing);

    // No client to hang an invoice off: that tile yields its place.
    expect(find.text('+ Invoice'), findsOneWidget);
    expect(find.text('Add To Invoice'), findsNothing);
  });

  _screenTest(
    'an expense that has been billed links its invoice and stops offering to '
    'bill it',
    _expense(invoiceId: 'i1'),
    (tester, screen) async {
      expect(
        find.descendant(
          of: find.byType(StandingCard),
          matching: find.text('Invoiced'),
        ),
        findsOneWidget,
      );
      await screen.untilFound(
        find.byWidgetPredicate((w) => w is LinkText && w.label == '#0042'),
        'the invoice row',
      );
      // Answered by the row above it.
      expect(find.text('Should be invoiced'), findsNothing);
      expect(find.text('+ Invoice'), findsNothing);
      // The tiles for making the next one are still there.
      expect(find.text('Clone'), findsOneWidget);
    },
  );

  _screenTest(
    'a deleted expense is read-only, and says so once',
    _expense(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered — no tiles, no Edit.
      expect(find.byType(EntityQuickActions<ExpenseAction>), findsOneWidget);
      expect(find.text('+ Invoice'), findsNothing);
      expect(find.text('Clone'), findsNothing);
      expect(find.text('Edit'), findsNothing);

      // Its receipts stay readable and it takes no more.
      expect(find.text('receipt-0012.pdf'), findsOneWidget);
      expect(
        tester
            .widget<EntityDocumentsTab>(find.byType(EntityDocumentsTab))
            .readOnly,
        isTrue,
      );

      // Its comments stay readable; adding one does not.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('No comments yet'), 'the comments tab');
      expect(find.text('Add Comment'), findsNothing);
    },
  );

  _screenTest(
    'an archived expense says so and keeps its actions',
    _expense(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only: the server still accepts edits.
      expect(find.text('+ Invoice'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view expenses gets the banner without Restore, the '
    'names without links, and no tile for a record they may not create',
    _expense(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);

      // The names are still there — the expense lists print them too.
      await screen.untilFound(_inHeader('Staples'), 'the linked names');
      expect(_inHeader('Acme Corporation'), findsOneWidget);
      // But a name is a link only to a record this user may open.
      expect(_headerLink('Staples'), findsNothing);
      expect(_headerLink('Acme Corporation'), findsNothing);

      expect(find.text('+ Invoice'), findsNothing);
      expect(find.text('Clone'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_expense',
    ),
  );

  final unsynced = _Server();
  _screenTest(
    'an unsynced expense gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _expense(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(find.text('+ Invoice'), findsNothing);
      expect(find.text('Clone'), findsNothing);
      await screen.quiet();
      // (The fixture syncs in the background; none of that is about this
      // record.)
      expect(unsynced.requests, isNotEmpty, reason: 'the server was reachable');
      expect(unsynced.naming('tmp_1'), isEmpty);
    },
    server: unsynced,
  );

  group('wide', () {
    _screenTest(
      'the profile cards share level rows, and the band ends on one line',
      _expense(),
      (tester, screen) async {
        expect(tester.takeException(), isNull);
        // Four cards: two rows of two, each row level.
        final details = tester.getRect(_card('Details'));
        final invoicing = tester.getRect(_card('Invoicing'));
        final payment = tester.getRect(_card('Payment'));
        final taxes = tester.getRect(_card('Taxes'));
        expect(invoicing.top, details.top);
        expect(invoicing.bottom, details.bottom);
        expect(invoicing.left, greaterThan(details.right));
        expect(payment.top, greaterThan(details.bottom));
        expect(taxes.top, payment.top);
        expect(taxes.bottom, payment.bottom);
        expect(details.width, moreOrLessEquals(invoicing.width, epsilon: 0.5));

        // The standing card sits beside the header and ends with the tiles.
        final standing = tester.getRect(find.byType(StandingCard));
        final header = tester.getRect(find.byType(ExpenseDetailHeader));
        expect(standing.top, header.top);
        expect(standing.left, greaterThan(header.right));
        final tile = tester.getRect(
          find.ancestor(
            of: find.text('+ Invoice'),
            matching: find.byType(InkWell),
          ),
        );
        expect(standing.bottom, moreOrLessEquals(tile.bottom, epsilon: 0.5));
      },
      size: const Size(1300, 1600),
    );

    _screenTest(
      'a lone card takes the row, under both sides of the band',
      _bare,
      (tester, screen) async {
        final details = tester.getRect(_card('Details'));
        final standing = tester.getRect(find.byType(StandingCard));
        final header = tester.getRect(find.byType(ExpenseDetailHeader));
        // Edge to edge with the band above it — not held to the header's
        // column with a blank under the standing card.
        expect(details.left, moreOrLessEquals(header.left, epsilon: 0.5));
        expect(details.right, moreOrLessEquals(standing.right, epsilon: 0.5));
      },
      size: const Size(1300, 1200),
    );
  });

  group('refresh', () {
    final recheck = _Server()..record = _json(updatedAt: 1710009999);
    _screenTest(
      'opening a cached expense quietly re-checks it, once',
      _expense(),
      (tester, screen) async {
        await screen.until(() => recheck.recordAsks.isNotEmpty, 'the re-check');
        await screen.quiet();
        expect(recheck.recordAsks, hasLength(1));
      },
      server: recheck,
      online: true,
    );

    final server = _Server();
    _screenTest(
      'R re-fetches the record, with nothing clicked first',
      _expense(),
      (tester, screen) async {
        await screen.quiet();
        final before = server.recordAsks.length;
        // What the server holds has moved on since the cached copy.
        server.record = _json(amount: '1500.00', updatedAt: 1710009999);

        // Straight from arrival: no click into the body to give the key
        // somewhere to land.
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(
          () => server.recordAsks.length > before,
          'the refresh',
        );
        await screen.untilFound(find.text(r'$1,500.00'), 'the new amount');
      },
      server: server,
      online: true,
    );
  });
}
