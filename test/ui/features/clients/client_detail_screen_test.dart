// The client record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/clients/views/client_detail_screen.dart';
import 'package:admin/ui/features/clients/widgets/client_actions.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_header.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_past_due_line.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

const _contacts = [
  ContactApi(
    id: 'k1',
    firstName: 'Jane',
    lastName: 'Doe',
    email: 'jane@acme.example.com',
    isPrimary: true,
  ),
  ContactApi(id: 'k2', firstName: 'Sam', lastName: 'Lee'),
];

ClientApi _client({
  String id = 'c1',
  bool isDeleted = false,
  int archivedAt = 0,
}) => ClientApi(
  id: id,
  name: 'Acme Corporation',
  displayName: 'Acme Corporation',
  number: '0042',
  balance: '4250.00',
  paidToDate: '18900.00',
  city: 'Berlin',
  vatNumber: 'DE123456789',
  privateNotes: 'Call before visiting.',
  isDeleted: isDeleted,
  archivedAt: archivedAt,
  updatedAt: 1710000000,
  createdAt: 1700000000,
  contacts: _contacts,
);

// Far from today in both directions, so no clock or timezone can move an
// invoice across the line.
Map<String, dynamic> _invoice(String id, String balance, String due) => {
  'id': id,
  'client_id': 'c1',
  'number': id,
  'status_id': '2',
  'amount': balance,
  'balance': balance,
  'due_date': due,
  'date': '2000-01-01',
  'updated_at': 1700000000,
};

/// What the app asked the server, and what the server says back.
class _Server {
  /// Rows returned for a client-scoped invoice list (and its unpaid slice).
  List<Map<String, dynamic>> invoices = const [];

  /// `meta.pagination.total` by list path, for a `per_page=1` count request.
  Map<String, int> totals = const {};

  /// The record `GET /clients/{id}` returns — null leaves it unanswered.
  Map<String, dynamic>? record;

  /// Answer `GET /clients/{id}` the way the server refuses a record this user
  /// may not view — or one that belongs to another company.
  bool denyRecord = false;

  Iterable<Uri> get recordAsks =>
      requests.where((u) => u.path == '/api/v1/clients/c1');

  final List<Uri> requests = [];

  Iterable<Uri> get counts =>
      requests.where((u) => u.queryParameters['per_page'] == '1');

  Iterable<Uri> get unpaidAsks =>
      requests.where((u) => u.queryParameters['client_status'] == 'unpaid');

