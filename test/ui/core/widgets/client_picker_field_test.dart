import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/ui/core/widgets/client_picker_field.dart';

import '../../../_localization_helper.dart';

/// Never hand this widget a real Drift watch stream in a test —
/// `pumpAndSettle` never settles against a live watch (it times out after
/// ~10 minutes and then fails). `Stream.value` is required.
///
/// `watchPage` deliberately HONOURS `search:` and caps at [windowSize], the
/// way Drift does. A fake that ignores the filter would hide the bug this
/// picker exists to avoid: fetching a match from the server and then reading
/// it back through a window that excludes it.
class _FakeClientRepo implements ClientRepository {
  _FakeClientRepo(
    this.rows, {
    this.serverOnly = const [],
    this.windowSize = 50,
  });

  final List<Client> rows;

  /// Rows the server has but the local cache does not — moved into [rows] by
  /// `ensurePageLoaded`, exactly as a real fetch would.
  final List<Client> serverOnly;

  /// Local page size, so a test can push a client outside the window.
  final int windowSize;

  final List<String?> searches = [];
  final List<String?> fetches = [];

  /// Ids handed to [watch], in order — the selected-client subscription. A
  /// commit must re-point it, or the field keeps listening to the client the
  /// document no longer references.
  final List<String> watched = [];

  /// When set, `ensurePageLoaded` parks here until the test completes it, so a
  /// test can start a server search and then supersede it mid-flight.
  Completer<void>? fetchGate;

  /// Mirrors `ClientDao.watchPage`'s search predicate — name / number /
  /// email / id_number / custom values, where the `email` column holds the
  /// PRIMARY contact's address. Kept in step with the DAO deliberately: a fake
  /// that matches more generously than production would let a search bug
  /// through green tests.
  bool _matches(Client c, String q) {
    final needle = q.toLowerCase();
    final primaryEmail = c.contacts
        .where((ct) => ct.isPrimary)
        .map((ct) => ct.email)
        .firstOrNull;
    return c.name.toLowerCase().contains(needle) ||
        c.number.toLowerCase().contains(needle) ||
        c.idNumber.toLowerCase().contains(needle) ||
        (primaryEmail ?? '').toLowerCase().contains(needle);
  }

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
  }) {
    searches.add(search);
    final sorted = [...rows]..sort((a, b) => a.name.compareTo(b.name));
    final filtered = (search == null || search.isEmpty)
        ? sorted
        : sorted.where((c) => _matches(c, search)).toList();
    return Stream<List<Client>>.value(
      filtered.take(loadedPages * windowSize).toList(),
    );
  }

  @override
  Stream<Client?> watch({required String companyId, required String id}) {
    watched.add(id);
    return Stream<Client?>.value(
      [...rows, ...serverOnly].where((c) => c.id == id).firstOrNull,
    );
  }

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<Object?> states = const {},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    fetches.add(search);
    final gate = fetchGate;
    if (gate != null) await gate.future;
    if (search != null && search.isNotEmpty) {
      for (final c in serverOnly) {
        if (_matches(c, search) && !rows.contains(c)) rows.add(c);
      }
    }
    return true;
  }

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
  _FakeServices({required this.auth, required this.clients});
  @override
  final AuthRepository auth;
  @override
  final ClientRepository clients;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Client _client(
  String id, {
  String name = '',
  String displayName = '',
  String number = '',
  List<Contact> contacts = const [],
}) => Client(
  id: id,
  name: name,
  displayName: displayName.isEmpty ? name : displayName,
  number: number,
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

Contact _contact({
  String id = 'ct1',
  String firstName = '',
  String lastName = '',
  String email = '',
}) => Contact(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  phone: '',
  isPrimary: true,
  sendEmail: true,
  isDeleted: false,
  updatedAt: DateTime.utc(2026),
);

AuthSession _session({
  String permissions = '',
  bool isAdmin = true,
  bool isOwner = false,
}) => AuthSession(
  baseUrl: '',
  isHosted: false,
  accountId: '',
  currentCompanyId: 'co',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: permissions,
      isAdmin: isAdmin,
      isOwner: isOwner,
    ),
  ],
);

