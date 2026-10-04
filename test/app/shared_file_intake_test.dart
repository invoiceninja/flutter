import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/app/shared_file_intake.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../_localization_helper.dart';

/// What a file shared into the app does (invoiceninja/flutter#173). Every
/// failure guarded here is a silent one: a share acted on over the lock
/// screen, a share dropped because it arrived before the router or the first
/// frame, and an app-owned copy of a receipt left on disk — or handed to the
/// next account — because some exit path forgot to delete it.

const _co1 = AuthCompany(
  id: 'co1',
  name: 'One',
  displayName: 'One',
  permissions: '',
  isAdmin: true,
  isOwner: true,
);

/// A company nobody has named yet — what the `/setup` gate waits on.
const _unnamed = AuthCompany(
  id: 'co1',
  name: '',
  displayName: '',
  permissions: '',
  isAdmin: true,
  isOwner: true,
);

AuthSession _session({bool setupDone = true}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acc-1',
  companies: [setupDone ? _co1 : _unnamed],
  currentCompanyId: 'co1',
);

const _credentials = ApiCredentials(
  baseUrl: 'https://example.test',
  token: 'tok',
);

class _Harness {
  _Harness({
    bool authenticated = true,
    bool locked = false,
    bool setupDone = true,
    this.canCreate = true,
    this.moduleOn = true,
    this.canAttach = true,
    this.confirm = true,
  }) : session = ValueNotifier(
         authenticated ? _session(setupDone: setupDone) : null,
       ),
       credentials = ValueNotifier(authenticated ? _credentials : null),
       locked = ValueNotifier(locked) {
    dir = Directory.systemTemp.createTempSync('shared_intake_test');
    intake = SharedFileIntake(
      session: session,
      credentials: credentials,
      requiresBiometricUnlock: this.locked,
      isSetupRequired: (s) => s?.currentCompany?.displayName.isEmpty ?? false,
      canCreateExpense: () => canCreate,
      expenseModuleOn: () => moduleOn,
      canAttachDocuments: () => canAttach,
      currentCompanyId: () => session.value?.currentCompanyId,
      confirmLeave: (_) async {
        confirmCalls++;
        onConfirm?.call();
        return confirm;
      },
      stageExpense: staged.add,
      deleteFiles: (paths) async => deleted.addAll(paths),
      ownsFile: (path) async => p.isWithin(dir.path, path),
      toasts: toasts,
    );
  }

  final ValueNotifier<AuthSession?> session;
  final ValueNotifier<ApiCredentials?> credentials;
  final ValueNotifier<bool> locked;
  final toasts = ToastController();
  late final Directory dir;
  late final SharedFileIntake intake;

  bool canCreate;
  bool moduleOn;
  bool canAttach;
  bool confirm;
  int confirmCalls = 0;

  /// Runs while the unsaved-changes prompt is "up".
  void Function()? onConfirm;

  final staged = <List<UploadSource>>[];
  final navigations = <String>[];
  final deleted = <String>[];
  BuildContext? context;

  /// A real file under the temp dir — validation reads its length.
  SharedFile file(String name, {int bytes = 10, SharedFileIssue? issue}) {
    if (issue != null) return SharedFile(path: '', name: name, issue: issue);
    final f = File(p.join(dir.path, name))
      ..writeAsBytesSync(List.filled(bytes, 1));
    return SharedFile(path: f.path, name: name);
  }

  void attach() => intake.attach(go: navigations.add, contextOf: () => context);

  /// `AuthRepository`'s order: session first, credentials second.
  void signIn() {
    session.value = _session();
    credentials.value = _credentials;
  }

  Future<void> mountContext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  List<String> get toastMessages => [for (final t in toasts.toasts) t.message];

  void dispose() {
    intake.dispose();
    session.dispose();
    credentials.dispose();
    locked.dispose();
    toasts.clearAll();
    toasts.dispose();
    dir.deleteSync(recursive: true);
  }
}

/// One frame plus one real tick. A replay starts in a post-frame callback
/// (fake async) and then validates real files (real I/O), so it needs both.
Future<void> _tick(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
}

/// Tick until [done] — the replay's expected effect — with a generous bound,
/// so a loaded machine slows the test down instead of failing it.
Future<void> _settleUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await _tick(tester);
  }
}

/// A fixed number of ticks, for asserting that NOTHING happens.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await _tick(tester);
  }
}

