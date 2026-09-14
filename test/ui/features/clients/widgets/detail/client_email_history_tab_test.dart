import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/api/email_history_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/emails_api.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;
import 'package:admin/ui/features/clients/widgets/detail/client_email_history_tab.dart';

import '../../../../../_localization_helper.dart';

/// The client Email-History tab's empty state.
///
/// This feed is the server's `SystemLog` mail log, which only a
/// webhook-capable ESP populates — so an empty result means either "no mail
/// yet" or "this sender reports nothing", and the tab cannot tell which.
///
/// It briefly branched on `isHosted`, asserting "No emails have been sent" for
/// hosted accounts on the premise that hosted is always Postmark. It is not:
/// `Email::MAIL_DRIVER_MAP` offers gmail / office365 / microsoft and the
/// `client_*` methods, and hosted free/trial routes to Mailgun — so a hosted
/// account sending through Gmail gets no webhook, an always-empty feed, and
/// would have been told its mail was never sent. These tests pin the neutral
/// copy on **both** account kinds.

class _FakeEmailsApi implements EmailsApi {
  _FakeEmailsApi([this.records = const []]);

  final List<EmailHistoryRecordApi> records;

  @override
  Future<List<EmailHistoryRecordApi>> clientHistory({
    required String clientId,
  }) async => records;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeOutboxDao implements OutboxDao {
  const _FakeOutboxDao();

  @override
  Stream<List<OutboxRow>> watchPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    MutationKind? kind,
  }) => Stream<List<OutboxRow>>.multi((c) {
    c.add(const <OutboxRow>[]);
    c.close();
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeDb implements AppDatabase {
  @override
  final OutboxDao outboxDao = const _FakeOutboxDao();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);

  final ValueListenable<AuthSession?> _session;

  @override
  ValueListenable<AuthSession?> get session => _session;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.emails});

  @override
  final AuthRepository auth;

  @override
  final EmailsApi emails;

  @override
  final AppDatabase db = _FakeDb();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<void> _pump(
  WidgetTester tester, {
  required bool isHosted,
  List<EmailHistoryRecordApi> records = const [],
}) async {
  final session = ValueNotifier<AuthSession?>(
    AuthSession(
      baseUrl: '',
      isHosted: isHosted,
      accountId: '',
      companies: const [],
      currentCompanyId: 'co-A',
    ),
  );
  addTearDown(session.dispose);
  final services = _FakeServices(
    auth: _FakeAuth(session),
    emails: _FakeEmailsApi(records),
  );
  await tester.pumpWidget(
    Provider<Services>.value(
      value: services,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClientEmailHistoryTab(
              key: UniqueKey(),
              client: emptyClient().copyWith(id: 'cl1'),
              formatter: null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('an empty feed makes no claim about sending, on hosted', (
    tester,
  ) async {
    await _pump(tester, isHosted: true);

    expect(find.text('No records found'), findsOneWidget);
    expect(find.textContaining('Postmark/Mailgun'), findsOneWidget);
    // A hosted account can be sending through Gmail or Office365, which
    // report nothing back — so this claim must not appear.
    expect(find.text('No emails have been sent'), findsNothing);
  });

  testWidgets('and the same on self-hosted', (tester) async {
    await _pump(tester, isHosted: false);

    expect(find.text('No records found'), findsOneWidget);
    expect(find.textContaining('Postmark/Mailgun'), findsOneWidget);
    expect(find.text('No emails have been sent'), findsNothing);
  });

  testWidgets('a real record renders instead of the empty state', (
    tester,
  ) async {
    await _pump(
      tester,
      isHosted: true,
      records: const [
        EmailHistoryRecordApi(
          entity: 'invoice',
          entityId: 'inv1',
          subject: 'Invoice 0012',
          recipients: 'jane@example.com',
          events: [
            EmailHistoryEventApi(
              date: '2026-01-02 09:30:00',
              status: 'Delivered',
              recipient: 'jane@example.com',
            ),
          ],
        ),
      ],
    );

    expect(find.text('Invoice 0012'), findsOneWidget);
    expect(find.text('No records found'), findsNothing);
    // House separator: single-spaced middot, not the double-spaced bullet
    // these two email tabs were the only holdouts for.
    expect(find.textContaining('Delivered · jane@example.com'), findsOneWidget);
  });
}
