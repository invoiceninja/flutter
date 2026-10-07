// The product record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/products/views/product_detail_screen.dart';
import 'package:admin/ui/features/products/widgets/detail/product_detail_header.dart';
import 'package:admin/ui/features/products/widgets/product_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

/// A stocked product with everything on it.
Map<String, dynamic> _json({
  String id = 'p1',
  bool isDeleted = false,
  int archivedAt = 0,
  num stock = 3,
  String price = '349.00',
  int updatedAt = 1710000000,
}) => {
  'id': id,
  'product_key': 'Office Chair',
  'notes': 'Mesh back, adjustable lumbar support.',
  'price': price,
  'cost': '181.50',
  'quantity': '2',
  'max_quantity': 20,
  'in_stock_quantity': stock,
  'stock_notification': true,
  'stock_notification_threshold': 5,
  'tax_id': '1',
  'tax_name1': 'VAT',
  'tax_rate1': 20,
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'created_at': 1700000000,
  'updated_at': updatedAt,
};

ProductApi _product({
  String id = 'p1',
  bool isDeleted = false,
  int archivedAt = 0,
  num stock = 3,
}) => ProductApi.fromJson(
  _json(id: id, isDeleted: isDeleted, archivedAt: archivedAt, stock: stock),
);

/// A service: a key and a price, nothing else.
ProductApi _bare({num stock = 0}) => ProductApi.fromJson({
  'id': 'p2',
  'product_key': 'Consulting',
  'price': '150.00',
  'quantity': '1',
  'in_stock_quantity': stock,
  'created_at': 1700000000,
  'updated_at': 1710000000,
});

/// Turns inventory tracking on for the fixture's company, with a company-wide
/// low-stock threshold.
Future<void> _trackInventory(Services s) =>
    (s.db.update(s.db.companies)..where((c) => c.id.equals('co1'))).write(
      const CompaniesCompanion(
        trackInventory: Value(true),
        inventoryNotificationThreshold: Value(5),
      ),
    );

/// What the app asked the server, and what the server says back.
class _Server {
  /// The record `GET /products/p1` returns — null leaves it unanswered.
  Map<String, dynamic>? record;

  /// Every request, whoever made it — the fixture's own background sync
  /// included.
  final List<http.Request> requests = [];

  Iterable<Uri> get recordAsks =>
      requests.map((r) => r.url).where((u) => u.path == '/api/v1/products/p1');

  Iterable<http.Request> naming(String id) =>
      requests.where((r) => '${r.url}'.contains(id) || r.body.contains(id));

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final record = this.record;
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/products/p1' &&
        record != null) {
      return jsonOk({'data': record});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

void _screenTest(
  String description,
  ProductApi product,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  bool inventory = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  // Under the two-column breakpoint, so the single stack; wider than the
  // pane because the test font is far wider than the real one.
  Size size = const Size(800, 2400),
}) => recordScreenTest(
  description,
  seed: (services) async {
    if (inventory) await _trackInventory(services);
    await services.products.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: product,
    );
  },
  screen: () => ProductDetailScreen(id: product.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
  size: size,
);

Finder _inHeader(Finder matching) =>
    find.descendant(of: find.byType(ProductDetailHeader), matching: matching);

