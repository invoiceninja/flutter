import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/hide_peppol_status_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/domain/billing/peppol_sending_status.dart';
import 'package:admin/ui/features/billing_shared/peppol_status_icon.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';

import '../../../_localization_helper.dart';

PeppolSendingStatus? _status({
  bool peppol = true,
  String? country = '56',
  String classification = '',
  String guid = '',
  bool draft = false,
  bool deleted = false,
  bool archived = false,
}) => peppolSendingStatus(
  companyUsesPeppol: peppol,
  clientCountryId: country,
  clientClassification: classification,
  guid: guid,
  isDraft: draft,
  isDeleted: deleted,
  isArchived: archived,
);

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeClients implements ClientRepository {
  _FakeClients(this.byId);
  final Map<String, Client> byId;
  final List<String> ensured = [];

  @override
  Client? peek({required String companyId, required String id}) => byId[id];
  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream<Client?>.value(byId[id]);
  @override
  Future<EnsureLoadedOutcome> ensureLoaded({
    required String companyId,
    required String id,
  }) async {
    ensured.add(id);
    return EnsureLoadedOutcome.cached;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({
    required this.auth,
    required this.clients,
    required this.hidePeppolStatus,
  });
  @override
  final AuthRepository auth;
  @override
  final ClientRepository clients;
  @override
  final HidePeppolStatusController hidePeppolStatus;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('peppolSendingStatus', () {
    test('a delivered document is sent, whatever its state now', () {
      expect(_status(guid: 'abc'), PeppolSendingStatus.sent);
      expect(_status(guid: 'abc', draft: true), PeppolSendingStatus.sent);
      expect(_status(guid: 'abc', archived: true), PeppolSendingStatus.sent);
    });

    test('a live, undelivered document has failed', () {
      expect(_status(), PeppolSendingStatus.failed);
    });

    test('a draft, deleted or archived undelivered document shows nothing', () {
      expect(_status(draft: true), isNull);
      expect(_status(deleted: true), isNull);
      expect(_status(archived: true), isNull);
    });

    test('nothing unless the company sends by PEPPOL', () {
      expect(_status(peppol: false, guid: 'abc'), isNull);
      expect(_status(peppol: false), isNull);
    });

    test('nothing while the client is unknown', () {
      expect(_status(country: null), isNull);
    });

    test('nothing for a client outside the network', () {
      expect(_status(country: '840'), isNull); // United States
      expect(_status(country: ''), isNull);
    });

    test('a client with no classification counts as a business', () {
      expect(_status(country: '826'), PeppolSendingStatus.failed);
    });

    test('the classification must be one the country accepts', () {
      expect(_status(classification: 'government'), PeppolSendingStatus.failed);
      expect(_status(classification: 'individual'), isNull);
      // The UK takes businesses only.
      expect(_status(country: '826', classification: 'government'), isNull);
    });

    test('the network countries are kPeppolCountries, exactly', () {
      expect(
        kPeppolClientClassifications.keys.toSet(),
        kPeppolCountries.toSet(),
      );
    });

    test('peppolGuidOf reads backup.guid, or empty', () {
      expect(peppolGuidOf(null), '');
      expect(peppolGuidOf(const {}), '');
      expect(peppolGuidOf(const {'guid': 'abc'}), 'abc');
      expect(peppolGuidOf(const {'guid': 7}), '');
    });
  });

  group('PeppolStatusIcon', () {
    late HidePeppolStatusController hide;
    late _FakeClients clients;

    setUp(() {
      hide = HidePeppolStatusController(prefs: DevicePrefsStore(null));
      clients = _FakeClients({
        'be': Client.fromApi(
          const ClientApi(id: 'be', name: 'Brussels BV', countryId: '56'),
        ),
        'us': Client.fromApi(
          const ClientApi(id: 'us', name: 'Austin LLC', countryId: '840'),
        ),
      });
    });
    tearDown(() => hide.dispose());

    Future<void> pump(
      WidgetTester tester, {
      required bool peppol,
      String clientId = 'be',
      Map<String, dynamic>? backup,
      bool draft = false,
    }) async {
      final session = ValueNotifier<AuthSession?>(
        const AuthSession(
          baseUrl: '',
          isHosted: true,
          accountId: '',
          companies: [],
          currentCompanyId: 'co',
        ),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(
            auth: _FakeAuth(session),
            clients: clients,
            hidePeppolStatus: hide,
          ),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: PeppolStatusScope(
                companyUsesPeppol: peppol,
                child: PeppolStatusIcon(
                  clientId: clientId,
                  backup: backup,
                  isDraft: draft,
                  isDeleted: false,
                  isArchived: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a delivered invoice shows the sent mark', (tester) async {
      await pump(tester, peppol: true, backup: const {'guid': 'abc'});
      expect(find.bySemanticsLabel('E-Invoice sent successfully!'), findsOne);
      expect(find.byIcon(Icons.send), findsOne);
    });

    testWidgets('an undelivered one shows the failed mark', (tester) async {
      await pump(tester, peppol: true, backup: const {'guid': ''});
      expect(find.bySemanticsLabel('E-Invoice sending failed!'), findsOne);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOne);
    });

    testWidgets('nothing, and no client fetch, without PEPPOL', (tester) async {
      await pump(tester, peppol: false);
      expect(find.byType(PeppolStatusMark), findsNothing);
      expect(clients.ensured, isEmpty);
    });

    testWidgets('a PEPPOL list hydrates the row client', (tester) async {
      await pump(tester, peppol: true);
      expect(clients.ensured, ['be']);
    });

    testWidgets('nothing for a client outside the network', (tester) async {
      await pump(tester, peppol: true, clientId: 'us');
      expect(find.byType(PeppolStatusMark), findsNothing);
    });

    testWidgets('nothing for a draft', (tester) async {
      await pump(tester, peppol: true, draft: true);
      expect(find.byType(PeppolStatusMark), findsNothing);
    });

    testWidgets('the Device Settings switch hides it', (tester) async {
      await pump(tester, peppol: true);
      expect(find.byType(PeppolStatusMark), findsOne);

      await hide.set(true);
      await tester.pump();
      expect(find.byType(PeppolStatusMark), findsNothing);
    });
  });
}
