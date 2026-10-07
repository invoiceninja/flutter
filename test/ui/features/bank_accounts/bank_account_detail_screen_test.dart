// The bank-account record screen, assembled — the record layout end to end
// against a real `Services` graph and a real local database, with the network
// played by a `MockClient`. The harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/bank_account_api_model.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_detail_screen.dart';
import 'package:admin/ui/features/bank_accounts/widgets/bank_account_actions.dart';
import 'package:admin/ui/features/bank_accounts/widgets/detail/bank_account_detail_header.dart';
import 'package:admin/ui/features/bank_accounts/widgets/reconnect_banner.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

/// A Yodlee-connected checking account at Chase, holding $48,210.55.
BankAccountApi _account({
  String id = 'b1',
  String integration = 'YODLEE',
  bool disabledUpstream = false,
  bool isDeleted = false,
  int archivedAt = 0,
}) => BankAccountApi.fromJson({
  'id': id,
  'bank_account_name': 'Operating Account',
  'bank_account_status': 'ACTIVE',
  'bank_account_type': 'Checking',
  'provider_name': 'Chase',
  'balance': '48210.55',
  'currency': 'USD',
  'auto_sync': true,
  'disabled_upstream': disabledUpstream,
  'integration_type': integration,
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'updated_at': 1710000000,
  'created_at': 1700000000,
});

Map<String, dynamic> _txJson(String id) => {
  'id': id,
  'amount': '120.00',
  'currency_id': '1',
  'base_type': 'CREDIT',
  'date': '2001-03-14',
  'bank_integration_id': 'b1',
  'description': 'Deposit $id',
  'status_id': '1',
  'updated_at': 1700000000,
  'created_at': 1700000000,
};

const _transactions = '/api/v1/bank_transactions';
const _accounts = '/api/v1/bank_integrations';

/// What the app asked the server, and what the server says back.
class _Server {
  /// `meta.pagination.total` for a `per_page=1` count of transactions — null
  /// leaves the count unanswered.
  int? total;

  /// Rows returned for a transaction list page.
  List<Map<String, dynamic>> rows = const [];

  final List<Uri> requests = [];

  Iterable<Uri> get counts =>
      requests.where((u) => u.queryParameters['per_page'] == '1');

  Iterable<Uri> get listAsks => requests.where(
    (u) => u.path == _transactions && u.queryParameters['per_page'] != '1',
  );

  /// Requests for the account itself, by id.
  Iterable<Uri> get accountAsks =>
      requests.where((u) => u.path.startsWith('$_accounts/'));

  http.Client get client => MockClient((request) async {
    final url = request.url;
    if (request.method != 'GET') {
      throw http.ClientException('offline (test fixture)');
    }
    if (url.path == _transactions) {
      if (url.queryParameters['per_page'] == '1') {
        final total = this.total;
        if (total == null) throw http.ClientException('offline');
        requests.add(url);
        return countOf(total);
      }
      requests.add(url);
      return jsonOk({'data': rows});
    }
    if (url.path.startsWith('$_accounts/')) {
      // Asked for, and not answered: the cached row stays on screen.
      requests.add(url);
      throw http.ClientException('offline (test fixture)');
    }
    throw http.ClientException('offline (test fixture)');
  });
}

Future<void> _seed(Services services, BankAccountApi account) async {
  await services.bankAccounts.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: account,
  );
  await services.bankTransactions.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: BankTransactionApi.fromJson(_txJson('seeded')),
  );
}

/// The bank-account screen over an account seeded into the local database.
void _screenTest(
  String description,
  BankAccountApi account,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) => _seed(services, account),
  screen: () => BankAccountDetailScreen(id: account.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
);

Finder _tiles() => find.byType(EntityQuickActions<BankAccountAction>);

/// A quick-action tile, by its short label.
Finder _tile(String label) =>
    find.descendant(of: _tiles(), matching: find.text(label));

/// Text on the standing card. Scoped, because the fixed bar's compact title
/// repeats the balance (it is in the tree, faded out, until the header
/// scrolls away).
Finder _standing(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

Finder _header(String text) => find.descendant(
  of: find.byType(BankAccountDetailHeader),
  matching: find.text(text),
);

/// The count badge drawn inside the tab labelled [label].
Finder _badge(String label, String count) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  matching: find.text(count),
);

Switch _autoSync(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch));

