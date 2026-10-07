// The payment record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/payments/views/payment_detail_screen.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_header.dart';
import 'package:admin/ui/features/payments/widgets/payment_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

/// $1,250 received, $1,000 of it against two invoices, nothing refunded.
Map<String, dynamic> _json({
  String id = 'p1',
  String applied = '1000.00',
  String refunded = '0',
  bool isDeleted = false,
  int archivedAt = 0,
  bool withAllocations = true,
}) => {
  'id': id,
  'number': '0042',
  'status_id': '4',
  'client_id': 'c1',
  'currency_id': '1',
  // Far from today in both directions: nothing here depends on the clock.
  'date': '2001-03-14',
  'amount': '1250.00',
  'applied': applied,
  'refunded': refunded,
  'transaction_reference': 'ch_3PqR8sLkd',
  'private_notes': 'Paid over the phone.',
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'updated_at': 1710000000,
  'created_at': 1700000000,
  'paymentables': withAllocations
      ? [
          {'id': 'pa1', 'invoice_id': 'i1', 'amount': '600.00'},
          {'id': 'pa2', 'invoice_id': 'i2', 'amount': '400.00'},
        ]
      : <Object>[],
  'invoices': withAllocations
      ? [
          {'id': 'i1', 'number': '0031', 'amount': '600.00'},
          {'id': 'i2', 'number': '0032', 'amount': '900.00'},
        ]
      : <Object>[],
};

/// What the app asked the server, and what the server says back.
class _Server {
  /// The record `GET /payments/p1` returns — null leaves it unanswered.
  Map<String, dynamic>? record;

  /// Rows returned for the client's invoice list — what Apply looks through.
  List<Map<String, dynamic>> invoices = const [];

  final List<Uri> requests = [];

  Iterable<Uri> get recordAsks =>
      requests.where((u) => u.path == '/api/v1/payments/p1');

