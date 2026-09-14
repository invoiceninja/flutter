import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/ui/core/widgets/locked_entity_field_row.dart';

import '../../../_localization_helper.dart';

/// `LockedEntityFieldRow` is what a field the SERVER refuses to change looks
/// like — the invoice / quote / credit / recurring client, the purchase-order
/// vendor, the payment client, the project client (invoiceninja/flutter#158).
///
/// Three of the assertions below are the reason the widget exists at all rather
/// than a fourth hand-rolled `StreamBuilder` + `Text(name ?? id)`: it must never
/// print the raw hashid, the helper line must survive, and the row has to be a
/// real tap target on touch.
class _FakeClientRepo implements ClientRepository {
  _FakeClientRepo({this.client});

  final Client? client;
  final ensureLoadedCalls = <String>[];

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream<Client?>.value(client);

  @override
  Client? peek({required String companyId, required String id}) => null;

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async => ensureLoadedCalls.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeVendorRepo implements VendorRepository {
  _FakeVendorRepo({this.vendor});

  final Vendor? vendor;

  @override
  Stream<Vendor?> watch({required String companyId, required String id}) =>
      Stream<Vendor?>.value(vendor);

  @override
  Vendor? peek({required String companyId, required String id}) => null;

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {}

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
  _FakeServices({
    required this.clients,
    required this.auth,
    VendorRepository? vendors,
  }) : vendors = vendors ?? _FakeVendorRepo();
  @override
  final ClientRepository clients;
  @override
  final VendorRepository vendors;
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AuthSession _session({required bool canViewClient}) => AuthSession(
  baseUrl: '',
  isHosted: false,
  accountId: '',
  currentCompanyId: 'co',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      // A plain user with no permissions at all cannot view a client; the
      // admin bypass inside `AuthCompany.can` covers the other case.
      permissions: '',
      isAdmin: canViewClient,
      isOwner: false,
    ),
  ],
);

Vendor _vendor(String id, {String name = 'Northwind Supply'}) => Vendor(
  id: id,
  name: name,
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
  currencyId: '',
  privateNotes: '',
  publicNotes: '',
  userId: '',
  assignedUserId: '',
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  contacts: const [],
);

Client _client(String id, {String displayName = 'Acme'}) => Client(
  id: id,
  name: displayName,
  displayName: displayName,
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
  contacts: const [],
);

