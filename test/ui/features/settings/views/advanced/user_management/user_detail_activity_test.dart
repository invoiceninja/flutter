// Regression tests for invoiceninja/flutter#45 — "All Activity shown in a user
// in User Management is incorrectly attributed to every user".
//
// The screen used to hand `ActivityFormatter` a `seedLabels: {'user': <the
// viewed user's name>}`, trusting the (ignored) `?user_id=` server filter to
// have made the feed actor-scoped. It hadn't, so every row in the whole
// company feed was rendered under whichever user was on screen.
//
// Fakes resolve the user watch from an in-memory map so the StreamBuilder
// settles synchronously — no Drift stream, no `pumpAndSettle` timeout (see
// test/ui/core/widgets/user_name_label_test.dart, same pattern).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/views/user_detail_screen.dart';

import '../../../../../../_localization_helper.dart';

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this.byId);
  final Map<String, User> byId;
  @override
  Stream<User?> watch({required String companyId, required String id}) =>
      Stream<User?>.value(byId[id]);
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

/// Stands in for the real API, which already filters by actor. Returns
/// whatever rows the test declares for the requested id.
class _FakeActivitiesApi implements ActivitiesApi {
  _FakeActivitiesApi(this.byUser);
  final Map<String, List<DashboardActivity>> byUser;
  final requested = <String>[];

  @override
  Future<List<DashboardActivity>> fetchUserActivities(
    String userId, {
    int scanRows = kUserActivityScanRows,
    int limit = 50,
  }) async {
    requested.add(userId);
    return byUser[userId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({
    required this.auth,
    required this.user,
    required this.activities,
  });
  @override
  final AuthRepository auth;
  @override
  final UserRepository user;
  @override
  final ActivitiesApi activities;
  // Explicit: a bare noSuchMethod would throw where the screen expects null.
  @override
  Formatter? formatterIfReady(String companyId) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A `?reactv2` row carrying its own actor label — the shape the fixed
/// `fetchUserActivities` returns.
DashboardActivity _row({
  required String id,
  required String userId,
  required String userLabel,
  String invoiceLabel = '0026',
}) => DashboardActivity.fromJson({
  'user': {'label': userLabel, 'hashed_id': userId},
  'invoice': {'label': invoiceLabel, 'hashed_id': 'inv_$id'},
  'client': {'label': 'Acme', 'hashed_id': 'cli_$id'},
  'activity_type_id': 4, // ":user created invoice :invoice"
  'id': id,
  'notes': '',
  'created_at': 1778990481,
  'ip': '192.0.2.1',
});

/// A row with **no** `user` label — the flat-transformer shape, and the exact
/// case that produced #45: with nothing to render `:user` from, the screen used
/// to substitute the viewed user's name.
DashboardActivity _unlabelledRow({
  required String id,
  required String userId,
}) => DashboardActivity.fromJson({
  'user_id': userId,
  'invoice_id': 'inv_$id',
  'activity_type_id': 4,
  'id': id,
  'notes': '',
  'created_at': 1778990481,
});

User _user(String id, String first, String last) =>
    const User().copyWith(id: id, firstName: first, lastName: last);

void main() {
  late _FakeActivitiesApi api;
  late _FakeServices services;

  setUp(() {
    api = _FakeActivitiesApi({
      'u1': [
        _row(
          id: '1',
          userId: 'u1',
          userLabel: 'Ada Lovelace',
          invoiceLabel: '0026',
        ),
        _unlabelledRow(id: '9', userId: 'u1'),
      ],
      'u2': [
        _row(
          id: '2',
          userId: 'u2',
          userLabel: 'Grace Hopper',
          invoiceLabel: '0027',
        ),
      ],
    });
    services = _FakeServices(
      auth: _FakeAuth(
        ValueNotifier<AuthSession?>(
          const AuthSession(
            baseUrl: '',
            isHosted: false,
            accountId: '',
            companies: [],
            currentCompanyId: 'co',
            userId: 'admin',
          ),
        ),
      ),
      user: _FakeUserRepo({
        'u1': _user('u1', 'Zoe', 'Viewer'),
        'u2': _user('u2', 'Grace', 'Hopper'),
      }),
      activities: api,
    );
  });

  Future<void> pump(WidgetTester tester, String id) async {
    final level = SettingsLevelController();
    addTearDown(level.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: services),
          // SettingsScreenScaffold renders a SettingsScopeBanner that watches
          // this; without it the banner throws and the scaffold's Column
          // overflows on the substituted error widget.
          ChangeNotifierProvider<SettingsLevelController>.value(value: level),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          // No key — this is exactly how go_router builds the screen, which is
          // what let a stale feed survive a user → user navigation.
          home: UserDetailScreen(id: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('each row names its own actor, not the user being viewed', (
    tester,
  ) async {
    await pump(tester, 'u1');

    // The row was performed by Ada; the screen belongs to Zoe Viewer.
    expect(find.textContaining('Ada Lovelace created'), findsOneWidget);
    // And the entity token resolves to a real number, not the noun "Invoice".
    expect(find.textContaining('0026'), findsOneWidget);

    // The discriminating assertion. A row that names no actor must fall back
    // to the localized noun — never to whoever's page this is. Seeding the
    // viewed user here is precisely what #45 was. Match on the whole sentence:
    // the bare name legitimately renders once, in the Details `name` row.
    expect(find.textContaining('Zoe Viewer created'), findsNothing);
    expect(find.text('User created invoice Invoice'), findsOneWidget);
  });

  testWidgets('the viewed user still owns the details row', (tester) async {
    await pump(tester, 'u1');

    // Guard against the assertion above passing for the wrong reason: the
    // name does render on this screen — as the Details `name` row — just never
    // as the actor of an activity.
    expect(find.text('Zoe Viewer'), findsOneWidget);
  });

  testWidgets('refetches when the id changes under a reused element', (
    tester,
  ) async {
    await pump(tester, 'u1');
    expect(find.textContaining('Ada Lovelace created'), findsOneWidget);

    await pump(tester, 'u2');

    expect(api.requested, ['u1', 'u2']);
    expect(find.textContaining('Grace Hopper created'), findsOneWidget);
    expect(find.textContaining('Ada Lovelace created'), findsNothing);
  });

  testWidgets('an actor with no rows gets the empty state', (tester) async {
    services = _FakeServices(
      auth: services.auth,
      user: services.user,
      activities: _FakeActivitiesApi(const {}),
    );

    await pump(tester, 'u1');

    expect(find.text('No records found'), findsOneWidget);
  });
}