  http.Client get client => MockClient((request) async {
    final url = request.url;
    if (request.method != 'GET') {
      throw http.ClientException('offline (test fixture)');
    }
    if (url.path == '/api/v1/payments/p1' && record != null) {
      requests.add(url);
      return jsonOk({'data': record});
    }
    if (url.path == '/api/v1/invoices' &&
        url.queryParameters['client_id'] == 'c1') {
      requests.add(url);
      return jsonOk({'data': invoices});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

Future<void> _seed(Services services, Map<String, dynamic> payment) async {
  await services.clients.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ClientApi(
      id: 'c1',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
  );
  await services.payments.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: PaymentApi.fromJson(payment),
  );
}

/// The payment screen over a payment seeded into the local database.
void _screenTest(
  String description,
  Map<String, dynamic> payment,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) => _seed(services, payment),
  screen: () => PaymentDetailScreen(id: payment['id'] as String),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
);

Finder _tiles() => find.byType(EntityQuickActions<PaymentAction>);

/// A quick-action tile, by its short label.
Finder _tile(String label) =>
    find.descendant(of: _tiles(), matching: find.text(label));

/// Text on the standing card. Scoped, because the fixed bar's compact title
/// repeats the number and the amount (it is in the tree, faded out, until the
/// header scrolls away).
Finder _standing(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

Finder _header(String text) => find.descendant(
  of: find.byType(PaymentDetailHeader),
  matching: find.text(text),
);

/// What has been toasted. The harness mounts no `ToastHost`, so a toast is
/// read off the controller rather than found on screen.
List<String> _toasts(RecordScreen screen) => [
  for (final t in screen.services.toasts.toasts) t.message,
];

void main() {
  _screenTest(
    'an active payment: identity, actions, standing, profile, tabs',
    _json(),
    (tester, screen) async {
      expect(_header('#0042'), findsOneWidget);
      // Who paid, as a link, under the number.
      await screen.untilFound(_header('Acme Corporation'), 'the client link');
      // Its status rides in the header — it used to be nowhere on the screen.
      expect(find.text('Partially Unapplied'), findsOneWidget);

      // $250 is on it that pays for nothing yet, so Apply leads the tiles.
      for (final label in ['Apply', 'Email', 'Refund', 'Client']) {
        expect(_tile(label), findsOneWidget, reason: label);
      }

      // Standing: what came in and what was applied, always; the rest only
      // when there is some.
      expect(_standing('AMOUNT'), findsOneWidget);
      expect(_standing(r'$1,250.00'), findsOneWidget);
      expect(find.text('APPLIED'), findsOneWidget);
      expect(_standing(r'$1,000.00'), findsOneWidget);
      expect(_standing('Unapplied'), findsOneWidget);
      expect(_standing(r'$250.00'), findsOneWidget);
      expect(find.text('Refunded'), findsNothing);

      // The profile is simply there: how it was paid, and the user's note.
      expect(find.text('Transaction Reference'), findsOneWidget);
      expect(find.text('ch_3PqR8sLkd'), findsOneWidget);
      expect(find.text('Paid over the phone.'), findsOneWidget);

      // Comments and Activity lead the strip; the landing tab is what the
      // payment was applied to, and there is no Overview tab any more.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final invoices = tester.getTopLeft(find.text('Invoices')).dx;
      expect(comments, lessThan(activity));
      expect(activity, lessThan(invoices));
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Invoice #0031'), findsOneWidget);
      expect(find.text('Invoice #0032'), findsOneWidget);
      expect(find.text(r'$600.00'), findsOneWidget);

      // And the Comments tab offers a new comment — the control for the
      // deleted-payment test below, which expects exactly this to be gone.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('Add Comment'), 'the comments tab');
    },
  );

  _screenTest(
    'a payment applied in full and never refunded shows neither figure, '
    'and no Apply',
    _json(applied: '1250.00'),
    (tester, screen) async {
      expect(find.text('APPLIED'), findsOneWidget);
      // The label was the alarm (flutter#113): no "Refunded" over a zero, and
      // no "Unapplied" on a payment with nothing left on it.
      expect(find.text('Refunded'), findsNothing);
      expect(find.text('Unapplied'), findsNothing);
      expect(_tile('Apply'), findsNothing);
      // The tiles that do apply are still there.
      expect(_tile('Email'), findsOneWidget);
    },
  );

  _screenTest(
    'a refund is a figure once there is one',
    _json(applied: '1250.00', refunded: '100.00'),
    (tester, screen) async {
      expect(_standing('Refunded'), findsOneWidget);
      expect(_standing(r'$100.00'), findsOneWidget);
    },
  );

  _screenTest(
    'a payment applied to nothing says so on its landing tab',
    _json(applied: '0', withAllocations: false),
    (tester, screen) async {
      expect(find.text('No invoices found'), findsOneWidget);
      // Nothing to refund against, so no tile that would dead-end.
      expect(_tile('Refund'), findsNothing);
      expect(_tile('Apply'), findsOneWidget);
    },
  );

  _screenTest(
    'a deleted payment is read-only, and says so once',
    _json(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered.
      expect(_tile('Apply'), findsNothing);
      expect(_tile('Email'), findsNothing);

      // Its comments stay readable; adding one does not.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('No comments yet'), 'the comments tab');
      expect(find.text('Add Comment'), findsNothing);
    },
  );

  _screenTest(
    'an archived payment says so and keeps its actions',
    _json(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only.
      expect(_tile('Email'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view payments gets the banner without Restore, and '
    'neither Apply nor Refund',
    _json(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      // An allocation is an edit, and a refund is admin-only on the server.
      expect(_tile('Apply'), findsNothing);
      expect(_tile('Refund'), findsNothing);
      // Opening the client is still theirs to do.
      expect(_tile('Client'), findsOneWidget);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_payment,view_client',
    ),
  );

  final unsynced = _Server()..record = _json(id: 'tmp_1');
  _screenTest(
    'an unsynced payment gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _json(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tiles(), findsOneWidget, reason: 'mounted, and empty');
      expect(_tile('Email'), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isEmpty);
    },
    server: unsynced,
    online: true,
  );

  group('refresh', () {
    final server = _Server()..record = _json();
    _screenTest(
      'opening re-checks the record once, and R fetches it again — with '
      'nothing clicked first',
      _json(),
      (tester, screen) async {
        await screen.until(() => server.recordAsks.isNotEmpty, 'the re-check');
        await screen.quiet();
        expect(server.recordAsks, hasLength(1));

        // Straight from arrival: no click into the body to give the key
        // somewhere to land.
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(() => server.recordAsks.length == 2, 'the refresh');
      },
      server: server,
      online: true,
    );

    final newer = _Server()
      ..record = (_json(applied: '1250.00')..['updated_at'] = 1710009999);
    _screenTest(
      'a newer copy on the server replaces the cached figures',
      _json(),
      (tester, screen) async {
        expect(find.text('Unapplied'), findsOneWidget);
        await screen.until(
          () => find.text('Unapplied').evaluate().isEmpty,
          'the re-checked record',
        );
        expect(_tile('Apply'), findsNothing);
      },
      server: newer,
      online: true,
    );
  });

  group('Apply', () {
    Map<String, dynamic> invoice(String id, String date, String balance) => {
      'id': id,
      'client_id': 'c1',
      'number': id,
      'status_id': '2',
      'amount': '900.00',
      'balance': balance,
      'date': date,
      'due_date': '2999-01-01',
      'updated_at': 1700000000,
    };

    Future<List<String>> queued(RecordScreen screen) async {
      late List<String> kinds;
      await screen.tester.runAsync(() async {
        final rows = await screen.services.db.outboxDao.watchAll('co1').first;
        kinds = [for (final r in rows) r.mutationKind];
      });
      return kinds;
    }

    final server = _Server()
      ..invoices = [
        invoice('newer', '2001-05-01', '900.00'),
        invoice('older', '2001-02-01', '100.00'),
      ];
    _screenTest(
      'names the oldest unpaid invoice before any money moves, and moves '
      'none when cancelled',
      _json(),
      (tester, screen) async {
        await tester.tap(_tile('Apply'));
        await screen.untilFound(
          find.widgetWithText(AlertDialog, 'Apply Payment'),
          'the dialog',
        );
        // The older invoice, and only what it still owes — not the whole
        // $250 that is unapplied.
        expect(find.text('#older'), findsOneWidget);
        expect(find.text(r'$100.00'), findsNWidgets(2));
        expect(await queued(screen), isEmpty, reason: 'nothing yet');

        await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
        await screen.until(
          () => find.byType(AlertDialog).evaluate().isEmpty,
          'the dialog closing',
        );
        expect(await queued(screen), isEmpty);
      },
      server: server,
    );

    final confirm = _Server()
      ..invoices = [invoice('older', '2001-02-01', '100.00')];
    _screenTest('confirmed, it queues the allocation', _json(), (
      tester,
      screen,
    ) async {
      await tester.tap(_tile('Apply'));
      await screen.untilFound(find.byType(AlertDialog), 'the dialog');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Apply'),
        ),
      );
      // The outbox is read off the fake clock, so this polls it by hand
      // rather than through `screen.until`, whose predicate is synchronous.
      var kinds = const <String>[];
      for (var i = 0; i < 80 && kinds.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        kinds = await queued(screen);
      }
      expect(kinds, contains('apply_payment'));
      expect(_toasts(screen), contains('Successfully applied payment'));
      // Past the toast's own timer, which the binding checks for.
      await tester.pump(const Duration(seconds: 10));
    }, server: confirm);

    final none = _Server();
    _screenTest('with nothing unpaid it says so and opens no dialog', _json(), (
      tester,
      screen,
    ) async {
      await tester.tap(_tile('Apply'));
      await screen.until(
        () => _toasts(screen).contains('No unpaid invoices'),
        'the explanation',
      );
      expect(find.byType(AlertDialog), findsNothing);
      // Past the toast's own timer, which the binding checks for.
      await tester.pump(const Duration(seconds: 10));
    }, server: none);
  });
}
