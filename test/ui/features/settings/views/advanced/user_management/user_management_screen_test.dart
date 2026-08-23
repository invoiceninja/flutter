// Regression + safety tests for invoiceninja/flutter#46 — "`owner` user
// doesn't appear in `Users`".
//
// The roster used to be stripped of the account owner and the logged-in user,
// both on the wire (`hideOwnerUsers=true&without=<authId>`) and again in the
// local Drift query. Showing them is only half the fix: the list has a bulk
// Archive / Delete bar, and the server does NOT protect the owner from
// deletion by a privileged caller — `DestroyUserRequest::authorize()` checks
// only that the *caller* is an owner, then `UserController::destroy` answers
// `401 "Cannot detach owner."`. A 401 in this app means forced logout plus a
// local DB wipe, and because the mutation drains through the outbox it lands
// seconds later, disconnected from the tap that caused it. So the guard tests
// below are load-bearing, not cosmetic.
//
// Fakes resolve everything from memory so the StreamBuilder settles
// synchronously — a real Drift watch stream makes `pumpAndSettle` hang.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management_screen.dart';

import '../../../../../../_localization_helper.dart';

class _FakeUserRepo implements UserRepository {
  _FakeUserRepo(this.rows);
  final List<User> rows;
  final archived = <String>[];
  final deleted = <String>[];

  /// Broadcast so a test can push a second emission (e.g. a `/refresh` that
  /// promotes someone to owner) after the screen has already subscribed.
  final _controller = StreamController<List<User>>.broadcast();
  void emit(List<User> next) => _controller.add(next);
  void dispose() => _controller.close();

  @override
  Stream<List<User>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = 'first_name',
    bool sortAscending = true,
  }) async* {
    yield rows;
    yield* _controller.stream;
  }

  // Returning false stops the screen's page 1..5 warm-up after one call.
  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    bool ignoreCursor = false,
  }) async => false;

  @override
  Future<void> archive({required String companyId, required String id}) async =>
      archived.add(id);

  @override
  Future<void> delete({required String companyId, required String id}) async =>
      deleted.add(id);

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
  _FakeServices({required this.auth, required this.user});
  @override
  final AuthRepository auth;
  @override
  final UserRepository user;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

User _user(String id, String first, String last, {bool isOwner = false}) =>
    const User().copyWith(
      id: id,
      firstName: first,
      lastName: last,
      email: '$id@example.com',
      companyUser: CompanyUser(isOwner: isOwner, isAdmin: true),
    );

