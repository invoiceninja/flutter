import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// The Email History tab drops invitations nothing was ever sent to
/// (invoiceninja/flutter#146).
///
/// The server seeds one invitation per send-email contact when the *document*
/// is saved, so a draft listed every contact with nothing beneath it under a
/// heading reading "Email History" — testers read that as proof the contact
/// had been emailed. These tests pin the filter, the two empty-state copies,
/// the states that must survive it (a failed send, a bounce, a spam
/// complaint), and the queued-send row that keeps the tab from denying a send
/// the user has just made offline.
///
/// Every pump is explicit: the queued row spins a `CircularProgressIndicator`
/// forever, so `pumpAndSettle` would never return.

final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'X',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

Contact _contact(String id, String first, String last, String email) => Contact(
  id: id,
  firstName: first,
  lastName: last,
  email: email,
  phone: '',
  isPrimary: id == 'c1',
  sendEmail: true,
  updatedAt: DateTime.utc(2026, 1, 1, 12),
  isDeleted: false,
);

final _client = emptyClient().copyWith(
  id: 'cl1',
  contacts: [
    _contact('c1', 'Jane', 'Doe', 'jane@example.com'),
    _contact('c2', 'Bob', 'Stone', 'bob@example.com'),
  ],
);

final _vendor = emptyVendor().copyWith(
  id: 'v1',
  contacts: [
    VendorContact(
      id: 'vc1',
      firstName: 'Vera',
      lastName: 'Ng',
      email: 'vera@example.com',
      phone: '',
      password: '',
      sendEmail: true,
      isPrimary: true,
      customValue1: '',
      customValue2: '',
      customValue3: '',
      customValue4: '',
      updatedAt: DateTime.utc(2026, 1, 1, 12),
      isDeleted: false,
    ),
  ],
);

/// A synthetic stream, not a real Drift watch: `pumpAndSettle` never settles
/// over a live query. `Stream.multi` rather than `Stream.value` because more
/// than one thing may listen over the widget's life, and a
/// single-subscription stream throws the second time.
class _FakeOutboxDao implements OutboxDao {
  _FakeOutboxDao(this.rows);

  final List<OutboxRow> rows;

