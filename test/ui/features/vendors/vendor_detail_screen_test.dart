// The vendor record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/billing_shared/ledger/ledger_tab.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_list_screen.dart';
import 'package:admin/ui/features/vendors/views/vendor_detail_screen.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_address_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_header.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

const _contacts = [
  VendorContactApi(
    id: 'k1',
    firstName: 'Katrin',
    lastName: 'Vogel',
    email: 'katrin@brandenburg.example.com',
    isPrimary: true,
  ),
  VendorContactApi(id: 'k2', firstName: 'Jonas', lastName: 'Weber'),
  // The all-blank row the server keeps on every vendor.
  VendorContactApi(id: 'k3'),
];

VendorApi _vendor({
  String id = 'v1',
  bool isDeleted = false,
  int archivedAt = 0,
}) => VendorApi(
  id: id,
  name: 'Brandenburg Office Supply',
  number: '0017',
  city: 'Berlin',
  currencyId: '1',
  vatNumber: 'DE811907980',
  privateNotes: 'Net 30. Ask Katrin.',
  isDeleted: isDeleted,
  archivedAt: archivedAt,
  updatedAt: 1710000000,
  createdAt: 1700000000,
  contacts: _contacts,
);

// Mid-month, so no timezone can move one across a day boundary.
ExpenseApi _expense(String id, String amount, String date) => ExpenseApi(
  id: id,
  number: id,
  vendorId: 'v1',
  currencyId: '1',
  amount: amount,
  date: date,
  updatedAt: 1700000000,
);

Map<String, dynamic> _expenseJson(String id, String amount, String date) => {
  'id': id,
  'number': id,
  'vendor_id': 'v1',
  'currency_id': '1',
  'amount': amount,
  'date': date,
  'updated_at': 1700000000,
};

Map<String, dynamic> _purchaseOrder(String id) => {
  'id': id,
  'vendor_id': 'v1',
  'number': id,
  'status_id': '1',
  'amount': '100.00',
  'balance': '100.00',
  'date': '2024-01-15',
  'updated_at': 1700000000,
};

/// What the app asked the server, and what the server says back.
class _Server {
  /// Rows returned for a vendor-scoped purchase-order list.
  List<Map<String, dynamic>> purchaseOrders = const [];

  /// Every active expense the server holds for the vendor.
  List<Map<String, dynamic>> expenses = const [];

  /// `meta.pagination.total` by list path, for a `per_page=1` count request.
  Map<String, int> totals = const {};

  /// The record `GET /vendors/{id}` returns — null leaves it unanswered.
  Map<String, dynamic>? record;

  /// Answer `GET /vendors/{id}` the way the server refuses a record this user
  /// may not view.
  bool denyRecord = false;

  final List<Uri> requests = [];

  Iterable<Uri> get recordAsks =>
      requests.where((u) => u.path == '/api/v1/vendors/v1');

  Iterable<Uri> get counts =>
      requests.where((u) => u.queryParameters['per_page'] == '1');

  /// Pages of the vendor's expenses — the standing card completing its sum,
  /// or the Expenses tab.
  Iterable<Uri> get expensePages => requests.where(
    (u) => u.path == '/api/v1/expenses' && u.queryParameters['per_page'] != '1',
  );

