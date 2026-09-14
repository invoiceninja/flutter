// The Device Settings card for "Hide unverified users"
// (invoiceninja/flutter#150).
//
// Worth pumping where its sibling `ListStatusTabsSection` is not, because this
// one is data-bound: the count line is the ONLY place in the app that shows the
// preference's effect (there is deliberately no marker inside the picker
// popover), and Device Settings has no widget test of its own, so nothing else
// would catch a broken stream here.

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
import 'package:admin/ui/features/settings/widgets/assigned_users_section.dart';

import '../../../../_localization_helper.dart';

User _user(
  String id, {
  String first = '',
  int emailVerifiedAt = 1700000000,
  bool hasPassword = true,
  bool isOwner = false,
}) => const User().copyWith(
  id: id,
  firstName: first,
  emailVerifiedAt: emailVerifiedAt,
  hasPassword: hasPassword,
  companyUser: CompanyUser(isOwner: isOwner),
);

User _invitee(String id, {String first = ''}) =>
    _user(id, first: first, emailVerifiedAt: 0, hasPassword: false);

class _FakeUsers implements UserRepository {
  _FakeUsers(this.roster);
  final List<User> roster;

  @override
  Stream<List<User>> watchAllForPicker({required String companyId}) =>
      Stream<List<User>>.multi((c) {
        c.add(roster);
        c.close();
      });

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

void main() {
  late AppDatabase db;
  late HideUnverifiedUsersController controller;

  setUpAll(() => db = AppDatabase(NativeDatabase.memory()));
  tearDownAll(() => db.close());
  setUp(() => controller = HideUnverifiedUsersController(db: db));

  Future<void> pump(
    WidgetTester tester, {
    required List<User> roster,
    String companyId = 'co',
  }) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          _FakeUsers(roster),
          _FakeAuth(
            ValueNotifier<AuthSession?>(
              AuthSession(
                baseUrl: '',
                isHosted: false,
                accountId: '',
                companies: const [],
                currentCompanyId: companyId,
                userId: 'me',
              ),
            ),
          ),
          controller,
        ),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: AssignedUsersSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the switch renders off by default', (tester) async {
    await pump(tester, roster: [_user('u1', first: 'Ada')]);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('an all-verified roster shows no count line', (tester) async {
    // The absence is the honest answer: it is what tells a single-user or
    // all-verified account that this switch will do nothing.
    await pump(
      tester,
      roster: [
        _user('u1', first: 'Ada'),
        _user('u2', first: 'Bob'),
      ],
    );
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('the card itself never collapses', (tester) async {
    // Only the count line may disappear. `phone_actions_section.dart` states
    // the rule: a control worth seeing renders anyway, because a disappearing
    // one reads as a bug.
    await pump(tester, roster: const []);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('off — the count describes what the switch would do', (
    tester,
  ) async {
    await pump(
      tester,
      roster: [
        _user('u1', first: 'Ada'),
        _invitee('u2', first: 'Bob'),
      ],
    );
    expect(find.text('1 user would be hidden'), findsOneWidget);
  });

  testWidgets('on — the count describes what it is doing', (tester) async {
    controller.value = true;
    await pump(
      tester,
      roster: [
        _user('u1', first: 'Ada'),
        _invitee('u2', first: 'Bob'),
        _invitee('u3', first: 'Cleo'),
      ],
    );
    expect(find.text('2 users hidden from assignee fields'), findsOneWidget);
  });

  testWidgets('the count exempts the owner and the signed-in user', (
    tester,
  ) async {
    await pump(
      tester,
      roster: [
        _user('u1', first: 'Olive', emailVerifiedAt: 0, isOwner: true),
        _invitee('me', first: 'Me'),
        _invitee('u3', first: 'Bob'),
      ],
    );
    expect(find.text('1 user would be hidden'), findsOneWidget);
  });

  testWidgets('no company means no count line', (tester) async {
    await pump(tester, roster: [_invitee('u1')], companyId: '');
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
  testWidgets('tapping the switch writes through the controller', (
    tester,
  ) async {
    // Every other case here drives `controller.value` directly, so without this
    // one `onChanged: controller.set` could be a no-op and the file stays green
    // while the preference never persists.
    await pump(tester, roster: [_user('u1', first: 'Ada')]);
    expect(controller.value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(controller.value, isTrue);
  });
}