Future<void> _pump(
  WidgetTester tester, {
  required Services services,
  required Widget child,
}) async {
  await tester.pumpWidget(
    Provider<Services>.value(
      value: services,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  _FakeServices servicesWith(
    _FakeClientRepo repo, {
    bool canViewClient = true,
    VendorRepository? vendors,
  }) => _FakeServices(
    clients: repo,
    vendors: vendors,
    auth: _FakeAuth(
      ValueNotifier<AuthSession?>(_session(canViewClient: canViewClient)),
    ),
  );

  testWidgets('renders the label, the resolved name and the lock', (
    tester,
  ) async {
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(clientId: 'c1'),
    );

    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    // Nothing editable: the whole point is that this is not a disabled picker.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows the helper line when supplied, and nothing when not', (
    tester,
  ) async {
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(
        clientId: 'c1',
        helperText: 'why it is locked',
      ),
    );
    expect(find.text('why it is locked'), findsOneWidget);

    await _pump(
      tester,
      services: servicesWith(_FakeClientRepo(client: _client('c1'))),
      child: const LockedClientFieldRow(clientId: 'c1'),
    );
    expect(find.text('why it is locked'), findsNothing);
  });

  // Material renders `errorText` INSTEAD of `helperText`, never both. That is
  // the right precedence — a live rejection outranks a standing explanation —
  // so it is asserted rather than left to be "fixed" later.
  testWidgets('an error supplants the helper line', (tester) async {
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(
        clientId: 'c1',
        helperText: 'why it is locked',
        errorText: 'The selected client id is invalid',
      ),
    );

    expect(find.text('The selected client id is invalid'), findsOneWidget);
    expect(find.text('why it is locked'), findsNothing);
  });

  // The reason this widget exists rather than a fourth copy of the
  // `StreamBuilder<Client?>` + `Text(c == null ? clientId : …)` shape the
  // project and task forms used to carry: a hashid is meaningless to the user
  // in every state, and those copies never called `ensureLoaded`, so for a
  // client outside the locally-paged window it was permanent, not a flash.
  testWidgets('an unresolved client renders an em dash, never the raw id', (
    tester,
  ) async {
    final repo = _FakeClientRepo(); // resolves to null
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(clientId: 'Wpmbk5ezJn'),
    );

    expect(find.text('Wpmbk5ezJn'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    // …and it asked for the missing row rather than giving up on it.
    expect(repo.ensureLoadedCalls, ['Wpmbk5ezJn']);
  });

  testWidgets('the row is only tappable when the user can view the record', (
    tester,
  ) async {
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(clientId: 'c1'),
    );
    expect(find.byType(InkWell), findsOneWidget);

    await _pump(
      tester,
      services: servicesWith(
        _FakeClientRepo(client: _client('c1')),
        canViewClient: false,
      ),
      child: const LockedClientFieldRow(clientId: 'c1'),
    );
    expect(
      find.byType(InkWell),
      findsNothing,
      reason: 'no view_client permission means no destination',
    );
  });

  // The task form's project-derived client is a lock with no destination: the
  // user unlocks it by clearing the Project, and the branch sits outside
  // `_Lockable`, so a live tap target there would be new behaviour.
  testWidgets('tappable: false leaves the row inert even with permission', (
    tester,
  ) async {
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(clientId: 'c1', tappable: false),
    );

    expect(find.byType(InkWell), findsNothing);
  });

  // `docs/touch-targets.md`: gated on the platform, not the viewport. The
  // decorated field already clears 44 in every configuration measured — this
  // makes it invariant rather than incidental.
  testWidgets('the tap target clears the touch floor on a touch platform', (
    tester,
  ) async {
    // Reset inside the body, not via addTearDown: the foundation-vars
    // invariant check runs before teardowns, so a lingering override fails.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final repo = _FakeClientRepo(client: _client('c1'));
      await _pump(
        tester,
        services: servicesWith(repo),
        child: const LockedClientFieldRow(
          clientId: 'c1',
          helperText: 'why it is locked',
        ),
      );

      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // The explanation must not be a tap target. `InputDecoration.helperText`
  // lays out INSIDE the decorator, so routing the reason through it put "why
  // can't I edit this?" inside the row's hit area — tapping the sentence left
  // the edit form, and on a dirty one raised a discard prompt the user never
  // asked for.
  testWidgets('the helper sentence sits outside the tap surface', (
    tester,
  ) async {
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(
        clientId: 'c1',
        helperText: 'why it is locked',
      ),
    );

    expect(find.byType(InkWell), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.text('why it is locked'),
      ),
      findsNothing,
      reason: 'reading the reason must not navigate away from the form',
    );
    // …but the value it names still is inside it.
    expect(
      find.descendant(of: find.byType(InkWell), matching: find.text('Acme')),
      findsOneWidget,
    );
  });

  // `docs/row-actions-and-values.md`: an inline text link takes `link:`, but a
  // whole row that navigates keeps `button:` — and the role has to sit on the
  // same node as the action, because `InkResponse` supplies `onTap` and never
  // sets `button`. Without the merge the flag lands on a node with four loose
  // text children and no name of its own.
  testWidgets('a tappable row is one button node carrying label and action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final repo = _FakeClientRepo(client: _client('c1'));
    await _pump(
      tester,
      services: servicesWith(repo),
      child: const LockedClientFieldRow(
        clientId: 'c1',
        helperText: 'why it is locked',
      ),
    );

    final data = tester
        .getSemantics(find.byType(MergeSemantics))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.label, contains('Client'));
    expect(data.label, contains('Acme'));
    handle.dispose();
  });

  // ── The vendor twin ─────────────────────────────────────────────────

  testWidgets('the vendor row renders its label, name and lock', (
    tester,
  ) async {
    await _pump(
      tester,
      services: servicesWith(
        _FakeClientRepo(),
        vendors: _FakeVendorRepo(vendor: _vendor('v1')),
      ),
      child: const LockedVendorFieldRow(vendorId: 'v1'),
    );

    expect(find.text('Vendor'), findsOneWidget);
    expect(find.text('Northwind Supply'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  // The regression this whole widget exists to avoid, on the side that had it:
  // `VendorNameLabel` used to fall back to the raw hashid, which is survivable
  // in a table cell and not under a `Vendor` label on a form.
  testWidgets('an unresolved vendor renders an em dash, never the raw id', (
    tester,
  ) async {
    await _pump(
      tester,
      services: servicesWith(
        _FakeClientRepo(),
        vendors: _FakeVendorRepo(), // resolves to null
      ),
      child: const LockedVendorFieldRow(vendorId: 'Wpmbk5ezJn'),
    );

    expect(find.text('Wpmbk5ezJn'), findsNothing);
    expect(find.text('—'), findsOneWidget);
  });
}
