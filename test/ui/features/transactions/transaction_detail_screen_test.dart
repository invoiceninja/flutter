// The bank-transaction record screen, assembled — the record layout end to end
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
import 'package:admin/ui/core/widgets/transaction_rule_matched_chip.dart';
import 'package:admin/ui/features/transactions/views/transaction_detail_screen.dart';
import 'package:admin/ui/features/transactions/widgets/detail/transaction_detail_header.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_actions.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_match_panel.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

const _unmatched = '1';
const _matched = '2';
const _converted = '3';

/// A $1,250 deposit through the Operating Account.
BankTransactionApi _tx({
  String id = 't1',
  String status = _unmatched,
  String description = 'Stripe payout',
  String ruleId = '',
  bool isDeleted = false,
  int archivedAt = 0,
}) => BankTransactionApi.fromJson({
  'id': id,
  'amount': '1250.00',
  'currency_id': '1',
  'base_type': 'CREDIT',
  // Far from today in both directions: nothing here depends on the clock.
  'date': '2001-03-14',
  'bank_integration_id': 'b1',
  'description': description,
  'status_id': status,
  'participant_name': 'Acme Corporation',
  'bank_transaction_rule_id': ruleId,
  'payment_id': status == _unmatched ? '' : 'p1',
  'invoice_ids': status == _unmatched ? '' : 'i1',
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'updated_at': 1710000000,
  'created_at': 1700000000,
});

Future<void> _seed(Services services, BankTransactionApi tx) async {
  await services.bankAccounts.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: BankAccountApi.fromJson({
      'id': 'b1',
      'bank_account_name': 'Operating Account',
      'currency': 'USD',
      'updated_at': 1710000000,
      'created_at': 1700000000,
    }),
  );
  await services.bankTransactions.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: tx,
  );
}

/// Records every request and answers none of them.
class _Server {
  final List<Uri> requests = [];

  http.Client get client => MockClient((request) async {
    requests.add(request.url);
    throw http.ClientException('offline (test fixture)');
  });
}

/// The transaction screen over a transaction seeded into the local database.
void _screenTest(
  String description,
  BankTransactionApi tx,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) => _seed(services, tx),
  screen: () => TransactionDetailScreen(id: tx.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
);

Finder _tiles() => find.byType(EntityQuickActions<TransactionAction>);

/// A quick-action tile, by its short label.
Finder _tile(String label) =>
    find.descendant(of: _tiles(), matching: find.text(label));

