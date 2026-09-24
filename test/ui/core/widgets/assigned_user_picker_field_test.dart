// The roster query behind every "Assigned User" field. It had been hand-copied
// into five call sites in two incompatible shapes; this is the one home, so
// these are the rules that used to be re-argued (or lost) per copy.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:drift/native.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/hide_unverified_users_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/core/widgets/assigned_user_picker_field.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

import '../../../_localization_helper.dart';

/// `Stream.multi`, not `Stream.value`: `EntityPickerField` re-subscribes to
/// `watchById` on every `selectedId` change, and a single-subscription stream
/// throws the second time — the finding `_task_filter_doubles.dart` records.
Stream<T> _oneShot<T>(T value) => Stream<T>.multi((c) {
  c.add(value);
  c.close();
});

User _user(
  String id, {
  String first = '',
  String last = '',
  int archivedAt = 0,
  bool isDeleted = false,
  // Defaults describe an ordinary, fully-onboarded colleague, so a test that
  // says nothing about verification gets a user the hide rule never touches.
  int emailVerifiedAt = 1700000000,
  bool hasPassword = true,
  String oauthProviderId = '',
  String lastConfirmedEmailAddress = '',
  bool isOwner = false,
}) => const User().copyWith(
  id: id,
  firstName: first,
  lastName: last,
  archivedAt: archivedAt,
  isDeleted: isDeleted,
  emailVerifiedAt: emailVerifiedAt,
  hasPassword: hasPassword,
  oauthProviderId: oauthProviderId,
  lastConfirmedEmailAddress: lastConfirmedEmailAddress,
  companyUser: CompanyUser(isOwner: isOwner),
);

/// An invited user who never accepted — the one shape the hide rule catches.
User _neverOnboarded(String id, {String first = '', String last = ''}) =>
    _user(id, first: first, last: last, emailVerifiedAt: 0, hasPassword: false);

class _FakeUsers implements UserRepository {
  _FakeUsers(this.roster, {this.byId = const <String, User>{}});

  final List<User> roster;

  /// Deliberately separate from [roster]: the whole point of the widget is that
  /// a selection outside the offered list still resolves.
  final Map<String, User> byId;

  @override
  Stream<List<User>> watchAllForPicker({required String companyId}) =>
      _oneShot(roster);

  @override
  Stream<User?> watch({required String companyId, required String id}) =>
      _oneShot(byId[id] ?? roster.where((u) => u.id == id).firstOrNull);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.user, this.auth, this.hideUnverifiedUsers);

  @override
  final UserRepository user;

  @override
  final AuthRepository auth;

  @override
  final HideUnverifiedUsersController hideUnverifiedUsers;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

AuthSession _session(String userId) => AuthSession(
  baseUrl: '',
  isHosted: false,
  accountId: '',
  companies: const [],
  currentCompanyId: 'co',
  userId: userId,
);