  /// Honours `kind:` deliberately. With it ignored, re-adding
  /// `kind: MutationKind.reactivateEmail` to the production watch would leave
  /// every test in this file green — including the one that exists to pin the
  /// filter being dropped.
  @override
  Stream<List<OutboxRow>> watchPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    MutationKind? kind,
  }) => Stream<List<OutboxRow>>.multi((c) {
    c.add(
      kind == null
          ? rows
          : rows.where((r) => r.mutationKind == kind.wireName).toList(),
    );
    c.close();
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeDb implements AppDatabase {
  _FakeDb(this.outboxDao);

  @override
  final OutboxDao outboxDao;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeClients implements ClientRepository {
  _FakeClients(this.client);

  final Client? client;

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {}

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream<Client?>.multi((c) {
        c.add(client);
        c.close();
      });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeVendors implements VendorRepository {
  _FakeVendors(this.vendor);

  final Vendor? vendor;

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {}

  @override
  Stream<Vendor?> watch({required String companyId, required String id}) =>
      Stream<Vendor?>.multi((c) {
        c.add(vendor);
        c.close();
      });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeServices implements Services {
  _FakeServices({
    required this.db,
    required this.clients,
    required this.vendors,
  });

  @override
  final AppDatabase db;

  @override
  final ClientRepository clients;

  @override
  final VendorRepository vendors;

  @override
  final ToastController toasts = ToastController();

  @override
  Future<Formatter> formatterFor(String companyId) async => _formatter;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

OutboxRow _outboxRow(MutationKind kind) => OutboxRow(
  id: 1,
  companyId: 'co-A',
  entityType: 'invoice',
  entityId: 'e1',
  mutationKind: kind.wireName,
  payload: '{}',
  idempotencyKey: 'k1',
  attempts: 0,
  nextAttemptAt: 0,
  state: 'pending',
  requiresPassword: false,
  createdAt: 0,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<Invitation> invitations,
  List<OutboxRow> pending = const [],
  bool isDirty = false,
  bool isHosted = true,
  bool vendor = false,
  double textScale = 1,
}) async {
  final services = _FakeServices(
    db: _FakeDb(_FakeOutboxDao(pending)),
    clients: _FakeClients(vendor ? null : _client),
    vendors: _FakeVendors(vendor ? _vendor : null),
  );
  addTearDown(services.toasts.dispose);
  await tester.pumpWidget(
    Provider<Services>.value(
      value: services,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          // Mirrors production: every one of the six mount sites sits inside
          // a vertical scroll view, which is what makes `EmptyState`'s own
          // inner scroll view shrink-wrap rather than scroll.
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SingleChildScrollView(
                child: BillingDocSendsTab(
                  // A fresh key per pump. Without it a second `pumpWidget` of
                  // the same widget type reuses the State, so `initState`'s
                  // `late final` streams stay bound to the FIRST call's fakes
                  // and a multi-case test silently asserts against stale data.
                  key: UniqueKey(),
                  services: services,
                  companyId: 'co-A',
                  entityWireName: vendor ? 'purchase_order' : 'invoice',
                  entityId: 'e1',
                  invitations: invitations,
                  isHosted: isHosted,
                  isDirty: isDirty,
                  onReactivate: (_) async => 1,
                  clientId: vendor ? '' : 'cl1',
                  vendorId: vendor ? 'v1' : '',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // Streams + the formatter future; never pumpAndSettle (see the file doc).
  await tester.pump();
  await tester.pump();
}

String? _pillTooltip(WidgetTester tester) => tester
    .widget<Tooltip>(
      find.descendant(
        of: find.byType(StatusPill),
        matching: find.byType(Tooltip),
      ),
    )
    .message;

void main() {
  const seeded = [
    Invitation(id: 'i1', clientContactId: 'c1'),
    Invitation(id: 'i2', clientContactId: 'c2'),
  ];

  testWidgets('a draft whose invitations were never sent says so', (
    tester,
  ) async {
    await _pump(tester, invitations: seeded);

    expect(find.text('No emails have been sent'), findsOneWidget);
    // The rows the issue was filed about are gone, not just unlabelled.
    expect(find.text('Jane Doe'), findsNothing);
    expect(find.text('Bob Stone'), findsNothing);
  });

  testWidgets('no invitations at all gets the same copy', (tester) async {
    await _pump(tester, invitations: const []);

    expect(find.text('No emails have been sent'), findsOneWidget);
  });

  testWidgets('a dirty record cannot claim nothing was sent', (tester) async {
    // A local edit-save rewrites the Drift payload from `toApiJson`, which
    // drops every invitation's lifecycle — so the honest claim is that we
    // hold no record, not that nothing was sent.
    await _pump(tester, invitations: seeded, isDirty: true);

    expect(find.text('No records found'), findsOneWidget);
    expect(find.text('No emails have been sent'), findsNothing);
  });

  testWidgets('only the invitation with history renders', (tester) async {
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          sentDate: '2026-01-02 09:30:00',
        ),
        Invitation(id: 'i2', clientContactId: 'c2'),
      ],
    );

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Bob Stone'), findsNothing);
    expect(find.text('No emails have been sent'), findsNothing);
  });

  testWidgets('a failed send with no sent_date survives the filter', (
    tester,
  ) async {
    // email_error with no email_status is the one shape that still means a
    // failure: the MTA rejected it and no webhook ever spoke.
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          emailError: 'Connection refused',
          messageId: 'm1',
        ),
      ],
    );

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
    // The pill and its tooltip must agree — the tooltip used to be hardcoded
    // to "Email Bounced" whatever the label said.
    expect(find.widgetWithText(StatusPill, 'Error'), findsOneWidget);
    expect(_pillTooltip(tester), 'There was a problem sending the email');
    // No Reactivate: the action clears a Postmark suppression, and only a
    // bounce creates one. There is nothing on the far end to reactivate.
    expect(find.text('Reactivate Email'), findsNothing);
  });

  testWidgets('a bounce keeps its pill and its Reactivate', (tester) async {
    // The server-real shape: Postmark writes `email_error` from the payload's
    // `Details` for a Bounce too, so `hasError` is true here — the pill must
    // still resolve to `bounced`, not `errored`.
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          emailStatus: 'bounced',
          emailError: 'smtp;550 5.1.1 user unknown',
          messageId: 'm1',
        ),
      ],
    );

    expect(find.widgetWithText(StatusPill, 'Bounced'), findsOneWidget);
    expect(_pillTooltip(tester), 'Email Bounced');
    expect(find.text('smtp;550 5.1.1 user unknown'), findsOneWidget);
    expect(find.text('Reactivate Email'), findsOneWidget);
  });

  testWidgets('a spam complaint is visible, and offers no Reactivate', (
    tester,
  ) async {
    // A spam webhook writes email_status and NOTHING else, so before the pill
    // covered it this row rendered bare — #146 all over again. Postmark's own
    // payload says `CanActivate: false`, so the button must stay away.
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          emailStatus: 'spam',
          // Postmark's SpamComplaint payload carries `Details`, so a real spam
          // row has email_error set. Omit it and the no-Reactivate assertion
          // below passes for the wrong reason.
          emailError: 'The subscriber explicitly marked this message as spam.',
          messageId: 'm1',
        ),
      ],
    );

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.widgetWithText(StatusPill, 'Spam'), findsOneWidget);
    expect(_pillTooltip(tester), 'Spam Complaint');
    expect(find.text('Reactivate Email'), findsNothing);
  });

  testWidgets('a delivered row reads as a success, not a failure', (
    tester,
  ) async {
    // The steady state for every hosted Postmark account: `email_status` says
    // delivered and `email_error` holds the MTA's SUCCESS line, because the
    // webhook assigns it before branching on record type. Rank `errored`
    // first and this paints a red Error pill over "smtp;250 OK" with a
    // Reactivate button on mail that arrived.
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          sentDate: '2026-01-02 09:30:00',
          emailStatus: 'delivered',
          emailError: 'smtp;250 2.0.0 OK 1615496594 z6si',
          messageId: 'm1',
        ),
      ],
    );

    expect(find.widgetWithText(StatusPill, 'Delivered'), findsOneWidget);
    expect(_pillTooltip(tester), 'Email Delivered');
    expect(find.text('Error'), findsNothing);
    // The success line must not print in red beneath a green pill.
    expect(find.textContaining('smtp;250'), findsNothing);
    expect(find.text('Reactivate Email'), findsNothing);
  });

  testWidgets('the filter works on the vendor / purchase-order path', (
    tester,
  ) async {
    await _pump(
      tester,
      vendor: true,
      invitations: const [
        Invitation(
          id: 'i1',
          vendorContactId: 'vc1',
          sentDate: '2026-01-02 09:30:00',
        ),
        Invitation(id: 'i2', vendorContactId: 'vc-none'),
      ],
    );

    expect(find.text('Vera Ng'), findsOneWidget);
    expect(find.text('No emails have been sent'), findsNothing);
    // The dropped invitation would have rendered under the `contact` fallback,
    // its vendor contact id resolving to nothing.
    expect(find.text('Contact'), findsNothing);
  });

  testWidgets('a queued send replaces the denial', (tester) async {
    // The send rides the outbox and does not dirty the entity, so nothing
    // else on the screen shows it in flight. Offline that window is
    // unbounded.
    await _pump(
      tester,
      invitations: seeded,
      pending: [_outboxRow(MutationKind.emailEntity)],
    );

    expect(find.text('Email queued'), findsOneWidget);
    expect(find.text('Syncing…'), findsOneWidget);
    expect(find.text('No emails have been sent'), findsNothing);
  });

  testWidgets('a queued SCHEDULED send does not', (tester) async {
    // Scheduling creates a task_scheduler row; nothing is sent, and its
    // handler applies nothing when it drains — so the row would appear and
    // vanish. "No emails have been sent" is simply true here.
    await _pump(
      tester,
      invitations: seeded,
      pending: [_outboxRow(MutationKind.scheduleEmail)],
    );

    expect(find.text('Email queued'), findsNothing);
    expect(find.text('No emails have been sent'), findsOneWidget);
  });

  testWidgets('a queued send sits above the real history', (tester) async {
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          sentDate: '2026-01-02 09:30:00',
        ),
      ],
      pending: [_outboxRow(MutationKind.emailEntity)],
    );

    expect(find.text('Email queued'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Email queued')).dy,
      lessThan(tester.getTopLeft(find.text('Jane Doe')).dy),
    );
  });

  /// Bottom borders of the row shells, in tree order. The card's own
  /// `Border.all` is excluded by requiring a styleless top side — a row shell
  /// only ever sets `bottom`.
  List<BorderSide> rowBottomBorders(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.border)
      .whereType<Border>()
      .where((b) => b.top.style == BorderStyle.none)
      .map((b) => b.bottom)
      .toList();

  void expectOneBorderlessLastRow(WidgetTester tester, int rows) {
    final borders = rowBottomBorders(tester);
    expect(borders, hasLength(rows));
    // Exactly one hairline missing, and it is the final row's.
    expect(
      borders.where((b) => b.style == BorderStyle.none),
      hasLength(1),
      reason: 'expected exactly one borderless row',
    );
    expect(borders.last.style, BorderStyle.none);
  }

  testWidgets('the divider lands on the real final row in every combination', (
    tester,
  ) async {
    // `isLast` is counted against the queued row plus the surviving
    // invitations, not `invitations.length`. Getting it wrong doubles a
    // hairline or drops one — silent in review.
    const one = [
      Invitation(id: 'i1', clientContactId: 'c1', sentDate: '2026-01-02'),
    ];
    const two = [
      Invitation(id: 'i1', clientContactId: 'c1', sentDate: '2026-01-02'),
      Invitation(id: 'i2', clientContactId: 'c2', sentDate: '2026-01-03'),
    ];
    final queued = [_outboxRow(MutationKind.emailEntity)];

    await _pump(tester, invitations: one);
    expectOneBorderlessLastRow(tester, 1);

    await _pump(tester, invitations: two);
    expectOneBorderlessLastRow(tester, 2);

    await _pump(tester, invitations: const [], pending: queued);
    expectOneBorderlessLastRow(tester, 1);

    await _pump(tester, invitations: one, pending: queued);
    expectOneBorderlessLastRow(tester, 2);

    await _pump(tester, invitations: two, pending: queued);
    expectOneBorderlessLastRow(tester, 3);
  });

  testWidgets('Reactivate stays its own semantics node', (tester) async {
    // The row merges its text column so a screen reader announces one item;
    // a merge stretched over the whole Column would absorb the button's tap
    // action into that sentence — announced, unusable — on the only row that
    // has an action to take.
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          emailStatus: 'bounced',
          emailError: 'smtp;550 5.1.1 user unknown',
          messageId: 'm1',
        ),
      ],
    );

    final node = tester.getSemantics(find.text('Reactivate Email'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.label, isNot(contains('Jane Doe')));
    expect(node.label, isNot(contains('jane@example.com')));

    // …and the merged row node carries the pill's tooltip, which is how a
    // screen reader learns what the state means.
    final row = tester.getSemantics(find.text('Jane Doe'));
    expect(row.label, contains('jane@example.com'));
    expect(row.getSemanticsData().tooltip, contains('Email Bounced'));
    handle.dispose();
  });

  testWidgets('the pill is capped so a long label cannot blow the row', (
    tester,
  ) async {
    // A non-flex child after an `Expanded` is laid out unbounded, so
    // `StatusPill`'s own ellipsis never binds without the cap — and a bare
    // `Flexible` instead would pin the identity column to half the row.
    await _pump(
      tester,
      textScale: 2,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          sentDate: '2026-01-02 09:30:00',
          emailStatus: 'delivered',
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(StatusPill)).width,
      lessThanOrEqualTo(160),
    );
  });

  testWidgets('self-hosted hides Reactivate but keeps the bounce visible', (
    tester,
  ) async {
    await _pump(
      tester,
      isHosted: false,
      invitations: const [
        Invitation(
          id: 'i1',
          clientContactId: 'c1',
          emailStatus: 'bounced',
          emailError: 'smtp;550 5.1.1 user unknown',
          messageId: 'm1',
        ),
      ],
    );

    expect(find.widgetWithText(StatusPill, 'Bounced'), findsOneWidget);
    expect(find.text('Reactivate Email'), findsNothing);
  });
}