  http.Client get client => MockClient((request) async {
    final url = request.url;
    http.Response json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
    if (request.method != 'GET') {
      throw http.ClientException('offline (test fixture)');
    }
    final query = url.queryParameters;
    if (query['per_page'] == '1') {
      final total = totals[url.path];
      if (total != null) {
        requests.add(url);
        return json({
          'data': <Object>[],
          'meta': {
            'pagination': {'total': total},
          },
        });
      }
    } else if (url.path == '/api/v1/invoices' && query['client_id'] == 'c1') {
      requests.add(url);
      final rows = query['overdue'] == 'true'
          ? [
              for (final i in invoices)
                if ((i['due_date'] as String).startsWith('2000')) i,
            ]
          : invoices;
      return json({'data': rows});
    } else if (url.path == '/api/v1/clients/c1' && denyRecord) {
      requests.add(url);
      return http.Response(
        jsonEncode({'message': 'This action is unauthorized.'}),
        401,
        headers: {'content-type': 'application/json'},
      );
    } else if (url.path == '/api/v1/clients/c1' && record != null) {
      requests.add(url);
      return json({'data': record});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The client screen over a client seeded into the local database.
void _screenTest(
  String description,
  ClientApi client,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  List<FakeCompany> otherCompanies = const [],
  Future<void> Function(WidgetTester tester, RecordScreen screen)? beforeSettle,
}) => recordScreenTest(
  description,
  seed: (services) => services.clients.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: client,
  ),
  screen: () => ClientDetailScreen(id: client.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
  otherCompanies: otherCompanies,
  beforeSettle: beforeSettle,
);

/// The count badge drawn inside the tab labelled [label].
Finder _badge(String label, String count) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  matching: find.text(count),
);

void main() {
  _screenTest(
    'an active client: identity, actions, standing, profile, tabs',
    _client(),
    (tester, screen) async {
      expect(find.text('Acme Corporation'), findsWidgets);
      // Place · number under the name. (The city is in the Address card too.)
      expect(
        find.descendant(
          of: find.byType(ClientDetailHeader),
          matching: find.text('Berlin'),
        ),
        findsOneWidget,
      );
      expect(find.text('#0042'), findsOneWidget);

      expect(find.byType(EntityQuickActions<ClientAction>), findsOneWidget);
      expect(find.text('+ Invoice'), findsOneWidget);

      // The profile is simply there — nothing to open. Every contact, the
      // details, and the note the user left themselves.
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Sam Lee'), findsOneWidget);
      expect(find.text('VAT Number'), findsOneWidget);
      expect(find.text('DE123456789'), findsOneWidget);
      expect(find.text('Call before visiting.'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Comments and Activity still lead the strip.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final invoices = tester.getTopLeft(find.text('Invoices')).dx;
      expect(comments, lessThan(activity));
      expect(activity, lessThan(invoices));

      // And the Comments tab offers a new comment — the control for the
      // deleted-client test below, which expects exactly this to be gone.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('Add Comment'), 'the comments tab');
    },
  );

  _screenTest(
    'a deleted client is read-only, and says so once',
    _client(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered.
      expect(find.text('+ Invoice'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'New'), findsNothing);

      // Its comments stay readable; adding one does not.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('No comments yet'), 'the comments tab');
      expect(find.text('Add Comment'), findsNothing);
    },
  );

  _screenTest(
    'an archived client says so and keeps its actions',
    _client(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only: the server still accepts edits and new
      // records for it.
      expect(find.text('+ Invoice'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view clients gets the banner without Restore',
    _client(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_client',
    ),
  );

  final unsynced = _Server()..totals = const {'/api/v1/invoices': 12};
  _screenTest(
    'an unsynced client gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _client(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(find.text('+ Invoice'), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isEmpty);
    },
    server: unsynced,
    online: true,
  );

  group('the past-due line', () {
    final late = _Server()
      ..invoices = [
        _invoice('late1', '1000.00', '2000-01-01'),
        _invoice('late2', '240.00', '2000-02-01'),
        _invoice('current', '3010.00', '2999-01-01'),
      ];
    _screenTest(
      'says how much of the balance is late, and opens exactly those invoices',
      // 4,250.00 owed.
      _client(),
      (tester, screen) async {
        await screen.untilFound(find.byType(ClientPastDueLine), 'the line');
        expect(late.unpaidAsks.single.queryParameters['client_id'], 'c1');
        expect(find.text(r'Past Due: $1,240.00 · Invoices: 2'), findsOneWidget);

        await tester.tap(find.byType(ClientPastDueLine));
        // The Invoices tab, narrowed by the list's own filter — which the
        // user can see and remove.
        await screen.until(
          () =>
              late.requests.any((u) => u.queryParameters['overdue'] == 'true'),
          'the filtered list',
        );
        await screen.untilFound(find.text('overdue'), 'the filter chip');
        expect(find.text('#late1'), findsOneWidget);
        expect(find.text('#late2'), findsOneWidget);
        expect(find.text('#current'), findsNothing);
      },
      server: late,
    );

    final none = _Server()
      ..invoices = [_invoice('current', '4250.00', '2999-01-01')];
    _screenTest('nothing late is a plain zero that leads nowhere', _client(), (
      tester,
      screen,
    ) async {
      await screen.untilFound(find.text(r'Past Due: $0.00'), 'the line');
      expect(
        find.descendant(
          of: find.byType(ClientPastDueLine),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    }, server: none);

    final short = _Server()
      // 1,000 of a 4,250 balance: something is missing or stale.
      ..invoices = [_invoice('late1', '1000.00', '2000-01-01')];
    _screenTest(
      'invoices that do not add up to the balance say nothing',
      _client(),
      (tester, screen) async {
        // First that it asked — or "no line" would pass just as well with the
        // fetch never having run.
        await screen.until(() => short.unpaidAsks.isNotEmpty, 'the fetch');
        await screen.quiet();
        expect(find.byType(ClientPastDueLine), findsNothing);
      },
      server: short,
    );

    _screenTest('offline says nothing', _client(), (tester, screen) async {
      await screen.quiet();
      expect(find.byType(ClientPastDueLine), findsNothing);
    });
  });

  group('counts on the related tabs', () {
    final counted = _Server()
      ..totals = const {'/api/v1/invoices': 12, '/api/v1/quotes': 0};
    _screenTest(
      'each tab says how many records it holds on the server',
      _client(),
      (tester, screen) async {
        await screen.untilFound(_badge('Invoices', '12'), 'the badges');
        // A real zero is worth saying: it is a tab not worth opening.
        expect(_badge('Quotes', '0'), findsOneWidget);
        // Payments was never answered — no badge, not a zero.
        expect(_badge('Payments', '0'), findsNothing);

        expect(counted.counts, isNotEmpty);
        for (final u in counted.counts) {
          expect(u.queryParameters['client_id'], 'c1');
          expect(u.queryParameters['status'], 'active');
        }
      },
      server: counted,
      online: true,
    );

    final recheck = _Server()
      ..totals = const {'/api/v1/invoices': 12, '/api/v1/quotes': 3}
      // The server's copy is newer than the cached one.
      ..record = {
        'id': 'c1',
        'name': 'Acme Corporation',
        'display_name': 'Acme Corporation',
        'balance': '4250.00',
        'paid_to_date': '18900.00',
        'updated_at': 1710009999,
        'contacts': <Object>[],
      };
    _screenTest(
      'a re-check that finds a newer record does not make every count be '
      'asked twice',
      _client(),
      (tester, screen) async {
        // The counts used to go out beside the re-check; its newer
        // `updated_at` then read as "the record moved" and sent all of them
        // again while the first batch was still in flight.
        await screen.untilFound(_badge('Invoices', '12'), 'the badges');
        await screen.quiet();
        expect(recheck.recordAsks, hasLength(1), reason: 'the re-check ran');
        final byPath = <String, int>{};
        for (final u in recheck.counts) {
          byPath[u.path] = (byPath[u.path] ?? 0) + 1;
        }
        expect(byPath, {'/api/v1/invoices': 1, '/api/v1/quotes': 1});
      },
      server: recheck,
      online: true,
    );

    final offline = _Server()..totals = const {'/api/v1/invoices': 12};
    _screenTest('offline, the tabs carry no counts at all', _client(), (
      tester,
      screen,
    ) async {
      await screen.quiet();
      expect(_badge('Invoices', '12'), findsNothing);
      expect(offline.counts, isEmpty);
    }, server: offline);
  });

  group('a record the server will not give this user', () {
    // The server's answer to "you may not view this record" is a 401, and the
    // app used to treat every 401 as a dead session. The quiet re-check asks
    // for the record by id on every open, so it turned "you can no longer see
    // this client" — or, after a company switch, "that client is in the other
    // company" — into being signed out.
    final denied = _Server()..denyRecord = true;
    _screenTest(
      'being refused the record does not end the session',
      _client(),
      (tester, screen) async {
        await screen.until(() => denied.recordAsks.isNotEmpty, 'the re-check');
        await screen.quiet();
        expect(
          screen.services.auth.session.value,
          isNotNull,
          reason: 'still signed in',
        );
        // And the cached record is still what is on screen.
        expect(find.text('Acme Corporation'), findsWidgets);
        expect(find.byType(StandingCard), findsOneWidget);
      },
      server: denied,
      online: true,
    );

    final switched = _Server()..denyRecord = true;
    _screenTest(
      'switching company with a client open neither signs out nor undoes the '
      'switch',
      _client(),
      (tester, screen) async {
        // This screen outlives the switch and still shows the old company's
        // client, while the token is already the new company's. Widgets on it
        // that resolve "the current company" when they build — the currency
        // lookup behind every amount, a client-name label — ask for that
        // client by id, and the server refuses a record in another company.
        //
        // That refusal used to be read as a rejected token: before the new
        // token had answered anything it rolled the switch back, and after,
        // it ended the session.
        await screen.until(
          () => switched.recordAsks.isNotEmpty,
          'a leftover widget asking for the old company\'s client',
        );
        await screen.quiet();
        final session = screen.services.auth.session.value;
        expect(session, isNotNull, reason: 'still signed in');
        expect(session!.currentCompanyId, 'co2', reason: 'and still switched');
      },
      server: switched,
      otherCompanies: const [FakeCompany(id: 'co2', name: 'Other')],
      beforeSettle: (tester, screen) async {
        await tester.runAsync(() => screen.services.auth.switchCompany('co2'));
      },
    );
  });

  group('refresh', () {
    final server = _Server()
      ..invoices = [_invoice('i1', '4250.00', '2999-01-01')];
    _screenTest(
      'R reloads this client\'s list — one page, still scoped — with nothing '
      'clicked first',
      _client(),
      (tester, screen) async {
        await screen.untilFound(find.text('#i1'), 'the list');
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

        // Every request the refresh made for invoices named the client. The
        // list's own `refresh` is a sweep of the whole entity — every page,
        // no client — and that is what this used to call.
        final after = server.requests.skip(before).toList();
        expect(after, isNotEmpty);
        for (final u in after.where((u) => u.path == '/api/v1/invoices')) {
          expect(u.queryParameters['client_id'], 'c1', reason: '$u');
          expect(u.queryParameters['page'], '1', reason: '$u');
        }
      },
      server: server,
    );
  });
}
