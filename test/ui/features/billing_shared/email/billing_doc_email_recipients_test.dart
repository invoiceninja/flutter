import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_screen.dart';
import 'package:admin/ui/features/billing_shared/email/recipient_email_fix.dart';
import 'package:admin/ui/features/billing_shared/email/recipient_email_state.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;

import '../../../../_localization_helper.dart';

/// The recipient half of the Send Email screen: who it is addressed to, who is
/// copied, and what happens when nobody has an address (invoiceninja/ui
/// #3400, #3280, #3285).

Contact _contact(
  String id, {
  String first = '',
  String email = '',
  bool primary = false,
  bool ccOnly = false,
  bool locked = false,
}) => Contact(
  id: id,
  firstName: first,
  lastName: '',
  email: email,
  phone: '',
  isPrimary: primary,
  sendEmail: !ccOnly,
  ccOnly: ccOnly,
  isLocked: locked,
  updatedAt: DateTime.utc(2026, 1, 1, 12),
  isDeleted: false,
);

class _FakeTemplatesApi implements TemplatesApi {
  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async => TemplatePreview(
    subject: subject,
    body: body,
    wrapper: '',
    rawSubject: subject,
    rawBody: body,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeClients implements ClientRepository {
  _FakeClients(this.client, {this.byId = const {}});

  final Client? client;

  /// Per-id clients, for the bulk preflight; falls back to [client].
  final Map<String, Client> byId;

  @override
  Future<EnsureLoadedOutcome> ensureLoaded({
    required String companyId,
    required String id,
  }) async => EnsureLoadedOutcome.cached;

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream.value(byId[id] ?? client);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeServices implements Services {
  _FakeServices(this.clients);

  @override
  final TemplatesApi templates = _FakeTemplatesApi();

  @override
  final ClientRepository clients;

  @override
  final ToastController toasts = ToastController();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<List<String?>> _pump(
  WidgetTester tester, {
  required Client? client,
  List<Invitation> invitations = const [
    Invitation(id: 'i1', clientContactId: 'c1'),
  ],
  bool canCcEmail = true,
  bool canCustomizeEmail = true,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final services = _FakeServices(_FakeClients(client));
  addTearDown(services.toasts.dispose);
  final sentCc = <String?>[];

  await tester.pumpWidget(
    ChangeNotifierProvider<ToastController>.value(
      value: services.toasts,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: BillingDocEmailScreen(
          services: services,
          companyId: 'co',
          type: BillingDocType.invoice,
          entityId: 'inv1',
          entityNumber: '0012',
          invitations: invitations,
          isDirty: false,
          clientId: 'cl1',
          vendorId: '',
          isHosted: true,
          canCcEmail: canCcEmail,
          canCustomizeEmail: canCustomizeEmail,
          formatter: null,
          onSend: ({required template, subject, body, ccEmail}) async {
            sentCc.add(ccEmail);
          },
          onReactivate: (_) async => 0,
          pdfFetcher: ({designId, required deliveryNote}) async => Uint8List(0),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sentCc;
}

Client _client(List<Contact> contacts) =>
    emptyClient().copyWith(id: 'cl1', contacts: contacts);

void main() {
  group('recipientEmailState', () {
    final contacts = emailContactsOfClient(
      _client([
        _contact('c1', email: ''),
        _contact('c2', email: 'b@acme.test'),
      ]),
    );

    test('reads the INVITED contacts, not every contact', () {
      // c2 has an address but isn't invited to this document — the server
      // mails invitations, so nobody would receive it.
      expect(
        recipientEmailState(
          invitations: const [Invitation(id: 'i1', clientContactId: 'c1')],
          contacts: contacts,
        ),
        RecipientEmailState.none,
      );
      expect(
        recipientEmailState(
          invitations: const [Invitation(id: 'i2', clientContactId: 'c2')],
          contacts: contacts,
        ),
        RecipientEmailState.has,
      );
    });

    test('a blank-but-spaced address is no address', () {
      final spaced = emailContactsOfClient(
        _client([_contact('c1', email: '   ')]),
      );
      expect(
        recipientEmailState(
          invitations: const [Invitation(id: 'i1', clientContactId: 'c1')],
          contacts: spaced,
        ),
        RecipientEmailState.none,
      );
    });

    test('a client that is not cached is unknown, never "none"', () {
      expect(
        recipientEmailState(
          invitations: const [Invitation(id: 'i1', clientContactId: 'c1')],
          contacts: null,
        ),
        RecipientEmailState.unknown,
      );
    });

    test('Add email targets the invited primary contact first', () {
      final all = emailContactsOfClient(
        _client([_contact('c1'), _contact('c2', primary: true)]),
      )!;
      final target = contactToAddEmailTo(const [
        Invitation(id: 'i1', clientContactId: 'c1'),
        Invitation(id: 'i2', clientContactId: 'c2'),
      ], all);
      expect(target?.id, 'c2');
    });

    test('CC-only contacts: with an address, not locked, at most four', () {
      final all = emailContactsOfClient(
        _client([
          for (var i = 0; i < 6; i++)
            _contact('cc$i', email: 'cc$i@acme.test', ccOnly: true),
          _contact('blank', ccOnly: true),
          _contact('locked', email: 'x@acme.test', ccOnly: true, locked: true),
        ]),
      )!;
      final cc = ccOnlyContacts(all);
      expect(cc.map((c) => c.id), ['cc0', 'cc1', 'cc2', 'cc3']);
    });
  });

  group('the Send Email screen', () {
    testWidgets('no address on the invited contact: banner, Send disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        client: _client([_contact('c1', first: 'Jane', primary: true)]),
      );

      expect(find.byKey(const Key('no_email_banner')), findsOneWidget);
      expect(
        find.text('Client does not have an email address set'),
        findsOneWidget,
      );
      expect(find.text('Add Email'), findsOneWidget);
      expect(find.text('Edit Client'), findsOneWidget);
    });

    testWidgets('a client missing from the cache never blocks the send', (
      tester,
    ) async {
      await _pump(tester, client: null);

      expect(find.byKey(const Key('no_email_banner')), findsNothing);
    });

    testWidgets('CC-only contacts get their own line, not "To"', (
      tester,
    ) async {
      await _pump(
        tester,
        client: _client([
          _contact('c1', first: 'Jane', email: 'jane@acme.test', primary: true),
          _contact('c2', first: 'Bob', email: 'bob@acme.test', ccOnly: true),
        ]),
      );

      expect(find.text('Jane • jane@acme.test'), findsOneWidget);
      expect(find.text('Bob • bob@acme.test'), findsOneWidget);
      expect(find.text('CC'), findsOneWidget);
    });

    testWidgets('CC is disabled, with the reason, when the server drops it', (
      tester,
    ) async {
      await _pump(
        tester,
        client: _client([
          _contact('c1', email: 'jane@acme.test', primary: true),
        ]),
        canCcEmail: false,
        canCustomizeEmail: false,
      );

      final cc = tester.widget<TextField>(
        find.widgetWithText(TextField, 'name@example.com'),
      );
      expect(cc.enabled, isFalse);
      expect(
        find.text('CC is available on paid plans after the first month.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('this email will use the saved template'),
        findsOneWidget,
      );
    });
  });

  // A bulk send drops the documents whose client has no address — and says
  // which — rather than composing an email for all of them and letting some
  // go nowhere. Skip-and-continue, not stop-at-first.
  testWidgets('bulk preflight drops and names the unsendable documents', (
    tester,
  ) async {
    final services = _FakeServices(
      _FakeClients(
        null,
        byId: {
          'ok': emptyClient().copyWith(
            id: 'ok',
            contacts: [_contact('a', email: 'a@acme.test', primary: true)],
          ),
          'none': emptyClient().copyWith(
            id: 'none',
            contacts: [_contact('b', primary: true)],
          ),
        },
      ),
    );
    addTearDown(services.toasts.dispose);
    const docs = <({String client, String number, String contact})>[
      (client: 'ok', number: '0001', contact: 'a'),
      (client: 'none', number: '0002', contact: 'b'),
    ];

    List<Object?>? kept;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              kept =
                  await preflightRecipientEmails<
                    ({String client, String number, String contact})
                  >(
                    context,
                    services,
                    companyId: 'co',
                    eligible: docs,
                    clientIdOf: (d) => d.client,
                    invitationsOf: (d) => [
                      Invitation(id: 'i', clientContactId: d.contact),
                    ],
                    numberOf: (d) => d.number,
                  );
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('• #0002'), findsOneWidget);
    expect(find.text('• #0001'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(kept, [docs.first]);
  });
}