void main() {
  testWidgets('opens New Expense with the shared files staged', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('receipt.pdf');
    final b = h.file('photo.jpg');

    await tester.runAsync(() => h.intake.receive([a, b]));

    expect(h.navigations, [SharedFileIntake.kTarget]);
    expect(h.staged, hasLength(1));
    expect(h.staged.single.map((s) => s.fileName), [
      'receipt.pdf',
      'photo.jpg',
    ]);
    expect(h.deleted, isEmpty);
    expect(h.confirmCalls, 1, reason: 'a dirty form must get its prompt');
  });

  testWidgets('a share while biometric-locked waits for the unlock, then '
      'replays after the frame', (tester) async {
    final h = _Harness(locked: true)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));
    expect(h.navigations, isEmpty);
    expect(h.intake.heldPaths, hasLength(1));

    h.locked.value = false;
    await _settleUntil(tester, () => h.navigations.isNotEmpty);

    expect(h.navigations, [SharedFileIntake.kTarget]);
    expect(h.intake.heldPaths, isEmpty);
  });

  testWidgets('a share while signed out waits for the sign-in — whose session '
      'lands before its credentials', (tester) async {
    final h = _Harness(authenticated: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));
    expect(h.navigations, isEmpty);

    h.signIn();
    await _settleUntil(tester, () => h.navigations.isNotEmpty);

    expect(h.navigations, [SharedFileIntake.kTarget]);
  });

  testWidgets('a second share while waiting is appended, not dropped', (
    tester,
  ) async {
    final h = _Harness(locked: true)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));
    await tester.runAsync(() => h.intake.receive([h.file('b.pdf')]));
    expect(h.intake.heldPaths, hasLength(2));

    h.locked.value = false;
    await _settleUntil(tester, () => h.navigations.isNotEmpty);

    expect(h.navigations, [SharedFileIntake.kTarget]);
    expect(h.staged.single.map((s) => s.fileName), ['a.pdf', 'b.pdf']);
  });

  testWidgets('a share during company setup waits until setup is done — the '
      'router would bounce New Expense to /setup and lose it', (tester) async {
    final h = _Harness(setupDone: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));
    expect(h.navigations, isEmpty);

    h.session.value = _session();
    await _settleUntil(tester, () => h.navigations.isNotEmpty);

    expect(h.navigations, [SharedFileIntake.kTarget]);
  });

  testWidgets('a share before the router exists is replayed by attach', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));
    expect(h.navigations, isEmpty);

    h.attach();
    await _settleUntil(tester, () => h.navigations.isNotEmpty);

    expect(h.navigations, [SharedFileIntake.kTarget]);
  });

  testWidgets('without permission to create an expense: toast, delete, stay', (
    tester,
  ) async {
    final h = _Harness(canCreate: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));

    expect(h.navigations, isEmpty);
    expect(h.staged, isEmpty);
    expect(h.deleted, [a.path]);
    expect(h.toastMessages, ["Sorry, you don't have the needed permissions"]);
  });

  testWidgets('with Expenses switched off, the refusal says so — not that a '
      'permission is missing', (tester) async {
    final h = _Harness(canCreate: false, moduleOn: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));

    expect(h.navigations, isEmpty);
    expect(h.deleted, [a.path]);
    expect(h.toastMessages, ['Expenses is disabled for this company']);
  });

  testWidgets('a plan without attachments still opens New Expense, with no '
      'files, and says why the receipt didn\'t come along', (tester) async {
    final h = _Harness(canAttach: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));

    expect(h.navigations, [SharedFileIntake.kTarget]);
    expect(h.staged.single, isEmpty);
    expect(h.deleted, [a.path]);
    expect(h.toastMessages, ['Requires an Enterprise Plan']);
  });

  testWidgets('rejects are toasted with the upload surfaces\' words and '
      'deleted; the rest go through', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final good = h.file('receipt.pdf');
    final exe = h.file('setup.exe');
    final big = h.file('scan.pdf', issue: SharedFileIssue.tooLarge);

    await tester.runAsync(() => h.intake.receive([good, exe, big]));

    expect(h.staged.single.map((s) => s.fileName), ['receipt.pdf']);
    expect(h.deleted, [exe.path]);
    expect(h.toastMessages, hasLength(2));
    expect(h.navigations, [SharedFileIntake.kTarget]);
  });

  testWidgets('nothing valid left: no New Expense', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(
      () => h.intake.receive([
        h.file('logo.svg', issue: SharedFileIssue.unsupported),
      ]),
    );

    expect(h.navigations, isEmpty);
    expect(h.staged, isEmpty);
    expect(h.toastMessages, hasLength(1));
  });

  testWidgets('cancelling the unsaved-changes prompt keeps the form and '
      'deletes the share', (tester) async {
    final h = _Harness(confirm: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));

    expect(h.navigations, isEmpty);
    expect(h.staged, isEmpty);
    expect(h.deleted, [a.path]);
  });

  testWidgets('a deliberate sign-out (dropHeld) deletes a held share, which '
      'never replays into the next session', (tester) async {
    final h = _Harness(locked: true)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));
    h.intake
      ..endSession()
      ..dropHeld();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(h.deleted, [a.path]);
    expect(h.intake.heldPaths, isEmpty);

    h.locked.value = false;
    await _settle(tester);
    expect(h.navigations, isEmpty);
  });

  testWidgets('a share held while signed out survives a different identity '
      'signing in — endSession runs, dropHeld does not — and replays after', (
    tester,
  ) async {
    final h = _Harness(authenticated: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));
    // The identity-change wipe: onBeforeLogout → endSession, then
    // purgeAll(except: heldPaths) — and no onSessionReset.
    h.intake.endSession();
    expect(h.intake.heldPaths, {a.path});
    expect(h.deleted, isEmpty);

    h.signIn();
    await _settleUntil(tester, () => h.navigations.isNotEmpty);
    expect(h.navigations, [SharedFileIntake.kTarget]);
    expect(h.staged.single.map((s) => s.fileName), ['a.pdf']);
  });

  testWidgets('a sign-out while the prompt is up drops the share', (
    tester,
  ) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    h.onConfirm = h.intake.endSession;
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));

    expect(h.navigations, isEmpty);
    expect(h.staged, isEmpty);
    expect(h.deleted, [a.path]);
  });

  testWidgets('a lock that closes the prompt holds the share for the unlock, '
      'instead of deleting it', (tester) async {
    final h = _Harness(confirm: false)..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    h.onConfirm = () => h.locked.value = true;
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));
    expect(h.deleted, isEmpty);
    expect(h.intake.heldPaths, {a.path});

    h
      ..confirm = true
      ..onConfirm = null
      ..locked.value = false;
    await _settleUntil(tester, () => h.navigations.isNotEmpty);
    expect(h.navigations, [SharedFileIntake.kTarget]);
  });

  testWidgets('a New Expense already open takes the files — no prompt, no '
      'new stage', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final onForm = <UploadSource>[];
    final unregister = h.intake.registerAttachTarget('co1', (files) {
      onForm.addAll(files);
      return true;
    });
    final a = h.file('a.pdf');

    await tester.runAsync(() => h.intake.receive([a]));

    expect(onForm.map((s) => s.fileName), ['a.pdf']);
    expect(h.staged, isEmpty);
    expect(h.confirmCalls, 0);
    expect(h.navigations, [SharedFileIntake.kTarget]);

    unregister();
    await tester.runAsync(() => h.intake.receive([h.file('b.pdf')]));
    expect(onForm, hasLength(1), reason: 'unregistered');
  });

  testWidgets('a New Expense left open in another company is not used — the '
      'share opens a fresh one in the active company', (tester) async {
    // The create screen binds its company once, at mount, and a company
    // switch keeps other branches' stacks: a form opened in co0 can still be
    // registered after the switch to co1. Joining it would save the receipt
    // into co0.
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final onStale = <UploadSource>[];
    h.intake.registerAttachTarget('co0', (files) {
      onStale.addAll(files);
      return true;
    });

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));

    expect(onStale, isEmpty);
    expect(h.staged.single.map((s) => s.fileName), ['a.pdf']);
    expect(h.navigations, [SharedFileIntake.kTarget]);
  });

  testWidgets('a New Expense that can\'t take files right now (its save is '
      'unconfirmed) sends the share to a New Expense of its own', (
    tester,
  ) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    var asked = 0;
    h.intake.registerAttachTarget('co1', (_) {
      asked++;
      return false;
    });

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));

    expect(asked, 1);
    expect(h.confirmCalls, 1, reason: 'leaving that form is the user\'s call');
    expect(h.staged.single.map((s) => s.fileName), ['a.pdf']);
  });

  testWidgets('endSession forgets the open form', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final onForm = <UploadSource>[];
    h.intake.registerAttachTarget('co1', (files) {
      onForm.addAll(files);
      return true;
    });

    h.intake.endSession();
    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));

    expect(onForm, isEmpty);
    expect(h.staged, hasLength(1));
  });

  testWidgets('a second share before the first one\'s form mounts is staged '
      'together with it', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await tester.runAsync(() => h.intake.receive([h.file('a.pdf')]));
    await tester.runAsync(() => h.intake.receive([h.file('b.pdf')]));

    expect(h.staged.last.map((s) => s.fileName), ['a.pdf', 'b.pdf']);
    expect(h.confirmCalls, 1, reason: 'the second joins, no second prompt');
  });

  testWidgets('a path outside the app\'s own shared folder is refused, and '
      'left alone', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    final foreign = File(p.join(Directory.systemTemp.path, 'private.pdf'));

    await tester.runAsync(
      () => h.intake.receive([
        SharedFile(path: foreign.path, name: 'private.pdf'),
      ]),
    );

    expect(h.staged, isEmpty);
    expect(h.deleted, isEmpty);
    expect(h.toastMessages, hasLength(1));
  });

  group('SharedFile.fromChannel', () {
    test('reads path, name and issue', () {
      final f = SharedFile.fromChannel({
        'path': '/x/a.pdf',
        'name': 'a.pdf',
        'issue': null,
      })!;
      expect((f.path, f.name, f.issue), ('/x/a.pdf', 'a.pdf', null));
      expect(
        SharedFile.fromChannel({
          'path': '',
          'name': 'big.pdf',
          'issue': 'tooLarge',
        })!.issue,
        SharedFileIssue.tooLarge,
      );
    });

    test(
      'an entry with no name is dropped; an unknown issue reads as none',
      () {
        expect(SharedFile.fromChannel({'path': '/x'}), isNull);
        expect(SharedFile.fromChannel('nope'), isNull);
        expect(
          SharedFile.fromChannel({'name': 'a.pdf', 'issue': 'whatever'})!.issue,
          isNull,
        );
      },
    );
  });
}
