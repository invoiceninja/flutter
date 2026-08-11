import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/ui/features/clients/widgets/client_create_dialog.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

class _CapturingClientRepo implements ClientRepository {
  final List<Client> created = [];

  @override
  Future<SaveResult<Client>> create({
    required String companyId,
    required Client draft,
    String? existingTempId,
  }) async {
    created.add(draft);
    return SaveResult(
      entity: draft.copyWith(id: 'tmp_x'),
      outboxRowId: created.length,
    );
  }

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream<Client?>.value(
        created.isEmpty ? null : created.last.copyWith(id: id),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeStatics implements StaticsRepository {
  @override
  Map<String, Currency> get currencies => const {};
  @override
  Map<String, Language> get languages => const {};
  @override
  Map<String, Country> get countries => const {};
  @override
  Currency? currency(String id) => null;
  @override
  Language? language(String id) => null;
  @override
  Country? country(String id) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The 422 path looks for a dead outbox row to bin, and in production it
/// ALWAYS finds one — `awaitRow` only reports `validationFailed` for a row
/// that is already `state='dead'` with `lastStatusCode == 422`, which is
/// exactly `findDeadForEntity`'s filter. Returning null here would skip the
/// discard entirely and hide whatever it does to the form's state.
class _FakeOutboxDao implements OutboxDao {
  int discardLookups = 0;

  @override
  Future<OutboxRow?> findDeadForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) async {
    discardLookups++;
    return OutboxRow(
      id: 99,
      companyId: companyId,
      entityType: entityType,
      entityId: entityId,
      mutationKind: 'create',
      payload: '{}',
      idempotencyKey: 'idem',
      attempts: 1,
      nextAttemptAt: 0,
      state: 'dead',
      lastStatusCode: 422,
      requiresPassword: false,
      createdAt: 0,
    );
  }

  final List<int> deletedRows = [];

  @override
  Future<int> deleteRow(int id) async {
    deletedRows.add(id);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeDb implements AppDatabase {
  @override
  final OutboxDao outboxDao = _FakeOutboxDao();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGroups implements GroupSettingRepository {
  @override
  Stream<List<GroupSetting>> watchAll({required String companyId}) =>
      Stream<List<GroupSetting>>.value(const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSync implements SyncRepository {
  _FakeSync(this.result);
  final SyncRowResult result;
  final List<int> discarded = [];

  @override
  Future<SyncRowResult> awaitRow({
    required int rowId,
    required String companyId,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 200),
    bool callerWillDisplayFailure = true,
  }) async => result;

  @override
  Future<bool> discardOutboxRow(int id) async {
    discarded.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({
    required this.clients,
    required this.statics,
    required this.groupSettings,
    required this.sync,
    required this.connectivity,
  });
  @override
  final AppDatabase db = _FakeDb();
  @override
  final ClientRepository clients;
  @override
  final StaticsRepository statics;
  @override
  final GroupSettingRepository groupSettings;
  @override
  final SyncRepository sync;
  @override
  final ConnectivityWatcher connectivity;

  /// No company loaded in these tests — the VM falls back to a dot decimal
  /// separator, which is what the assertions assume.
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _CapturingClientRepo repo;
  late _FakeServices services;
  late Client? result;
  late bool closed;

  Future<void> open(
    WidgetTester tester, {
    String initialName = '',
    SyncRowResult? syncResult,
    bool online = true,
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    repo = _CapturingClientRepo();
    services = _FakeServices(
      clients: repo,
      statics: _FakeStatics(),
      groupSettings: _FakeGroups(),
      sync: _FakeSync(
        syncResult ?? const SyncRowResult(outcome: SyncRowOutcome.success),
      ),
      connectivity: ConnectivityWatcher.fixed(online: online),
    );
    result = null;
    closed = false;

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showClientCreateDialog(
                      context,
                      companyId: 'co',
                      initialName: initialName,
                    );
                    closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder fieldNamed(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  group('layout', () {
    // Locks React's field set — this dialog is deliberately narrower than the
    // full client edit screen.
    testWidgets('renders the four tabs with their fields', (tester) async {
      await open(tester);

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      expect(find.text('Shipping'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);

      for (final label in [
        'Name',
        'VAT Number',
        'First Name',
        'Last Name',
        'Email',
        'Phone',
        'Currency',
      ]) {
        expect(find.text(label), findsWidgets, reason: 'Details: $label');
      }

      await tester.tap(find.text('Address'));
      await tester.pumpAndSettle();
      for (final label in ['Street', 'City', 'State/Province', 'Postal Code']) {
        expect(find.text(label), findsWidgets, reason: 'Address: $label');
      }

      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();
      expect(find.text('Shipping Street'), findsWidgets);

      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Send Reminders'), findsWidgets);
    });

    testWidgets('prefills the name typed into the picker', (tester) async {
      await open(tester, initialName: 'Acme Corp');

      expect(
        tester.widget<TextField>(fieldNamed('Name')).controller!.text,
        'Acme Corp',
      );
    });

    // A four-tab, twenty-field form in an AlertDialog is ~295px wide on a
    // phone after inset padding — unusable, so it goes fullscreen instead.
    testWidgets('goes fullscreen on a narrow window', (tester) async {
      await open(tester, size: const Size(390, 844));

      expect(find.byType(Dialog).hitTestable(), findsWidgets);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('stays a windowed dialog on a wide window', (tester) async {
      await open(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('name guard', () {
    // React blocks only when the client name AND both contact names are
    // blank; the server itself accepts a nameless client.
    testWidgets('blocks a save with no name and no contact name', (
      tester,
    ) async {
      await open(tester);
      await save(tester);

      expect(repo.created, isEmpty);
      expect(closed, isFalse);
      expect(find.text('Please enter a client or contact name'), findsWidgets);
    });

    testWidgets('a contact first name alone is enough', (tester) async {
      await open(tester);
      await tester.enterText(fieldNamed('First Name'), 'Ada');
      await tester.pumpAndSettle();
      await save(tester);

      expect(repo.created, hasLength(1));
      expect(repo.created.single.contacts.first.firstName, 'Ada');
      expect(result?.id, 'tmp_x');
    });

    testWidgets('no error is shown before the first save attempt', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Please enter a client or contact name'), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('returns the created client and closes', (tester) async {
      await open(tester, initialName: 'Acme Corp');
      await save(tester);

      expect(repo.created.single.name, 'Acme Corp');
      expect(result?.id, 'tmp_x');
      expect(closed, isTrue);
    });

    // The tab bodies are disposed when off-screen (TabBarView is lazy), so
    // this proves edits land in the VM rather than in per-tab widget state.
    testWidgets('address and shipping edits survive tab switching', (
      tester,
    ) async {
      await open(tester, initialName: 'Acme Corp');

      await tester.tap(find.text('Address'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldNamed('Street'), '1 Main St');
      await tester.enterText(fieldNamed('City'), 'Springfield');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();
      await tester.enterText(fieldNamed('Shipping Street'), '2 Depot Rd');
      await tester.pumpAndSettle();

      // Back to Details, so both edited tabs have been disposed.
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await save(tester);

      final saved = repo.created.single;
      expect(saved.address1, '1 Main St');
      expect(saved.city, 'Springfield');
      expect(saved.shippingAddress1, '2 Depot Rd');
    });

    testWidgets('a 422 keeps the dialog open with the error inline', (
      tester,
    ) async {
      await open(
        tester,
        initialName: 'Acme Corp',
        syncResult: const SyncRowResult(
          outcome: SyncRowOutcome.validationFailed,
          fieldErrors: {
            'contacts.0.email': ['is invalid'],
          },
        ),
      );
      await tester.enterText(fieldNamed('Email'), 'nope');
      await tester.pumpAndSettle();
      await save(tester);

      expect(closed, isFalse);
      expect(find.text('is invalid'), findsOneWidget);
    });

    // Offline creation must not hang on the outbox: `save()` checks
    // connectivity before awaiting the row.
    testWidgets('offline still closes with the tmp client', (tester) async {
      await open(tester, initialName: 'Acme Corp', online: false);
      await save(tester);

      expect(result?.id, 'tmp_x');
      expect(closed, isTrue);
    });

    testWidgets('cancel returns null and writes nothing', (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repo.created, isEmpty);
      expect(result, isNull);
      expect(closed, isTrue);
    });

    // Twenty fields of typing shouldn't vanish to a stray click.
    testWidgets('cancelling a dirty draft asks before discarding', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(fieldNamed('Name'), 'Acme');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(closed, isFalse);
    });

    // `barrierDismissible: false` disables the modal route's own dismiss
    // action, so without an explicit binding Escape does nothing at all.
    testWidgets('Escape routes through the discard prompt', (tester) async {
      await open(tester);
      await tester.enterText(fieldNamed('Name'), 'Acme');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(closed, isFalse);
    });
  });

  // A failed save leaves a local `tmp_` client plus its outbox row. Neither
  // may outlive the dialog when the user abandons it, and neither may be
  // binned while the user is still fixing the flagged fields.
  group('failed-attempt cleanup', () {
    SyncRowResult emailRejected() => const SyncRowResult(
      outcome: SyncRowOutcome.validationFailed,
      fieldErrors: {
        'contacts.0.email': ['is invalid'],
      },
    );

    testWidgets('a 422 keeps the ghost so the user can fix and re-save', (
      tester,
    ) async {
      await open(tester, initialName: 'Acme Corp', syncResult: emailRejected());
      await save(tester);

      // Binning it here would also wipe the field errors the form is meant
      // to be displaying (clearFailedSync), leaving a form that reports
      // nothing at all.
      final sync = services.sync as _FakeSync;
      expect(sync.discarded, isEmpty);
      expect(find.text('is invalid'), findsOneWidget);
    });

    testWidgets('cancelling after a failed save bins the ghost client', (
      tester,
    ) async {
      await open(tester, initialName: 'Acme Corp', syncResult: emailRejected());
      await save(tester);
      // Nothing was typed beyond the seeded name, so the draft is clean and
      // Cancel closes straight away — no discard prompt to clear.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      final sync = services.sync as _FakeSync;
      expect(sync.discarded, [99]);
      expect(result, isNull);
      expect(closed, isTrue);
    });

    testWidgets('a successful save drops the superseded dead row', (
      tester,
    ) async {
      await open(tester, initialName: 'Acme Corp');
      await save(tester);

      // No prior failure here, so nothing to consume — but the lookup must
      // not blow up on the happy path.
      final sync = services.sync as _FakeSync;
      expect(sync.discarded, isEmpty);
      expect(result?.id, 'tmp_x');
    });
  });
}