void main() {
  late List<String> changes;
  late AppDatabase db;
  late HideUnverifiedUsersController hideUnverified;

  // The controller needs an `AppDatabase` for `restore()` / `set()`, neither of
  // which this widget ever calls — it only reads `.value` and listens. One
  // in-memory database for the file is cheaper than faking the type, and no
  // Drift stream is ever opened on it (`pumpAndSettle` over a real one hangs).
  setUpAll(() => db = AppDatabase(NativeDatabase.memory()));
  tearDownAll(() => db.close());
  late ValueNotifier<AuthSession?> sessionNotifier;

  setUp(() {
    hideUnverified = HideUnverifiedUsersController(prefs: DevicePrefsStore(db));
    sessionNotifier = ValueNotifier<AuthSession?>(null);
  });

  Future<void> pump(
    WidgetTester tester, {
    required List<User> roster,
    String selectedId = '',
    Map<String, User> byId = const <String, User>{},
    String signedInUserId = 'me',
    String labelKey = 'assigned_user',
  }) async {
    changes = <String>[];
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          _FakeUsers(roster, byId: byId),
          _FakeAuth(sessionNotifier..value = _session(signedInUserId)),
          hideUnverified,
        ),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: AssignedUserPickerField(
                companyId: 'co',
                selectedId: selectedId,
                onChanged: changes.add,
                labelKey: labelKey,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  group('hide unverified users (invoiceninja/flutter#150)', () {
    testWidgets('off by default — an un-onboarded user is still offered', (
      tester,
    ) async {
      await pump(
        tester,
        roster: [
          _user('u1', first: 'Ada', last: 'Lovelace'),
          _neverOnboarded('u2', first: 'Bob', last: 'Invitee'),
        ],
      );
      await openOptions(tester);

      expect(find.text('Bob Invitee'), findsOneWidget);
    });

    testWidgets('on — the un-onboarded user is dropped', (tester) async {
      hideUnverified.value = true;
      await pump(
        tester,
        roster: [
          _user('u1', first: 'Ada', last: 'Lovelace'),
          _neverOnboarded('u2', first: 'Bob', last: 'Invitee'),
        ],
      );
      await openOptions(tester);

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Bob Invitee'), findsNothing);
    });

    testWidgets('the account owner is never dropped', (tester) async {
      hideUnverified.value = true;
      await pump(
        tester,
        roster: [
          _user('u1', first: 'Ada', last: 'Lovelace'),
          // Unverified *and* password-less, but an owner: an OAuth signup
          // produces exactly this, and #46 settled that the owner stays
          // assignable app-wide.
          _user(
            'u2',
            first: 'Olive',
            last: 'Owner',
            emailVerifiedAt: 0,
            hasPassword: false,
            isOwner: true,
          ),
        ],
      );
      await openOptions(tester);

      expect(find.text('Olive Owner'), findsOneWidget);
    });

    testWidgets('the signed-in user is never dropped', (tester) async {
      hideUnverified.value = true;
      await pump(
        tester,
        // `_persistAndActivate` hand-builds your own row without
        // `email_verified_at` or `has_password`, so after a delta refresh you
        // look exactly like an un-accepted invite to yourself.
        roster: [_neverOnboarded('me', first: 'Me', last: 'Myself')],
        signedInUserId: 'me',
      );
      await openOptions(tester);

      expect(find.text('Me Myself'), findsOneWidget);
    });

    testWidgets('a signed-in id that arrives late still exempts you', (
      tester,
    ) async {
      // `AuthRepository.restore()` starts `userId` empty and leaves it that way
      // when the restored company's `user_settings` row is missing or its
      // lookup throws, so a mounted picker can genuinely see `''` first. With
      // no self-exemption *you* satisfy every conjunct — `_persistAndActivate`
      // writes your own row without `email_verified_at`, `has_password` or
      // `last_confirmed_email_address` — and vanish from your own field. Only a
      // listener on the session can heal that; the `cacheKey` alone cannot,
      // because nothing would rebuild the widget.
      hideUnverified.value = true;
      await pump(
        tester,
        roster: [
          _user('u1', first: 'Ada', last: 'Lovelace'),
          _neverOnboarded('me', first: 'Me', last: 'Myself'),
        ],
        signedInUserId: '',
      );

      // Pushed with the popover CLOSED, for the reason the flip test above
      // records: `RawAutocomplete` recomputes its options only on a text
      // change, so an overlay that is already open keeps the list it was built
      // with. Without the session listener the widget never rebuilds at all,
      // `meId` stays `''`, and this row stays filtered out.
      sessionNotifier.value = _session('me');
      await tester.pumpAndSettle();

      await openOptions(tester);
      expect(find.text('Me Myself'), findsOneWidget);
    });

    testWidgets('a currently-assigned hidden user still renders', (
      tester,
    ) async {
      hideUnverified.value = true;
      final bob = _neverOnboarded('u2', first: 'Bob', last: 'Invitee');
      await pump(
        tester,
        roster: [_user('u1', first: 'Ada', last: 'Lovelace')],
        selectedId: 'u2',
        byId: {'u2': bob},
      );

      // `EntityPickerField` resolves the selection through `watchById` and
      // splices it back in, so narrowing the list can never blank a form that
      // holds a value.
      expect(find.text('Bob Invitee'), findsOneWidget);
    });

    testWidgets('flipping the switch while mounted re-filters the list', (
      tester,
    ) async {
      await pump(
        tester,
        roster: [
          _user('u1', first: 'Ada', last: 'Lovelace'),
          _neverOnboarded('u2', first: 'Bob', last: 'Invitee'),
        ],
      );
      // An edit screen stays mounted behind `/settings/**` while the switch is
      // flipped, so the picker has to listen rather than read once — it was
      // pumped with the preference off and must rebuild to see it on.
      //
      // Flipped with the popover CLOSED deliberately: `RawAutocomplete`
      // recomputes its options only on a text change, so an overlay that is
      // already open keeps the list it was built with whatever `items` does.
      // Re-opening is the path a real user takes (flip in Settings, come back,
      // open the field), and it is the one this can honestly assert.
      hideUnverified.value = true;
      await tester.pumpAndSettle();

      await openOptions(tester);
      expect(find.text('Bob Invitee'), findsNothing);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });
  });

  testWidgets('labelKey overrides the field label', (tester) async {
    // `billing_doc_settings_tab.dart` is the only host that passes one, and
    // that call site is pinned by `assigned_user_picker_wiring_test.dart`;
    // this proves the parameter is actually wired to the label.
    await pump(
      tester,
      roster: [_user('u1', first: 'Ada')],
      labelKey: 'user',
    );
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Assigned User'), findsNothing);
  });

  testWidgets('archived and soft-deleted users are not offered', (
    tester,
  ) async {
    await pump(
      tester,
      roster: [
        _user('u1', first: 'Ada', last: 'Lovelace'),
        // `archivedAt` is an int epoch, 0 = not archived — never null. An
        // `== null` test analyzes as dead code and filters the roster to
        // nothing, which is why this is asserted rather than assumed.
        _user('u2', first: 'Bob', last: 'Archived', archivedAt: 1700000000),
        _user('u3', first: 'Cleo', last: 'Deleted', isDeleted: true),
      ],
    );
    await openOptions(tester);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Bob Archived'), findsNothing);
    expect(find.text('Cleo Deleted'), findsNothing);
  });

  testWidgets('options are alphabetical, with the id breaking a name tie', (
    tester,
  ) async {
    await pump(
      tester,
      roster: [
        _user('u9', first: 'Zoe', last: 'Zeta'),
        // `watchAllForPicker` applies no ORDER BY, so without the sort this
        // list is in rowid order.
        _user('u5', first: 'Sam', last: 'Same'),
        _user('u2', first: 'Sam', last: 'Same'),
        _user('u1', first: 'Ada', last: 'Lovelace'),
      ],
    );
    await openOptions(tester);

    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(
      y(find.text('Ada Lovelace')),
      lessThan(y(find.text('Sam Same').at(0))),
    );
    expect(y(find.text('Sam Same').at(1)), lessThan(y(find.text('Zoe Zeta'))));
    // The id tiebreak, proved by which row the first `Sam Same` actually is:
    // `List.sort` is not stable in Dart, so without it the two would swap
    // places between Drift emissions and reorder the list under the user's
    // finger.
    await tester.tap(find.text('Sam Same').at(0));
    await tester.pumpAndSettle();
    expect(changes, ['u2']);
  });

  testWidgets('a nameless user renders its id, never a blank row', (
    tester,
  ) async {
    await pump(tester, roster: [_user('u7', first: '   ')]);
    await openOptions(tester);

    // `(no name)` is wrong here: a repeated `(no name)` cannot tell two
    // nameless rows apart in a list you must pick from.
    expect(find.text('u7'), findsWidgets);
  });

  testWidgets('a selection outside the offered roster still renders', (
    tester,
  ) async {
    // The archived assignee: dropped from `watchAllForPicker`, so a picker that
    // scans the list would blank the field WITHOUT firing `onChanged`, and the
    // form would silently lose an assignment it still holds.
    await pump(
      tester,
      roster: [_user('u1', first: 'Ada', last: 'Lovelace')],
      selectedId: 'gone',
      byId: {
        'gone': _user('gone', first: 'Zoe', last: 'Archived', archivedAt: 1),
      },
    );

    expect(find.text('Zoe Archived'), findsOneWidget);
    expect(changes, isEmpty);
  });

  testWidgets('clearing reports an empty id', (tester) async {
    await pump(
      tester,
      roster: [_user('u1', first: 'Ada', last: 'Lovelace')],
      selectedId: 'u1',
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(changes, ['']);
  });

  testWidgets('an empty roster reads as loading, not as "no records"', (
    tester,
  ) async {
    // Deliberately no `emptyHintKey`: the roster arrives bundled on `/refresh`
    // and always holds at least the signed-in user, so empty really is a
    // loading state. Its Project and Client siblings pass `no_records_found`
    // because a company can genuinely have none.
    await pump(tester, roster: const <User>[]);

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('No records found'), findsNothing);
  });
}
