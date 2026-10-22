import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/portal_constants.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/client_portal_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/client_portal_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/registration_screen.dart';

import '../../../../../../_localization_helper.dart';

/// The portal URL's QR code is what gets printed, so it is offered only for
/// the address the server holds. A hosted user who typed a subdomain that is
/// already taken used to get a code for `https://<taken>.invoicing.co` — the
/// save then 422'd, and the printed code led to another company's portal.

/// `watchCompany` is a controller the test pushes into; a save only moves
/// the view model's baseline.
class _FakeCompanyRepo implements CompanyRepository {
  final controller = StreamController<Company?>.broadcast();
  @override
  Stream<Company?> watchCompany(String companyId) => controller.stream;
  @override
  Future<void> refresh(String companyId) async {}
  @override
  Future<void> updateCompany({
    required Company draft,
    Map<String, dynamic>? extraOutboxPayload,
  }) async {}
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// The outbox answer, pushed by hand: a real Drift watch stream never
/// settles under the widget-test clock. The query itself is covered by
/// `outbox_unaccepted_record_edit_test.dart`.
class _FakeOutboxDao implements OutboxDao {
  final unaccepted = StreamController<bool>.broadcast();
  @override
  Stream<bool> watchHasUnacceptedRecordEdit({
    required String companyId,
    required String entityType,
    required String entityId,
  }) {
    expect(entityType, kCompanyWireName);
    expect(entityId, companyId);
    return unaccepted.stream;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeDb implements AppDatabase {
  _FakeDb(this.outboxDao);
  @override
  final OutboxDao outboxDao;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.db});
  @override
  final AuthRepository auth;
  @override
  final AppDatabase db;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _companyId = 'co';

const _saved = Company(
  id: _companyId,
  companyKey: 'KEY123',
  portalMode: kClientPortalModeSubdomain,
  subdomain: 'mine',
  clientCanRegister: true,
);

void main() {
  late _FakeCompanyRepo repo;
  late _FakeOutboxDao outbox;
  late ClientPortalViewModel vm;

  setUp(() {
    repo = _FakeCompanyRepo();
    outbox = _FakeOutboxDao();
    vm = ClientPortalViewModel(repo: repo, companyId: _companyId);
  });
  tearDown(() async {
    vm.dispose();
    await repo.controller.close();
    await outbox.unaccepted.close();
  });

  /// Pumps [screen] over the saved company; the outbox then says whether the
  /// company has a change the server has not accepted (null: not yet).
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    bool? unaccepted = false,
  }) async {
    // The form is a lazy ListView: make room for every section.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = _FakeServices(
      auth: _FakeAuth(
        ValueNotifier(
          const AuthSession(
            baseUrl: 'https://invoicing.co',
            isHosted: true,
            accountId: 'acct',
            companies: [],
            currentCompanyId: _companyId,
            plan: 'enterprise',
          ),
        ),
      ),
      db: _FakeDb(outbox),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MultiProvider(
          providers: [
            Provider<Services>.value(value: services),
            ChangeNotifierProvider<SettingsLevelController>.value(
              value: SettingsLevelController(),
            ),
            ChangeNotifierProvider<SettingsDraftHost>.value(value: vm),
          ],
          child: Scaffold(body: screen),
        ),
      ),
    );
    await vm.load();
    repo.controller.add(_saved);
    await tester.pump();
    if (unaccepted != null) {
      outbox.unaccepted.add(unaccepted);
      await tester.pump();
    }
  }

  final qrButton = find.byIcon(Icons.qr_code);
  final afterSync = find.text(
    'The QR code appears once your changes are saved and synced.',
  );

  testWidgets('the saved, synced address offers its QR code', (tester) async {
    await pumpScreen(tester, const ClientPortalScreen());

    expect(find.text('https://mine.invoicing.co/client/login'), findsOneWidget);
    expect(qrButton, findsOneWidget);
    expect(afterSync, findsNothing);
  });

  testWidgets('a typed, unsaved subdomain previews its URL with no QR code', (
    tester,
  ) async {
    await pumpScreen(tester, const ClientPortalScreen());

    await tester.enterText(find.widgetWithText(TextField, 'mine'), 'acme');
    // Let the subdomain field's availability probe run (it fails quietly on
    // the fake services) so no timer outlives the test.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('https://acme.invoicing.co/client/login'), findsOneWidget);
    expect(qrButton, findsNothing);
    expect(afterSync, findsOneWidget);
  });

  testWidgets('a saved address waits for the server to accept it', (
    tester,
  ) async {
    // Saved locally, still in the outbox — or dead after a 422, which leaves
    // the rejected value in the local row just the same.
    await pumpScreen(tester, const ClientPortalScreen(), unaccepted: true);

    expect(qrButton, findsNothing);
    expect(afterSync, findsOneWidget);

    // Delivered: the row leaves the outbox.
    outbox.unaccepted.add(false);
    await tester.pump();

    expect(qrButton, findsOneWidget);
    expect(afterSync, findsNothing);
  });

  testWidgets('before the outbox answers, no QR code and no notice', (
    tester,
  ) async {
    await pumpScreen(tester, const ClientPortalScreen(), unaccepted: null);

    expect(find.text('https://mine.invoicing.co/client/login'), findsOneWidget);
    expect(qrButton, findsNothing);
    expect(afterSync, findsNothing);
  });

  testWidgets('registration switched on but not saved: no QR code', (
    tester,
  ) async {
    await pumpScreen(tester, const ClientPortalRegistrationScreen());
    expect(
      find.text('https://mine.invoicing.co/client/register'),
      findsOneWidget,
    );
    expect(qrButton, findsOneWidget);

    // Saved off, then switched back on without saving: the server would
    // answer the address with "Registration disabled".
    vm.updateCompany((c) => c.copyWith(clientCanRegister: false));
    await vm.save();
    vm.updateCompany((c) => c.copyWith(clientCanRegister: true));
    await tester.pump();

    expect(
      find.text('https://mine.invoicing.co/client/register'),
      findsOneWidget,
    );
    expect(qrButton, findsNothing);
    expect(afterSync, findsOneWidget);
  });
}
