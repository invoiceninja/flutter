import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_client_picker.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

import '../../../_localization_helper.dart';

class _Doc {
  const _Doc({this.clientId = '', this.invitations = const []});
  final String clientId;
  final List<Invitation> invitations;
}

class _Vm extends GenericBillingDocEditViewModel<_Doc> {
  _Vm() : super(initialDraft: const _Doc());

  @override
  List<LineItem> lineItemsOf(_Doc d) => const [];
  @override
  _Doc copyWithLineItems(_Doc d, List<LineItem> items) => d;
  @override
  List<Invitation> invitationsOf(_Doc d) => d.invitations;
  @override
  _Doc copyWithInvitations(_Doc d, List<Invitation> inv) =>
      _Doc(clientId: d.clientId, invitations: inv);
  @override
  String clientIdOf(_Doc d) => d.clientId;
  @override
  _Doc copyWithClientId(_Doc d, String clientId) =>
      _Doc(clientId: clientId, invitations: d.invitations);
  @override
  Map<String, dynamic>? eInvoiceOf(_Doc d) => null;
  @override
  _Doc copyWithEInvoice(_Doc d, Map<String, dynamic>? e) => d;
  @override
  _Doc copyWithStampedTotals(
    _Doc d, {
    required Decimal amount,
    required Decimal taxAmount,
  }) => d;
  @override
  BillingTotalsInput totalsInputOf(_Doc d) => BillingTotalsInput(
    lineItems: const [],
    discount: Decimal.zero,
    isAmountDiscount: false,
    usesInclusiveTaxes: false,
  );
  @override
  Future<SaveResult<_Doc>> performSave() async =>
      SaveResult(entity: draft, outboxRowId: 1);
}

/// `watch(id:)` is driven by a controller so a test can land the server's
/// contact ids after the create, exactly as the sync drain would.
class _FakeClientRepo implements ClientRepository {
  final _watched = StreamController<Client?>.broadcast();

  void emitWatched(Client? c) => _watched.add(c);

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      _watched.stream;

  @override
  Stream<List<Client>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<Object?> states = const {},
    String sortField = '',
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
    String? badgeModeId,
  }) => Stream<List<Client>>.value(const []);

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<Object?> states = const {},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({required this.clients, required this.auth});
  @override
  final ClientRepository clients;
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Client _client(String id, {List<Contact> contacts = const []}) => Client(
  id: id,
  name: 'Acme',
  displayName: 'Acme',
  number: '',
  idNumber: '',
  vatNumber: '',
  website: '',
  phone: '',
  address1: '',
  address2: '',
  city: '',
  state: '',
  postalCode: '',
  countryId: '',
  balance: Decimal.zero,
  paidToDate: Decimal.zero,
  creditBalance: Decimal.zero,
  currencyId: '',
  languageId: '',
  paymentTerms: '',
  privateNotes: '',
  publicNotes: '',
  groupSettingsId: '',
  assignedUserId: '',
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  contacts: contacts,
);

Contact _contact(String id) => Contact(
  id: id,
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  phone: '',
  isPrimary: true,
  sendEmail: true,
  isDeleted: false,
  updatedAt: DateTime.utc(2026),
);

void main() {
  // A client created inline has contacts with no server ids yet, so
  // `selectClient` deliberately seeds no invitations (a blank
  // `client_contact_id` 422s the document save). Once the create syncs and the
  // real ids land, the invitations must be seeded — otherwise the Contacts tab
  // stays conspicuously empty compared with every other client.
  testWidgets('seeds invitations once the created client\'s contacts sync', (
    tester,
  ) async {
    final repo = _FakeClientRepo();
    final vm = _Vm();
    // A freshly created client: one contact, no server id yet.
    final created = _client('tmp_1', contacts: [_contact('')]);
    final services = _FakeServices(
      clients: repo,
      auth: _FakeAuth(
        ValueNotifier<AuthSession?>(
          const AuthSession(
            baseUrl: '',
            isHosted: false,
            accountId: '',
            currentCompanyId: 'co',
            companies: [
              AuthCompany(
                id: 'co',
                name: 'Co',
                displayName: 'Co',
                permissions: '',
                isAdmin: true,
                isOwner: false,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: BillingDocClientPicker<_Doc>(
              vm: vm,
              companyId: 'co',
              createClient: (_, _) async => created,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drive the real create path: focus the field, type a novel name, and
    // pick the "Create" row.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Acme');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Create'));
    await tester.pumpAndSettle();

    expect(vm.draft.clientId, 'tmp_1');
    expect(
      vm.draft.invitations,
      isEmpty,
      reason: 'contact has no server id yet, so no invitation may be shipped',
    );

    // The create drains and the server assigns the contact its id. The commit
    // above must NOT have cancelled the watch that is waiting for this.
    repo.emitWatched(_client('tmp_1', contacts: [_contact('ct-1')]));
    await tester.pumpAndSettle();

    expect(vm.draft.invitations.map((i) => i.clientContactId), ['ct-1']);
  });

  testWidgets('picking a different client abandons the pending re-seed', (
    tester,
  ) async {
    final repo = _FakeClientRepo();
    final vm = _Vm();
    final created = _client('tmp_1', contacts: [_contact('')]);
    final services = _FakeServices(
      clients: repo,
      auth: _FakeAuth(
        ValueNotifier<AuthSession?>(
          const AuthSession(
            baseUrl: '',
            isHosted: false,
            accountId: '',
            currentCompanyId: 'co',
            companies: [
              AuthCompany(
                id: 'co',
                name: 'Co',
                displayName: 'Co',
                permissions: '',
                isAdmin: true,
                isOwner: false,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: BillingDocClientPicker<_Doc>(
              vm: vm,
              companyId: 'co',
              createClient: (_, _) async => created,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Acme');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Create'));
    await tester.pumpAndSettle();

    // User changes their mind and picks someone else entirely.
    vm.selectClient('other', [_contact('ct-9')]);
    await tester.pumpAndSettle();

    repo.emitWatched(_client('tmp_1', contacts: [_contact('ct-1')]));
    await tester.pumpAndSettle();

    // The late arrival must not clobber the current selection.
    expect(vm.draft.clientId, 'other');
    expect(vm.draft.invitations.map((i) => i.clientContactId), ['ct-9']);
  });
}