void main() {
  late _FakeUserRepo repo;
  late _FakeServices services;

  final owner = _user('u_owner', 'Olivia', 'Owner', isOwner: true);
  final self = _user('u_self', 'Sam', 'Self');
  final staff = _user('u_staff', 'Riley', 'Staff');

  void wire(List<User> rows) {
    repo = _FakeUserRepo(rows);
    addTearDown(repo.dispose);
    services = _FakeServices(
      auth: _FakeAuth(
        ValueNotifier<AuthSession?>(
          const AuthSession(
            baseUrl: '',
            // Self-hosted ⇒ hasEnterpriseAccess, so the plan gate doesn't
            // disable the bulk bar under test.
            isHosted: false,
            accountId: '',
            companies: [],
            currentCompanyId: 'co',
            userId: 'u_self',
          ),
        ),
      ),
      user: repo,
    );
  }

  setUp(() => wire([owner, self, staff]));

  /// Records detail-screen navigations. A guarded row keeps its plain tap
  /// (viewing the owner is fine — bulk-deleting them is not), and with
  /// `onLongPress` null the long-press degrades to that tap, so the screen
  /// really does call `context.go` here. Without a router that throws.
  late List<String> visited;

  Future<void> pump(WidgetTester tester) async {
    final level = SettingsLevelController();
    addTearDown(level.dispose);
    visited = <String>[];
    final router = GoRouter(
      initialLocation: '/settings/users',
      routes: [
        GoRoute(
          path: '/settings/users',
          builder: (_, _) => const UserManagementScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) {
                visited.add(state.pathParameters['id']!);
                return const Scaffold(body: Text('detail'));
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: services),
          ChangeNotifierProvider<SettingsLevelController>.value(value: level),
        ],
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the owner and your own row are listed', (tester) async {
    await pump(tester);

    expect(find.text('Olivia Owner'), findsOneWidget);
    expect(find.text('Sam Self'), findsOneWidget);
    expect(find.text('Riley Staff'), findsOneWidget);
  });

  testWidgets('your own row is badged Current User, and only yours', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Current User'), findsOneWidget);
    // Owner + Current User are independent: Olivia is the owner, Sam is you.
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('a plain row can be selected for bulk actions', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('Riley Staff'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('the owner cannot be selected — long-press does nothing', (
    tester,
  ) async {
    await pump(tester);

    await tester.longPress(find.text('Olivia Owner'));
    await tester.pumpAndSettle();

    // No bulk bar ⇒ nothing entered the selection ⇒ bulk delete can never
    // reach the owner and trigger the 401 forced-logout path. The press falls
    // through to the row's plain tap instead, which opens their detail screen.
    expect(find.text('1 selected'), findsNothing);
    expect(visited, ['u_owner']);
  });

  testWidgets('your own row cannot be selected either', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('Sam Self'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets(
    'a user promoted to owner after being selected is dropped from the bulk '
    'action, not deleted',
    (tester) async {
      await pump(tester);

      await tester.longPress(find.text('Riley Staff'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // A `/refresh` lands and Riley is now the account owner. The selection
      // still holds the object captured at tap time, so unless the screen
      // re-reads it from the stream the guard sees a stale `isOwner == false`
      // and deletes the owner — 401, forced logout, local DB wipe.
      repo.emit([
        owner,
        self,
        _user('u_staff', 'Riley', 'Staff', isOwner: true),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      // Accept the confirm dialog if one appears at all. Today it doesn't —
      // the filter empties the batch first — but the assertion below is about
      // what got deleted, not about which guard stopped it.
      final confirm = find.widgetWithText(FilledButton, 'Delete');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm.last);
        await tester.pumpAndSettle();
      }

      expect(repo.deleted, isEmpty);
    },
  );

  testWidgets(
    'with a selection active, guarded rows show a disabled checkbox',
    (tester) async {
      await pump(tester);

      await tester.longPress(find.text('Riley Staff'));
      await tester.pumpAndSettle();

      final boxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList(growable: false);
      // One per row; only the selectable one accepts input.
      expect(boxes, hasLength(3));
      expect(boxes.where((c) => c.onChanged != null), hasLength(1));
    },
  );

  // Regression tests for invoiceninja/flutter#47 — "a user who is `Pending
  // invite` should not have any `Activity` displayed".
  //
  // The reported symptom was #45 (every user's Activity section listed the
  // whole company feed), already fixed. What survived it was the label: the
  // roster badged anyone with a null `email_verified_at` as "Pending invite",
  // and that flag is *also* null for an owner who never clicked the verify
  // email — which on hosted can be forever, since `CreateUser` back-dates the
  // column only on self-host — for anyone who has ever changed their email
  // address, and for pre-2021 self-hosted owners. Those people are active, so
  // the badge sat next to a live audit trail and read as a breach.
  //
  // The row now says only what the flag supports: verification is pending.
  // It is deliberately NOT suppressed per-platform — the invite path
  // (`POST /users` → `UserFactory::create`) leaves the column null on hosted
  // and self-hosted alike, so hiding it anywhere would drop a real signal.
  group('unconfirmed-email badge (flutter#47)', () {
    User verified(User u) => u.copyWith(emailVerifiedAt: 1787472002);

    testWidgets('an unconfirmed row says verification is pending', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Verification Pending'), findsNWidgets(3));
      // Never the old claim: nobody here was necessarily invited at all.
      expect(find.text('Pending invite'), findsNothing);
    });

    testWidgets('a confirmed row gets no badge', (tester) async {
      wire([verified(owner), verified(self), verified(staff)]);

      await pump(tester);

      expect(find.text('Verification Pending'), findsNothing);
    });

    testWidgets('a multi-badge row does not balloon the roster', (
      tester,
    ) async {
      // Adding a second badge to every row is what surfaced this: `ListTile`
      // lays `trailing` out in whatever width the avatar, title and subtitle
      // leave, so a Wrap of badges there breaks onto its own runs and drags
      // the row's height along — and a long translated label wraps inside its
      // own chip on top of that. Sam's three-badge row measured ~410 px and
      // pushed Riley clean off an 800x600 screen. Latent before #47 too:
      // a hosted user viewing their own unconfirmed row already had three.
      await pump(tester);

      final heights = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byType(ListTile).at(i)).height,
      ];
      expect(
        heights.every((h) => h < 140),
        isTrue,
        reason: 'a row grew out of proportion — heights: $heights',
      );
      // The load-bearing consequence: the last row is still on screen, so it
      // can still be tapped, long-pressed and bulk-selected.
      expect(tester.getCenter(find.text('Riley Staff')).dy, lessThan(600));
    });

    testWidgets('badges only the rows that are actually unconfirmed', (
      tester,
    ) async {
      wire([verified(owner), self, verified(staff)]);

      await pump(tester);

      expect(find.text('Verification Pending'), findsOneWidget);
      // Sanity: all three rows rendered, so the single badge is selectivity
      // and not a truncated list.
      expect(find.text('Olivia Owner'), findsOneWidget);
      expect(find.text('Riley Staff'), findsOneWidget);
    });
  });
}