void main() {
  late _FakeClientRepo repo;
  late _FakeServices services;

  /// Records what the widget reports back so tests can assert the commit.
  late List<Client?> selected;
  late List<String> createRequests;

  Future<void> pump(
    WidgetTester tester, {
    List<Client> rows = const [],
    List<Client> serverOnly = const [],
    int windowSize = 50,
    String selectedClientId = '',
    Future<Client?> Function(BuildContext, String)? onCreate,
    AuthSession? session,
    bool wireCreate = true,
  }) async {
    repo = _FakeClientRepo(
      [...rows],
      serverOnly: serverOnly,
      windowSize: windowSize,
    );
    services = _FakeServices(
      auth: _FakeAuth(ValueNotifier<AuthSession?>(session ?? _session())),
      clients: repo,
    );
    selected = [];
    createRequests = [];

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ClientPickerField(
                companyId: 'co',
                selectedClientId: selectedClientId,
                onSelected: selected.add,
                onCreateRequested: !wireCreate
                    ? null
                    : (context, name) async {
                        createRequests.add(name);
                        return onCreate == null
                            ? null
                            : onCreate(context, name);
                      },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  group('create affordance', () {
    // The reason this widget exists: RawAutocomplete hides its options
    // overlay entirely when the option list is empty, so a footer-based
    // affordance on SearchableDropdownField is unreachable for a brand-new
    // name — exactly the case inline-create is for.
    testWidgets('appears for a query that matches nothing', (tester) async {
      await pump(tester, rows: [_client('c1', name: 'Globex')]);
      await type(tester, 'Acme');

      expect(find.text('Globex'), findsNothing);
      expect(find.text('Create "Acme"'), findsOneWidget);
    });

    testWidgets('appears below matches and is always last', (tester) async {
      await pump(tester, rows: [_client('c1', name: 'Acme Holdings')]);
      await type(tester, 'Acme');

      expect(find.text('Acme Holdings'), findsOneWidget);
      expect(find.text('Create "Acme"'), findsOneWidget);
      final matchY = tester.getTopLeft(find.text('Acme Holdings')).dy;
      final createY = tester.getTopLeft(find.text('Create "Acme"')).dy;
      expect(createY, greaterThan(matchY));
    });

    testWidgets('shows a plain New Client row with an empty query', (
      tester,
    ) async {
      await pump(tester, rows: [_client('c1', name: 'Globex')]);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('New Client'), findsOneWidget);
    });

    // A company with no clients yet is the account that most needs "create" —
    // SearchableDropdownField would render a disabled placeholder here.
    testWidgets('is available when the company has no clients', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(find.text('New Client'), findsOneWidget);
    });

    testWidgets('is hidden without create_client permission', (tester) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Globex')],
        session: _session(permissions: 'view_client', isAdmin: false),
      );
      await type(tester, 'Acme');

      expect(find.textContaining('Create'), findsNothing);
    });

    testWidgets('is hidden when the host passes no create callback', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Globex')],
        wireCreate: false,
      );
      await type(tester, 'Acme');

      expect(find.textContaining('Create'), findsNothing);
    });
  });

  group('creating', () {
    testWidgets('passes the trimmed query and commits the result', (
      tester,
    ) async {
      await pump(
        tester,
        onCreate: (_, name) async => _client('tmp_x', name: 'Acme Corp'),
      );
      await type(tester, '  Acme Corp  ');
      await tester.tap(find.textContaining('Create'));
      await tester.pumpAndSettle();

      expect(createRequests, ['Acme Corp']);
      expect(selected.single?.id, 'tmp_x');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Acme Corp',
      );
    });

    // The created client carries a tmp_ id and is not in the (fixed) stream,
    // so a stream-derived selection would render blank.
    testWidgets('keeps a client absent from the stream visible', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Globex')],
        onCreate: (_, name) async => _client('tmp_x', name: 'Acme Corp'),
      );
      await type(tester, 'Acme Corp');
      await tester.tap(find.textContaining('Create'));
      await tester.pumpAndSettle();

      // Rebuild the host as the parent would once the VM took the new id.
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Acme Corp',
      );
    });

    testWidgets('cancelling restores the half-typed query verbatim', (
      tester,
    ) async {
      await pump(tester, onCreate: (_, _) async => null);
      await type(tester, 'Acme Cor');
      await tester.tap(find.textContaining('Create'));
      await tester.pumpAndSettle();

      expect(selected, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Acme Cor',
      );
    });

    // Regression: routing the create row through RawAutocomplete.onSelected
    // poisons `_selection` — `_select` early-returns on an unchanged
    // selection and optionsBuilder doesn't re-run for unchanged text, so the
    // row would be permanently dead after one cancel.
    testWidgets('create -> cancel -> create fires twice', (tester) async {
      await pump(tester, onCreate: (_, _) async => null);
      await type(tester, 'Acme');

      await tester.tap(find.textContaining('Create'));
      await tester.pumpAndSettle();
      expect(createRequests, hasLength(1));

      await tester.tap(find.textContaining('Create'));
      await tester.pumpAndSettle();
      expect(createRequests, hasLength(2));
    });
  });

  group('keyboard', () {
    testWidgets('Enter on the highlighted create row creates', (tester) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Acme Holdings')],
        onCreate: (_, name) async => _client('tmp_x', name: name),
      );
      await type(tester, 'Acme');

      // Create is last, so one arrow-down past the single match lands on it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(createRequests, ['Acme']);
      expect(selected.single?.id, 'tmp_x');
    });

    testWidgets('Enter on a highlighted match selects, never creates', (
      tester,
    ) async {
      await pump(tester, rows: [_client('c1', name: 'Acme Holdings')]);
      await type(tester, 'Acme');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(createRequests, isEmpty);
      expect(selected.single?.id, 'c1');
    });

    // `DismissIntent` hides the options overlay WITHOUT moving focus, so a
    // "popover is showing" flag captured at build time goes stale — and the
    // next Enter would open the create dialog over a popover the user just
    // dismissed.
    testWidgets('Escape then Enter does not create', (tester) async {
      await pump(
        tester,
        onCreate: (_, name) async => _client('tmp_x', name: name),
      );
      await type(tester, 'Acme');
      expect(find.text('Create "Acme"'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(createRequests, isEmpty);
      expect(selected, isEmpty);
    });
  });

  group('field affordances', () {
    // The clear button has to appear as soon as there is something to clear;
    // `RawAutocomplete` does not rebuild its field on a text change, so the
    // suffix has to be driven off the controller.
    testWidgets('the clear button appears while typing into an empty field', (
      tester,
    ) async {
      await pump(tester, rows: [_client('c1', name: 'Acme Holdings')]);
      expect(find.byIcon(Icons.close), findsNothing);

      await type(tester, 'Acme');

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.search), findsNothing);
    });
  });

  group('matching', () {
    testWidgets('finds a client by contact email, not just name', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [
          _client(
            'c1',
            name: 'Globex',
            contacts: [_contact(email: 'ada@example.com')],
          ),
        ],
      );
      await type(tester, 'ada@example');

      expect(find.text('Globex'), findsOneWidget);
    });

    testWidgets('finds a client by number', (tester) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Globex', number: 'CL-0042')],
      );
      await type(tester, 'CL-0042');

      expect(find.text('Globex'), findsOneWidget);
    });

    testWidgets('labels a client that has only a contact name', (tester) async {
      await pump(
        tester,
        rows: [
          _client(
            'c1',
            contacts: [_contact(firstName: 'Ada', lastName: 'Lovelace')],
          ),
        ],
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsOneWidget);
    });
  });

  // The whole point of reaching the server: if a match exists but isn't in the
  // local page yet, the picker must surface it instead of offering to create a
  // duplicate. Reading results back through an UNFILTERED window silently
  // defeats that — the fetched row lands outside it.
  group('server search', () {
    testWidgets('surfaces a client the local cache does not hold', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Acme Holdings')],
        serverOnly: [_client('c2', name: 'Zephyr Industries')],
      );
      await type(tester, 'Zephyr');

      expect(repo.fetches, contains('Zephyr'));
      expect(find.text('Zephyr Industries'), findsOneWidget);
    });

    testWidgets('narrows the local read by the same query it fetched', (
      tester,
    ) async {
      await pump(tester, rows: [_client('c1', name: 'Acme Holdings')]);
      await type(tester, 'Acme');

      expect(repo.searches, contains('Acme'));
    });

    testWidgets('still offers create when the server has no match either', (
      tester,
    ) async {
      await pump(tester, rows: [_client('c1', name: 'Acme Holdings')]);
      await type(tester, 'Nobody');

      expect(repo.fetches, contains('Nobody'));
      expect(find.text('Create "Nobody"'), findsOneWidget);
    });
  });

  group('selection', () {
    // A document's client may sort outside the first page. Resolving it by id
    // rather than by scanning the search results keeps the field populated.
    testWidgets('renders a selected client outside the search window', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Acme Holdings')],
        serverOnly: [_client('far', name: 'Zephyr Industries')],
        selectedClientId: 'far',
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Zephyr Industries',
      );
    });

    testWidgets('renders the selected client on first build', (tester) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Globex')],
        selectedClientId: 'c1',
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Globex',
      );
    });

    // invoiceninja/flutter#34: the field's text is the committed client's own
    // name, so searching by it used to offer that one client straight back —
    // leaving "clear the field first" as the only way to reach the others.
    testWidgets('tapping a populated field offers the other clients', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [
          _client('c1', name: 'Globex'),
          _client('c2', name: 'Initech'),
          _client('c3', name: 'Umbrella'),
        ],
        selectedClientId: 'c1',
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Initech'), findsOneWidget);
      expect(find.text('Umbrella'), findsOneWidget);
      expect(selected, isEmpty);
    });

    testWidgets('tapping a match commits it', (tester) async {
      await pump(tester, rows: [_client('c1', name: 'Globex')]);
      await type(tester, 'Glob');
      await tester.tap(find.text('Globex'));
      await tester.pumpAndSettle();

      expect(selected.single?.id, 'c1');
      expect(createRequests, isEmpty);
    });

    testWidgets('clearing emits null', (tester) async {
      await pump(
        tester,
        rows: [_client('c1', name: 'Globex')],
        selectedClientId: 'c1',
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(selected, [null]);
    });

    // The idle list is the whole client page in list order, so without a hoist
    // the default highlight (row 0) is whatever sorts first — NOT the client the
    // document holds. Enter, or Android's soft-keyboard "Done", then silently
    // replaced the invoice's client.
    testWidgets('the committed client is hoisted to the top of the idle list', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [
          _client('c1', name: 'Acme'),
          _client('c2', name: 'Globex'),
          _client('c3', name: 'Umbrella'),
        ],
        selectedClientId: 'c3',
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      Offset optionAt(String name) => tester.getTopLeft(
        find.descendant(of: find.byType(ListView), matching: find.text(name)),
      );
      expect(optionAt('Umbrella').dy, lessThan(optionAt('Acme').dy));
      expect(optionAt('Acme').dy, lessThan(optionAt('Globex').dy));
    });

    testWidgets('Enter on an untouched populated field does not switch client', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [
          _client('c1', name: 'Acme'),
          _client('c2', name: 'Globex'),
          _client('c3', name: 'Umbrella'),
        ],
        selectedClientId: 'c3',
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Dismisses rather than re-picking — and above all never commits 'Acme'.
      expect(selected, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Umbrella',
      );
    });

    // `_searching` used to be cleared on exactly one path, so a run that was
    // superseded mid-fetch left it stuck on — and `_buildSuffix` tests it
    // first, so the ✕ was replaced by a permanent spinner.
    testWidgets('a superseded server search does not strand the spinner', (
      tester,
    ) async {
      await pump(tester, rows: [_client('c1', name: 'Globex')]);
      repo.fetchGate = Completer<void>();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // No local match -> the server search starts and the spinner appears.
      // Bounded pumps from here on: `pumpAndSettle` can never settle while a
      // `CircularProgressIndicator` is animating.
      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Supersede it with a query that DOES match locally: the new run never
      // enters the fetch branch, so nothing else would clear the flag.
      await tester.enterText(find.byType(TextField), 'Glob');
      await tester.pump();
      repo.fetchGate!.complete();
      await tester.pump();
      // Past the warm-fetch debounce, so no timer outlives the test.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    // The watch resolves the committed client by id. It used to be armed once
    // and never re-pointed after a commit, so the next write to the clients
    // table re-emitted the OLD client and reverted the field behind the
    // document's back.
    testWidgets('committing re-points the selected-client watch', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [
          _client('c1', name: 'Globex'),
          _client('c2', name: 'Initech'),
        ],
        selectedClientId: 'c1',
      );
      expect(repo.watched, ['c1']);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Initech'));
      await tester.pumpAndSettle();
      expect(selected.single?.id, 'c2');

      // Re-render as the host would, with the newly committed id.
      await tester.pumpWidget(
        Provider<Services>.value(
          value: services,
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: ClientPickerField(
                  companyId: 'co',
                  selectedClientId: 'c2',
                  onSelected: selected.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.watched, ['c1', 'c2']);
    });
  });
}