/// Text on the standing card. Scoped, because the fixed bar's compact title
/// repeats the amount (it is in the tree, faded out, until the header scrolls
/// away).
Finder _standing(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

Finder _header(String text) => find.descendant(
  of: find.byType(TransactionDetailHeader),
  matching: find.text(text),
);

void main() {
  _screenTest(
    'an unmatched deposit: identity, standing, the match panel — and no tiles',
    _tx(),
    (tester, screen) async {
      expect(_header('Stripe payout'), findsOneWidget);
      // The account it moved through, as a link, under the description.
      await screen.untilFound(
        _header('Operating Account'),
        'the bank account link',
      );

      // Standing: which way, how much, and whether it is accounted for.
      expect(_standing('DEPOSIT'), findsOneWidget);
      expect(_standing(r'+$1,250.00'), findsOneWidget);
      expect(_standing('Unmatched'), findsOneWidget);

      // Matching it *is* the panel on the screen; a tile that only pointed
      // at it would be a button for looking down.
      expect(_tile('Convert'), findsNothing);
      expect(_tile('Unlink'), findsNothing);
      expect(find.byType(TransactionMatchPanel), findsOneWidget);
      expect(find.text('Create Payment'), findsWidgets);

      // The profile is simply there.
      expect(find.text('Participant name'), findsOneWidget);
      // A short description is already the title, and is not repeated.
      expect(find.text('Description'), findsNothing);
    },
  );

  _screenTest(
    'a description too long for the header is repeated whole in Details',
    _tx(
      description:
          'ACH CREDIT ACME CORPORATION INV 0031 0032 REF 88213377 TRACE 0042',
    ),
    (tester, screen) async {
      expect(find.text('Description'), findsOneWidget);
    },
  );

  _screenTest(
    'the work comes first on a narrow screen: the panel sits above Details',
    _tx(),
    (tester, screen) async {
      final panel = tester.getTopLeft(find.byType(TransactionMatchPanel)).dy;
      final details = tester.getTopLeft(find.text('Details')).dy;
      expect(panel, lessThan(details));
    },
  );

  _screenTest(
    'a matched transaction can be converted or unlinked',
    _tx(status: _matched),
    (tester, screen) async {
      expect(_standing('Matched'), findsOneWidget);
      expect(_tile('Convert'), findsOneWidget);
      expect(_tile('Unlink'), findsOneWidget);
      // Still matchable, so the panel stays.
      expect(find.byType(TransactionMatchPanel), findsOneWidget);
    },
  );

  _screenTest(
    'a match made by a rule names the rule beside the status',
    _tx(status: _matched, ruleId: 'r1'),
    (tester, screen) async {
      expect(
        find.descendant(
          of: find.byType(StandingCard),
          matching: find.byType(TransactionRuleMatchedChip),
        ),
        findsOneWidget,
      );
    },
  );

  _screenTest(
    'a rule that matched nothing yet is not named',
    _tx(ruleId: 'r1'),
    (tester, screen) async {
      expect(find.byType(TransactionRuleMatchedChip), findsNothing);
    },
  );

  _screenTest(
    'a converted transaction opens what it became, and has no panel',
    _tx(status: _converted),
    (tester, screen) async {
      expect(_standing('Converted'), findsOneWidget);
      expect(_tile('Payment'), findsOneWidget);
      expect(_tile('Unlink'), findsOneWidget);
      expect(_tile('Convert'), findsNothing);
      expect(find.byType(TransactionMatchPanel), findsNothing);
    },
  );

  _screenTest(
    'a deleted transaction is read-only, and says so once',
    _tx(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // It is matched to nothing until it has been restored.
      expect(find.byType(TransactionMatchPanel), findsNothing);
    },
  );

  _screenTest(
    'a deleted, converted transaction offers no tiles either',
    _tx(status: _converted, isDeleted: true),
    (tester, screen) async {
      expect(_tile('Unlink'), findsNothing);
      expect(_tile('Payment'), findsNothing);
    },
  );

  _screenTest(
    'an archived transaction says so and keeps its panel',
    _tx(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only.
      expect(find.byType(TransactionMatchPanel), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view transactions is not offered Convert or Unlink',
    // The server skips a row this user may not edit and still answers 200,
    // so ungated the app reported a conversion that never happened.
    _tx(status: _matched),
    (tester, screen) async {
      expect(_tile('Convert'), findsNothing);
      expect(_tile('Unlink'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_bank_transaction',
    ),
  );

  _screenTest(
    '…and one who may create them is — the row cannot say whose it is',
    _tx(status: _matched),
    (tester, screen) async {
      expect(_tile('Convert'), findsOneWidget);
      expect(_tile('Unlink'), findsOneWidget);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_bank_transaction,create_bank_transaction',
    ),
  );

  _screenTest(
    'a user who may only view transactions gets the banner without Restore',
    _tx(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_bank_transaction',
    ),
  );

  _screenTest(
    'an unsynced, converted transaction gets the sync banner and no tiles',
    _tx(id: 'tmp_1', status: _converted),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tile('Unlink'), findsNothing);
    },
  );

  final server = _Server();
  _screenTest(
    'R is heard with nothing clicked first, and re-fetches this transaction '
    'by id — never the table',
    // Converted, so the match panel's pickers are not on screen asking for
    // their own lists.
    _tx(status: _converted),
    (tester, screen) async {
      await screen.quiet();
      Iterable<Uri> asks() => server.requests.where(
        (u) => u.path.startsWith('/api/v1/bank_transactions'),
      );
      final before = asks().length;
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
      await screen.until(() => asks().length > before, 'the refresh');
      await screen.quiet();
      // `BankTransactionRepository.refreshByIds` was the base no-op, so this
      // used to ask for nothing at all. A sweep of the table is the other
      // thing it must never be.
      for (final u in asks().skip(before)) {
        expect(u.path, '/api/v1/bank_transactions/t1', reason: '$u');
      }
    },
    server: server,
    online: true,
  );
}