Finder _inStanding(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

Finder _card(String title) => find.widgetWithText(DashboardCardShell, title);

/// A quick-action tile, by its label.
Finder _tile(String label) => find.descendant(
  of: find.byType(EntityQuickActions<ProductAction>),
  matching: find.text(label),
);

void main() {
  _screenTest(
    'a stocked product: identity, actions, standing, profile, tabs',
    _product(),
    (tester, screen) async {
      // The key is the name and the description is the line under it — the
      // pair an invoice line prints.
      expect(_inHeader(find.text('Office Chair')), findsOneWidget);
      expect(
        _inHeader(find.text('Mesh back, adjustable lumbar support.')),
        findsOneWidget,
      );

      // What a product is for is being put on a document.
      expect(_tile('+ Invoice'), findsOneWidget);
      expect(_tile('+ Quote'), findsOneWidget);
      expect(_tile('+ Order'), findsOneWidget);
      expect(_tile('Clone'), findsOneWidget);
      expect(_tile('Tax Category'), findsOneWidget);

      // Standing: money with its symbol, and the stock under it — three left
      // against a threshold of five is low, and says so in words.
      expect(_inStanding('PRICE'), findsOneWidget);
      expect(_inStanding(r'$349.00'), findsOneWidget);
      expect(_inStanding('COST'), findsOneWidget);
      expect(_inStanding(r'$181.50'), findsOneWidget);
      // (Whether stock is tracked comes off a watch of the company, a beat
      // after the record itself.)
      await screen.untilFound(_inStanding('Low stock'), 'the company');
      expect(_inStanding('Stock quantity'), findsOneWidget);
      expect(_inStanding('3'), findsOneWidget);
      expect(_inStanding('Stock value'), findsOneWidget);
      expect(_inStanding(r'$1,047.00'), findsOneWidget);

      // The profile: what the edit form sets and the card above does not
      // already say.
      expect(_card('Details'), findsOneWidget);
      expect(find.text('Default Quantity'), findsOneWidget);
      expect(find.text('Max Quantity'), findsOneWidget);
      expect(find.text('Stock Notifications'), findsOneWidget);
      expect(find.text('Notification Threshold'), findsOneWidget);
      expect(_card('Taxes'), findsOneWidget);
      expect(find.text('Physical Goods'), findsOneWidget);
      expect(find.text('VAT'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      // Not a second time: the description is the header's.
      expect(find.text('Notes'), findsNothing);

      // One tab. No Overview — it is all above the strip.
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Overview'), findsNothing);
      expect(
        tester
            .widget<EntityDocumentsTab>(find.byType(EntityDocumentsTab))
            .readOnly,
        isFalse,
      );
    },
    inventory: true,
  );

  _screenTest('a service with no cost and no stock draws neither', _bare(), (
    tester,
    screen,
  ) async {
    expect(_inHeader(find.text('Consulting')), findsOneWidget);

    expect(_inStanding(r'$150.00'), findsOneWidget);
    // An unentered cost is not a cost of nothing (#92), and stock is not a
    // figure this company keeps (#91): neither is drawn, dashed or zeroed.
    expect(find.text('COST'), findsNothing);
    expect(find.text('Stock quantity'), findsNothing);
    expect(find.text('Stock value'), findsNothing);
    expect(find.text(r'$0.00'), findsNothing);
    expect(find.text('—'), findsNothing);

    // One is what a line gets anyway.
    expect(find.text('Default Quantity'), findsNothing);
    expect(find.text('Stock Notifications'), findsNothing);
    expect(_card('Taxes'), findsNothing);
  });

  _screenTest('out of stock says so', _product(stock: 0), (
    tester,
    screen,
  ) async {
    await screen.untilFound(_inStanding('Out of stock'), 'the company');
    expect(_inStanding('Low stock'), findsNothing);
    expect(_inStanding('0'), findsOneWidget);
    // Nothing in stock is worth nothing: no line for it.
    expect(find.text('Stock value'), findsNothing);
  }, inventory: true);

  _screenTest(
    'a figure the product carries is shown even where stock is not tracked',
    _bare(stock: 12),
    (tester, screen) async {
      expect(_inStanding('Stock quantity'), findsOneWidget);
      expect(_inStanding('12'), findsOneWidget);
      // But nothing is watching it: no low / out call.
      expect(find.text('Low stock'), findsNothing);
      expect(find.text('Out of stock'), findsNothing);
    },
  );

  _screenTest(
    'a deleted product is read-only, and says so once',
    _product(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered — no tiles, no Edit.
      expect(_tile('+ Invoice'), findsNothing);
      expect(_tile('Clone'), findsNothing);
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
    'an archived product says so and keeps its actions',
    _product(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      expect(_tile('+ Invoice'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view products gets the banner without Restore, and '
    'no tile for a record they may not create',
    _product(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(_tile('+ Invoice'), findsNothing);
      expect(_tile('Clone'), findsNothing);
      expect(_tile('Tax Category'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_product',
    ),
  );

  _screenTest(
    'a user who may make invoices but not quotes gets only that tile',
    _product(),
    (tester, screen) async {
      expect(_tile('+ Invoice'), findsOneWidget);
      expect(_tile('+ Quote'), findsNothing);
      expect(_tile('+ Order'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_product,create_invoice',
    ),
  );

  final unsynced = _Server();
  _screenTest(
    'an unsynced product gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _product(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tile('+ Invoice'), findsNothing);
      expect(_tile('Clone'), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isNotEmpty, reason: 'the server was reachable');
      expect(unsynced.naming('tmp_1'), isEmpty);
    },
    server: unsynced,
  );

  group('wide', () {
    _screenTest(
      'the two cards share a level row, and the band ends on one line',
      _product(),
      (tester, screen) async {
        expect(tester.takeException(), isNull);
        final details = tester.getRect(_card('Details'));
        final taxes = tester.getRect(_card('Taxes'));
        expect(taxes.top, details.top);
        expect(taxes.bottom, details.bottom);
        expect(taxes.left, greaterThan(details.right));
        expect(details.width, moreOrLessEquals(taxes.width, epsilon: 0.5));

        final standing = tester.getRect(find.byType(StandingCard));
        final header = tester.getRect(find.byType(ProductDetailHeader));
        expect(standing.top, header.top);
        expect(standing.left, greaterThan(header.right));
        final tile = tester.getRect(
          find
              .ancestor(of: _tile('+ Invoice'), matching: find.byType(InkWell))
              .first,
        );
        expect(standing.bottom, moreOrLessEquals(tile.bottom, epsilon: 0.5));
      },
      inventory: true,
      size: const Size(1300, 1600),
    );
  });

  group('refresh', () {
    final recheck = _Server()..record = _json(updatedAt: 1710009999);
    _screenTest(
      'opening a cached product quietly re-checks it, once',
      _product(),
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
      _product(),
      (tester, screen) async {
        await screen.quiet();
        final before = server.recordAsks.length;
        server.record = _json(price: '399.00', updatedAt: 1710009999);

        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(
          () => server.recordAsks.length > before,
          'the refresh',
        );
        await screen.untilFound(find.text(r'$399.00'), 'the new price');
      },
      server: server,
      online: true,
    );
  });
}
