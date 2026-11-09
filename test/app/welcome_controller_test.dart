import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/device_prefs_dao.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/welcome.dart';

/// A store whose preference rows can't be read — the boot `load` failed.
class _WedgedDatabase extends AppDatabase {
  _WedgedDatabase() : super(NativeDatabase.memory());

  @override
  DevicePrefsDao get devicePrefsDao => throw StateError('wedged');
}

/// The first-run schedule (docs/first-run-welcome.md): who is greeted, what
/// is remembered per user, how the setup wizard settles it, and how long the
/// other prompts keep away.
void main() {
  const alice = 'https://invoicing.co#alice';
  const bob = 'https://invoicing.co#bob';
  final noon = DateTime.utc(2026, 10, 14, 12);

  late DevicePrefsStore prefs;
  late String? signedIn;
  late DateTime now;
  late int welcomedCalls;
  late int seenCalls;

  setUp(() {
    prefs = DevicePrefsStore(null);
    signedIn = alice;
    now = noon;
    welcomedCalls = 0;
    seenCalls = 0;
  });

  WelcomeController controller({DevicePrefsStore? store, bool demo = false}) {
    final c = WelcomeController(
      prefs: store ?? prefs,
      currentUserKey: () => signedIn,
      onWelcomed: () async => welcomedCalls++,
      onSeen: () async => seenCalls++,
      now: () => now,
      isDemoBuild: demo,
      demoMode: false,
    );
    addTearDown(c.dispose);
    return c;
  }

  SignInFacts facts(
    String key, {
    bool isSignup = false,
    bool oldApp = false,
    bool welcomedElsewhere = false,
    int companies = 1,
  }) => SignInFacts(
    userKey: key,
    isSignup: isSignup,
    companyUserSettings: [
      if (oldApp) {'dashboard_fields_per_row_desktop': 3},
    ],
    reactSettings: [
      if (welcomedElsewhere) {kWelcomeReactSettingsKey: <String, dynamic>{}},
    ],
    companyCount: companies,
  );

  group('noteSignIn', () {
    test('an existing account is greeted on Get started', () {
      final c = controller()..noteSignIn(facts(alice));
      expect(c.autoOpens, isTrue);
      expect(c.currentKind, WelcomeKind.existingAccount);
      expect(c.onRequestKind, WelcomeKind.existingAccount);
    });

    test('a previous-app user is greeted on What\'s changed', () {
      final c = controller()..noteSignIn(facts(alice, oldApp: true));
      expect(c.autoOpens, isTrue);
      expect(c.onRequestKind, WelcomeKind.fromOldApp);
    });

    test('a sign-up never gets the Welcome — the wizard is theirs', () {
      final c = controller()..noteSignIn(facts(alice, isSignup: true));
      expect(c.currentKind, WelcomeKind.newAccount);
      expect(c.autoOpens, isFalse);
    });

    test('someone welcomed on another device is not greeted here', () {
      final c = controller()..noteSignIn(facts(alice, welcomedElsewhere: true));
      expect(c.autoOpens, isFalse);
      expect(c.state.users[alice]?.status, WelcomeStatus.seen);
    });

    test('the same user signing in again is not decided twice', () async {
      final c = controller()..noteSignIn(facts(alice));
      await c.markSeen();
      c.noteSignIn(facts(alice, oldApp: true));
      expect(c.autoOpens, isFalse);
    });

    test('a second user on the device is decided on their own', () async {
      final c = controller()..noteSignIn(facts(alice));
      await c.markSeen();
      signedIn = bob;
      c.noteSignIn(facts(bob));
      expect(c.autoOpens, isTrue);
      signedIn = alice;
      expect(c.autoOpens, isFalse);
    });

    test('a demo build decides nothing', () {
      final c = controller(demo: true)..noteSignIn(facts(alice));
      expect(c.state.users, isEmpty);
      expect(c.autoOpens, isFalse);
    });

    test('nothing is written before the store has read its rows', () async {
      final db = _WedgedDatabase();
      addTearDown(db.close);
      final broken = DevicePrefsStore(db);
      await expectLater(broken.load(), throwsStateError);
      final c = controller(store: broken)..noteSignIn(facts(alice));
      expect(c.state.users, isEmpty);
    });
  });

  group('noteLaunch', () {
    test('the user an existing install had signed in is not greeted', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: true, storedUserKey: alice);
      c.noteSignIn(facts(alice));
      expect(c.autoOpens, isFalse);
    });

    test('a fresh install leaves the next sign-in to decide', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: false, storedUserKey: null);
      c.noteSignIn(facts(alice));
      expect(c.autoOpens, isTrue);
    });

    test('a pending Welcome survives the next launch', () async {
      final c = controller()..noteSignIn(facts(alice));
      await c.noteLaunch(existingInstall: true, storedUserKey: alice);
      expect(c.autoOpens, isTrue);
    });
  });

  group('noteSetupCompleted', () {
    test('settles a new account and arms the checklist', () async {
      final c = controller()..noteSignIn(facts(alice, isSignup: true));
      await c.noteSetupCompleted(userKey: alice, companyId: 'c1');
      expect(c.state.users[alice]?.status, WelcomeStatus.seen);
      expect(c.showsChecklist('c1'), isTrue);
      expect(welcomedCalls, 1, reason: 'the server is told');
    });

    test('an account created from the login screen counts as new', () async {
      // Apple creates an account from the login screen; its one company is
      // unnamed, so it lands on /setup like a sign-up.
      final c = controller()..noteSignIn(facts(alice));
      await c.noteSetupCompleted(userKey: alice, companyId: 'c1');
      expect(c.autoOpens, isFalse);
      expect(c.currentKind, WelcomeKind.newAccount);
    });

    test('a long-standing user naming an old company keeps the Welcome', () {
      final c = controller()..noteSignIn(facts(alice, companies: 3));
      return c.noteSetupCompleted(userKey: alice, companyId: 'c9').then((_) {
        expect(c.autoOpens, isTrue);
        expect(c.showsChecklist('c9'), isTrue);
      });
    });

    test(
      'marks the launch, so no name dialog lands on the first dashboard',
      () async {
        final c = controller();
        expect(c.setupCompletedThisLaunch, isFalse);
        await c.noteSetupCompleted(userKey: null, companyId: 'c1');
        expect(c.setupCompletedThisLaunch, isTrue);
      },
    );

    test('only a new account\'s company is fresh', () async {
      // Fresh lets the dashboard's zero figures step back; an old company
      // named in /setup may have invoices this device hasn't downloaded.
      final c = controller()..noteSignIn(facts(alice, isSignup: true));
      await c.noteSetupCompleted(userKey: alice, companyId: 'new');
      expect(c.checklistFor('new')?.fresh, isTrue);
      signedIn = bob;
      c.noteSignIn(facts(bob, companies: 3));
      await c.noteSetupCompleted(userKey: bob, companyId: 'old');
      expect(c.checklistFor('old')?.fresh, isFalse);
    });

    test('a previous-app user keeps theirs', () async {
      final c = controller()..noteSignIn(facts(alice, oldApp: true));
      await c.noteSetupCompleted(userKey: alice, companyId: 'c1');
      expect(c.autoOpens, isTrue);
    });
  });

  group('attempts and holds', () {
    test('three launches that gave up stop the automatic open', () async {
      final c = controller()..noteSignIn(facts(alice));
      for (var i = 0; i < WelcomeController.maxAttempts; i++) {
        expect(c.autoOpens, isTrue);
        await c.noteGaveUp();
      }
      expect(c.autoOpens, isFalse);
    });

    test('a Welcome pending past a month is no longer a first run', () {
      final c = controller()..noteSignIn(facts(alice));
      now = noon.add(WelcomeController.pendingExpiry);
      expect(c.autoOpens, isFalse);
    });

    test('holds the other prompts while it may open, then a week', () async {
      final c = controller()..noteSignIn(facts(alice));
      expect(c.holdsBackPromptsAt(noon), isTrue);
      await c.noteOpened();
      await c.markSeen();
      expect(c.holdsBackPromptsAt(noon.add(const Duration(days: 6))), isTrue);
      expect(c.holdsBackPromptsAt(noon.add(const Duration(days: 8))), isFalse);
      expect(
        c.holdsBackPromptsAt(noon.subtract(const Duration(days: 1))),
        isFalse,
        reason: 'a clock moved back holds nothing',
      );
    });

    test('a Welcome that gave up holds nothing', () async {
      final c = controller()..noteSignIn(facts(alice));
      for (var i = 0; i < WelcomeController.maxAttempts; i++) {
        await c.noteGaveUp();
      }
      expect(c.holdsBackPromptsAt(noon), isFalse);
    });

    test('marking it seen tells the server and What\'s New', () async {
      final c = controller()..noteSignIn(facts(alice));
      await c.markSeen();
      expect(welcomedCalls, 1);
      expect(seenCalls, 1);
      expect(c.autoOpens, isFalse);
    });
  });

  group('checklist', () {
    test('hide, undo and complete', () async {
      final c = controller();
      await c.noteSetupCompleted(userKey: null, companyId: 'c1');
      await c.hideChecklist('c1');
      expect(c.showsChecklist('c1'), isFalse);
      await c.unhideChecklist('c1');
      expect(c.showsChecklist('c1'), isTrue);
      await c.noteChecklistCompleted('c1');
      expect(c.showsChecklist('c1'), isFalse);
    });

    test('a company setup never armed shows nothing', () {
      expect(controller().showsChecklist('c1'), isFalse);
    });

    test('remembers which ticks it drew', () async {
      final c = controller();
      await c.noteSetupCompleted(userKey: null, companyId: 'c1');
      await c.noteItemsShownDone('c1', {'business', 'logo'});
      expect(c.checklistFor('c1')?.doneShown, {'business', 'logo'});
    });
  });

  group('the record', () {
    test('round-trips through the store, and a sign-out keeps it', () async {
      final c = controller()..noteSignIn(facts(alice, oldApp: true));
      await c.noteSetupCompleted(userKey: null, companyId: 'c1');
      await c.noteOpened();
      final again = controller();
      expect(again.state, c.state);
      expect(DevicePrefKeys.welcome.scope, PrefScope.device);
    });

    test('an unreadable row reads as no record', () {
      expect(WelcomeState.decode('{nope'), const WelcomeState());
      expect(WelcomeState.decode('[1]'), const WelcomeState());
    });

    test('keeps at most maxUsers, dropping the oldest', () {
      var state = const WelcomeState();
      for (var i = 0; i < WelcomeController.maxUsers + 3; i++) {
        state = state.withUser(
          'k$i',
          WelcomeUser(
            status: WelcomeStatus.seen,
            at: noon.add(Duration(minutes: i)),
          ),
          WelcomeController.maxUsers,
        );
      }
      expect(state.users.length, WelcomeController.maxUsers);
      expect(state.users.containsKey('k0'), isFalse);
      expect(
        state.users.containsKey('k${WelcomeController.maxUsers + 2}'),
        isTrue,
      );
    });
  });
}