void main() {
  _screenTest(
    'an active account: identity, actions, standing, profile, transactions',
    _account(),
    (tester, screen) async {
      expect(_header('Operating Account'), findsOneWidget);
      // Institution · kind · how it is connected, under the name.
      expect(_header('Chase'), findsOneWidget);
      expect(_header('Checking'), findsOneWidget);
      expect(_header('Yodlee'), findsOneWidget);

      expect(_tile('View All'), findsOneWidget);
      expect(_tile('Refresh'), findsOneWidget);

      expect(_standing('BALANCE'), findsOneWidget);
      expect(_standing(r'$48,210.55'), findsOneWidget);

      // The profile is simply there, with the one setting worth flipping.
      expect(find.text('Account type'), findsOneWidget);
      expect(find.text('Auto Sync'), findsOneWidget);
      expect(_autoSync(tester).value, isTrue);
      expect(_autoSync(tester).onChanged, isNotNull);

      // The strip's one tab is the account's transactions.
      expect(find.text('Transactions'), findsOneWidget);
      await screen.untilFound(find.text('Deposit seeded'), 'the list');
      // The connection is up: no reconnect banner.
      expect(
        find.descendant(
          of: find.byType(ReconnectBanner),
          matching: find.text('Reconnect'),
        ),
        findsNothing,
      );
    },
  );

  _screenTest('flipping Auto Sync queues the one-field save', _account(), (
    tester,
    screen,
  ) async {
    await tester.tap(find.byType(Switch));
    await screen.until(() => !_autoSync(tester).value, 'the switch');
    late List<String> kinds;
    await tester.runAsync(() async {
      final rows = await screen.services.db.outboxDao.watchAll('co1').first;
      kinds = [
        for (final r in rows)
          if (r.entityId == 'b1') r.mutationKind,
      ];
    });
    expect(kinds, ['update']);
  });

  _screenTest(
    'a manually entered account has nothing upstream to refresh',
    _account(integration: ''),
    (tester, screen) async {
      expect(_tile('View All'), findsOneWidget);
      expect(_tile('Refresh'), findsNothing);
      // "Manual" is not worth a segment; the institution and kind still are.
      expect(_header('Manual'), findsNothing);
      expect(_header('Chase'), findsOneWidget);
    },
  );

  _screenTest(
    'a dropped connection leads with the reconnect banner, and has no '
    'Refresh until it is back',
    _account(disabledUpstream: true),
    (tester, screen) async {
      expect(
        find.descendant(
          of: find.byType(ReconnectBanner),
          matching: find.text('Reconnect'),
        ),
        findsOneWidget,
      );
      expect(_tile('Refresh'), findsNothing);
      // The banner is above the name, not below the cards.
      expect(
        tester.getTopLeft(find.byType(ReconnectBanner)).dy,
        lessThan(tester.getTopLeft(_header('Operating Account')).dy),
      );
    },
  );

  _screenTest(
    'a deleted account is read-only, and says so once',
    _account(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered — the switch is an edit.
      expect(_tile('View All'), findsNothing);
      expect(_autoSync(tester).onChanged, isNull);
      // And the embedded list offers no New.
      expect(find.widgetWithText(FilledButton, 'New'), findsNothing);
    },
  );

  _screenTest(
    'an archived account says so and keeps its actions',
    _account(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only.
      expect(_tile('View All'), findsOneWidget);
      expect(_autoSync(tester).onChanged, isNotNull);
    },
  );

  _screenTest(
    'archive, restore and Refresh are an admin\'s — every edit right there is '
    'does not buy them',
    // `BulkBankIntegrationRequest` and `AdminBankIntegrationRequest` are both
    // `isAdmin()`. Gated on `edit_bank_integration`, an `edit_all` user was
    // offered all three and refused each.
    _account(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(_tile('Refresh'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'edit_all,view_all',
    ),
  );

  _screenTest(
    'a user who may not edit bank accounts gets the banner without Restore, '
    'and a switch that does nothing',
    _account(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(_autoSync(tester).onChanged, isNull);
      expect(_tile('Refresh'), findsNothing);
      // Opening the transactions is still theirs to do.
      expect(_tile('View All'), findsOneWidget);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_bank_transaction',
    ),
  );

  final unsynced = _Server()..total = 12;
  _screenTest(
    'an unsynced account gets the sync banner — no tiles, and nothing is '
    'counted on a server that has never seen it',
    _account(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tile('View All'), findsNothing);
      await screen.quiet();
      expect(unsynced.counts, isEmpty);
    },
    server: unsynced,
    online: true,
  );

  group('the count on the Transactions tab', () {
    final counted = _Server()..total = 128;
    _screenTest(
      'is the server total, asked with the key the list itself sends',
      _account(),
      (tester, screen) async {
        await screen.untilFound(_badge('Transactions', '128'), 'the badge');
        for (final u in counted.counts) {
          // Plural: the only form `BankTransactionFilters` reads.
          expect(u.queryParameters['bank_integration_ids'], 'b1');
          expect(u.queryParameters['status'], 'active');
          // The list always sends this, and the server then returns nothing
          // for an archived or deleted account — so the count has to as well,
          // or such an account wears a badge over a list that fetches no rows.
          expect(u.queryParameters['active_banks'], 'true');
        }
      },
      server: counted,
      online: true,
    );

    final offline = _Server()..total = 128;
    _screenTest('offline, the tab carries no count', _account(), (
      tester,
      screen,
    ) async {
      await screen.quiet();
      expect(_badge('Transactions', '128'), findsNothing);
      expect(offline.counts, isEmpty);
    }, server: offline);
  });

  group('refresh', () {
    final server = _Server()..rows = [_txJson('i1')];
    _screenTest(
      'R reloads this account\'s transactions — one page, still scoped — and '
      'the account itself by id, with nothing clicked first',
      _account(),
      (tester, screen) async {
        await screen.untilFound(find.text('Deposit i1'), 'the list');
        await screen.quiet();
        final listsBefore = server.listAsks.length;
        final accountsBefore = server.accountAsks.length;

        // Straight from arrival: no click into the body to give the key
        // somewhere to land.
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(
          () =>
              server.listAsks.length > listsBefore &&
              server.accountAsks.length > accountsBefore,
          'the refresh',
        );
        await screen.quiet();

        // The account by id — never the whole accounts list.
        expect(server.accountAsks.last.path, '$_accounts/b1');

        // Every list request the refresh made named the account. The list's
        // own `refresh` is a sweep of every transaction the company has.
        for (final u in server.listAsks.skip(listsBefore)) {
          expect(u.queryParameters['bank_integration_ids'], 'b1', reason: '$u');
          expect(u.queryParameters['page'], '1', reason: '$u');
        }
      },
      server: server,
      online: true,
    );
  });
}