  http.Client get client => MockClient((request) async {
    final url = request.url;
    if (request.method != 'GET') {
      throw http.ClientException('offline (test fixture)');
    }
    final query = url.queryParameters;
    if (query['per_page'] == '1') {
      final total = totals[url.path];
      if (total != null) {
        requests.add(url);
        return countOf(total);
      }
    } else if (url.path == '/api/v1/purchase_orders' &&
        query['vendor_id'] == 'v1') {
      requests.add(url);
      return jsonOk({'data': purchaseOrders});
    } else if (url.path == '/api/v1/expenses' && query['vendor_id'] == 'v1') {
      requests.add(url);
      return jsonOk({'data': query['page'] == '1' ? expenses : <Object>[]});
    } else if (url.path == '/api/v1/vendors/v1' && denyRecord) {
      requests.add(url);
      return permissionDenied();
    } else if (url.path == '/api/v1/vendors/v1' && record != null) {
      requests.add(url);
      return http.Response(
        jsonEncode({'data': record}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The vendor screen over a vendor (and its expenses) seeded into the local
/// database.
void _screenTest(
  String description,
  VendorApi vendor,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  List<ExpenseApi> expenses = const [],
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  Finder Function()? ready,
}) => recordScreenTest(
  description,
  seed: (services) async {
    await services.vendors.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: vendor,
    );
    for (final e in expenses) {
      await services.expenses.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: e,
      );
    }
  },
  screen: () => VendorDetailScreen(id: vendor.id),
  ready: ready ?? () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
  // The pane at its widest. The strip keeps the selected tab in view, and at
  // the harness's 480 "Purchase Orders" is long enough to push Comments under
  // the strip's leading edge, where a tap cannot reach it.
  size: const Size(560, 2000),
);

/// The count badge drawn inside the tab labelled [label].
Finder _badge(String label, String count) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  matching: find.text(count),
);

/// [text] as a figure on the standing card — not the same amount in the bar
/// that replaces the header once it has scrolled away.
Finder _standing(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

String _date(Services services, String iso) =>
    services.formatterIfReady('co1')!.date(iso);

void main() {
  _screenTest(
    'an active vendor: identity, actions, standing, profile, tabs',
    _vendor(),
    (tester, screen) async {
      expect(find.text('Brandenburg Office Supply'), findsWidgets);
      // Place · number under the name. (The city is in the Address card too.)
      expect(
        find.descendant(
          of: find.byType(VendorDetailHeader),
          matching: find.text('Berlin'),
        ),
        findsOneWidget,
      );
      expect(find.text('#0017'), findsOneWidget);

      expect(find.byType(EntityQuickActions<VendorAction>), findsOneWidget);
      expect(find.text('+ Expense'), findsOneWidget);
      expect(find.text('+ Order'), findsOneWidget);

      // Where things stand: what was spent, and when last.
      await screen.untilFound(_standing(r'$1,339.90'), 'the total');
      expect(_standing('TOTAL EXPENSES'), findsOneWidget);
      expect(
        _standing(_date(screen.services, '2024-03-12')),
        findsOneWidget,
        reason: 'the most recent of the two',
      );

      // The profile is simply there — nothing to open. Every real contact,
      // the details, the address, and the note the user left themselves.
      expect(find.text('Katrin Vogel'), findsOneWidget);
      expect(find.text('Jonas Weber'), findsOneWidget);
      expect(find.textContaining('no name'), findsNothing);
      expect(find.text('VAT Number'), findsOneWidget);
      expect(find.text('DE811907980'), findsOneWidget);
      expect(find.byType(VendorDetailAddressCard), findsOneWidget);
      expect(find.text('Net 30. Ask Katrin.'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Comments and Activity still lead the strip, and the screen opens on
      // the first related list.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final orders = tester.getTopLeft(find.text('Purchase Orders')).dx;
      final spent = tester.getTopLeft(find.text('Expenses')).dx;
      expect(comments, lessThan(activity));
      expect(activity, lessThan(orders));
      expect(orders, lessThan(spent));
      expect(find.byType(PurchaseOrderListScreen), findsOneWidget);
      // …which offers a new one — the control for the deleted-vendor test
      // below, which expects exactly this to be gone.
      expect(find.text('New'), findsOneWidget);

      // And the Comments tab offers a new comment — likewise.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('Add Comment'), 'the comments tab');
    },
    expenses: [
      _expense('e1', '1250.00', '2024-02-11'),
      _expense('e2', '89.90', '2024-03-12'),
    ],
  );

  _screenTest(
    'a deleted vendor is read-only, and says so once',
    _vendor(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered.
      expect(find.text('+ Expense'), findsNothing);
      expect(find.byType(PurchaseOrderListScreen), findsOneWidget);
      expect(find.text('New'), findsNothing);

      // Its comments stay readable; adding one does not.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('No comments yet'), 'the comments tab');
      expect(find.text('Add Comment'), findsNothing);
    },
  );

  _screenTest(
    'an archived vendor says so and keeps its actions',
    _vendor(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only: the server still accepts edits and new
      // records for it.
      expect(find.text('+ Expense'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view vendors gets the banner without Restore',
    _vendor(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      // …and no tile for a record they may not create.
      expect(find.text('+ Expense'), findsNothing);
      // Nor what was spent with the vendor: without `view_expense` they are
      // shown only their own expenses, and a total of those under the
      // vendor's name is not the vendor's total.
      expect(find.byType(StandingCard), findsNothing);
    },
    ready: () => find.byType(VendorDetailHeader),
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_vendor',
    ),
  );

  _screenTest(
    '…and with view_expense as well, the spend is theirs to see',
    _vendor(),
    expenses: [_expense('e1', '120.00', '2024-03-10')],
    (tester, screen) async {
      await screen.untilFound(find.text(r'$120.00'), 'the total');
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_vendor,view_expense',
    ),
  );

  _screenTest(
    'a country with no address around it is a detail, not an Address card',
    // What the server gives every vendor nobody typed an address for: the
    // company's own country. (The statics here hold no countries, so the row
    // falls back to the raw id — which is the fallback being a row at all.)
    const VendorApi(
      id: 'v1',
      name: 'Corner Cafe',
      countryId: '840',
      currencyId: '1',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
    (tester, screen) async {
      expect(find.text('Country'), findsOneWidget);
      expect(find.text('840'), findsOneWidget);
      expect(find.byType(VendorDetailAddressCard), findsNothing);
      expect(find.text('View Map'), findsNothing);
      // Nor is a bare country a "place" worth putting under the name.
      expect(
        find.descendant(
          of: find.byType(VendorDetailHeader),
          matching: find.text('840'),
        ),
        findsNothing,
      );
    },
  );

  final unsynced = _Server()
    ..totals = const {'/api/v1/expenses': 12}
    ..expenses = [_expenseJson('e9', '5.00', '2024-01-10')];
  _screenTest(
    'an unsynced vendor gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _vendor(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(find.text('+ Expense'), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isEmpty);
    },
    server: unsynced,
    online: true,
  );

  group('standing', () {
    _screenTest(
      'a vendor with no expenses: a real zero, and a dash where a date '
      'would be',
      _vendor(),
      (tester, screen) async {
        await screen.untilFound(_standing(r'$0.00'), 'the total');
        expect(_standing('—'), findsOneWidget);
      },
    );

    _screenTest(
      'a figure opens the Expenses tab',
      _vendor(),
      (tester, screen) async {
        await screen.untilFound(_standing(r'$1,250.00'), 'the total');
        expect(find.byType(ExpenseListScreen), findsNothing);

        await tester.tap(_standing('TOTAL EXPENSES'));
        await screen.untilFound(
          find.byType(ExpenseListScreen),
          'the Expenses tab',
        );
      },
      expenses: [_expense('e1', '1250.00', '2024-02-11')],
    );

    final short = _Server()
      ..totals = const {'/api/v1/expenses': 3}
      ..expenses = [
        _expenseJson('e1', '1250.00', '2024-02-11'),
        _expenseJson('e2', '89.90', '2024-03-12'),
        _expenseJson('e3', '4310.25', '2024-03-18'),
      ];
    _screenTest(
      'when the server holds more expenses than this device, the rest are '
      'fetched before a total is claimed',
      _vendor(),
      (tester, screen) async {
        // One of three is cached. Its sum alone would be a confidently wrong
        // number in the most prominent card on the screen.
        await screen.untilFound(_standing(r'$5,650.15'), 'the whole total');
        expect(_standing(_date(screen.services, '2024-03-18')), findsOneWidget);

        // Asked for the way the Expenses tab asks: this vendor's, active,
        // from the first page.
        expect(short.expensePages, isNotEmpty);
        for (final u in short.expensePages) {
          expect(u.queryParameters['vendor_id'], 'v1', reason: '$u');
          expect(u.queryParameters['status'], 'active', reason: '$u');
          expect(
            u.queryParameters['without_deleted_clients'],
            'true',
            reason: 'the same rows the count counted — $u',
          );
        }
        expect(short.expensePages.first.queryParameters['page'], '1');
      },
      expenses: [_expense('e1', '1250.00', '2024-02-11')],
      server: short,
      online: true,
    );

    final whole = _Server()..totals = const {'/api/v1/expenses': 1};
    _screenTest(
      'a device that already holds them all asks for no expenses',
      _vendor(),
      (tester, screen) async {
        await screen.untilFound(_badge('Expenses', '1'), 'the count');
        await screen.quiet();
        expect(_standing(r'$1,250.00'), findsOneWidget);
        expect(whole.expensePages, isEmpty);
      },
      expenses: [_expense('e1', '1250.00', '2024-02-11')],
      server: whole,
      online: true,
    );

    _screenTest(
      'with the Expenses module off there is nothing to stand on',
      _vendor(),
      (tester, screen) async {
        expect(find.byType(StandingCard), findsNothing);
        expect(find.text('Recurring Expenses'), findsNothing);
        expect(find.text('+ Expense'), findsNothing);
        // The tabs that need no module are still there, and with no related
        // list ahead of it the Ledger is the one the screen opens on. (Not
        // `find.text('Expenses')` / `'Purchase Orders'`: the ledger has a
        // filter by each name.)
        expect(find.text('Documents'), findsOneWidget);
        expect(find.byType(LedgerTab), findsOneWidget);
        expect(find.byType(PurchaseOrderListScreen), findsNothing);
        expect(find.byType(ExpenseListScreen), findsNothing);
      },
      company: const FakeCompany(id: 'co1', name: 'Co', enabledModules: 0),
      ready: () => find.byType(VendorDetailHeader),
    );
  });

  group('counts on the related tabs', () {
    final counted = _Server()
      ..totals = const {'/api/v1/purchase_orders': 12, '/api/v1/expenses': 0};
    _screenTest(
      'each tab says how many records it holds on the server',
      _vendor(),
      (tester, screen) async {
        await screen.untilFound(_badge('Purchase Orders', '12'), 'the badges');
        // A real zero is worth saying: it is a tab not worth opening.
        expect(_badge('Expenses', '0'), findsOneWidget);
        // Recurring Expenses was never answered — no badge, not a zero.
        expect(_badge('Recurring Expenses', '0'), findsNothing);

        expect(counted.counts, isNotEmpty);
        for (final u in counted.counts) {
          // The key each of those lists sends for its own rows.
          expect(u.queryParameters['vendor_id'], 'v1');
          expect(u.queryParameters['status'], 'active');
        }
        // An expense fetch that is not scoped to a client leaves out expenses
        // billed to an archived or deleted one; the count has to ask the same
        // question or the badge is a number of rows the tab will not list.
        final expenses = counted.counts.singleWhere(
          (u) => u.path == '/api/v1/expenses',
        );
        expect(expenses.queryParameters['without_deleted_clients'], 'true');
        final orders = counted.counts.singleWhere(
          (u) => u.path == '/api/v1/purchase_orders',
        );
        expect(
          orders.queryParameters.containsKey('without_deleted_clients'),
          isFalse,
          reason: 'the purchase-order list sends no such filter',
        );
      },
      server: counted,
      online: true,
    );

    final recheck = _Server()
      ..totals = const {'/api/v1/purchase_orders': 12, '/api/v1/expenses': 0}
      // The server's copy is newer than the cached one.
      ..record = {
        'id': 'v1',
        'name': 'Brandenburg Office Supply',
        'currency_id': '1',
        'updated_at': 1710009999,
        'contacts': <Object>[],
      };
    _screenTest(
      'a re-check that finds a newer record does not make every count be '
      'asked twice',
      _vendor(),
      (tester, screen) async {
        await screen.untilFound(_badge('Purchase Orders', '12'), 'the badges');
        await screen.quiet();
        expect(recheck.recordAsks, hasLength(1), reason: 'the re-check ran');
        final byPath = <String, int>{};
        for (final u in recheck.counts) {
          byPath[u.path] = (byPath[u.path] ?? 0) + 1;
        }
        expect(byPath, {'/api/v1/purchase_orders': 1, '/api/v1/expenses': 1});
      },
      server: recheck,
      online: true,
    );

    final offline = _Server()..totals = const {'/api/v1/purchase_orders': 12};
    _screenTest('offline, the tabs carry no counts at all', _vendor(), (
      tester,
      screen,
    ) async {
      await screen.quiet();
      expect(_badge('Purchase Orders', '12'), findsNothing);
      expect(offline.counts, isEmpty);
    }, server: offline);
  });

  final denied = _Server()..denyRecord = true;
  _screenTest(
    'being refused the record does not end the session',
    _vendor(),
    (tester, screen) async {
      // The quiet re-check asks for the record by id on every open, and the
      // server's "you may not view this" is a 401.
      await screen.until(() => denied.recordAsks.isNotEmpty, 'the re-check');
      await screen.quiet();
      expect(
        screen.services.auth.session.value,
        isNotNull,
        reason: 'still signed in',
      );
      // And the cached record is still what is on screen.
      expect(find.text('Brandenburg Office Supply'), findsWidgets);
      expect(find.byType(StandingCard), findsOneWidget);
    },
    server: denied,
    online: true,
  );

  group('refresh', () {
    final server = _Server()..purchaseOrders = [_purchaseOrder('po1')];
    _screenTest(
      'R reloads this vendor\'s list — one page, still scoped — with nothing '
      'clicked first',
      _vendor(),
      (tester, screen) async {
        await screen.untilFound(find.text('#po1'), 'the list');
        await screen.quiet();
        final before = server.requests.length;

        // Straight from arrival: no click into the body to give the key
        // somewhere to land.
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(
          () => server.requests.length > before,
          'the refresh',
        );
        await screen.quiet();

        // Every request the refresh made for purchase orders named the
        // vendor. The list's own `refresh` is a sweep of the whole entity —
        // every page, no vendor — and must not be what this calls.
        final after = server.requests.skip(before).toList();
        final orders = after
            .where((u) => u.path == '/api/v1/purchase_orders')
            .toList();
        expect(orders, isNotEmpty);
        for (final u in orders) {
          expect(u.queryParameters['vendor_id'], 'v1', reason: '$u');
          expect(u.queryParameters['page'], '1', reason: '$u');
        }
      },
      server: server,
    );
  });
}
