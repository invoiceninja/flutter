import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/router.dart' show buildRouter;
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_settings_screen.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_templates_screen.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_users_screen.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_table.dart';

import '../../../_localization_helper.dart';
import '../shell/_shell_test_helpers.dart';

/// A session for the DocuNinja owner and admin, paired with the fixture's
/// first company, that never runs a handshake of its own.
class _Session extends DocuNinjaSession {
  _Session({int numUsers = 1})
    : super(
        loginApi: _NoLoginApi(),
        auth: ValueNotifier(null),
        companyKeyOf: (_) async => null,
      ) {
    final json =
        jsonDecode(
              File('test/fixtures/docuninja/login.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(json['data'] as Map? ?? json);
    data['company_user'] = {
      ...Map<String, dynamic>.from(data['company_user'] as Map),
      'is_admin': true,
      'is_owner': true,
    };
    data['account'] = {
      ...Map<String, dynamic>.from(data['account'] as Map? ?? const {}),
      'num_users': numUsers,
    };
    final login = DnLogin.fromJson(data);
    value = DocuNinjaState(
      DocuNinjaAccess.ready,
      login: login,
      company: login.companyFor('ninja-company-key-1'),
    );
  }

  @override
  Future<void> load({bool force = false}) async {}
}

class _NoLoginApi implements DocuNinjaLoginApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Api implements DocuNinjaApi {
  _Api({this.templates = const [], this.people = const [], this.seats = 0});

  final List<DnBlueprint> templates;
  final List<DnUser> people;

  /// The account's DocuNinja users, as the seat count reads them.
  final int seats;

  @override
  Future<DnPage<DnBlueprint>> blueprints({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = 'active',
  }) async => DnPage(
    items: templates,
    currentPage: 1,
    lastPage: 1,
    total: templates.length,
  );

  @override
  Future<DnPage<DnUser>> users({
    required String ninjaCompanyKey,
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = 'active',
  }) async => ninjaCompanyKey.isEmpty
      ? DnPage(items: const [], currentPage: 1, lastPage: 1, total: seats)
      : DnPage(
          items: people,
          currentPage: 1,
          lastPage: 1,
          total: people.length,
        );

  @override
  Future<List<DnEmailTemplate>> emailTemplates() async => [
    DnEmailTemplate.fromJson({
      'id': 't1',
      'name': 'Signature request',
      'subject': 'Please sign',
      'body': 'Body',
    }),
  ];

  @override
  Future<List<DnReminderSchedule>> reminderSchedules() async => const [];

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _GuardServices implements Services {
  _GuardServices(this.unsavedChangesGuard);

  @override
  final UnsavedChangesGuard unsavedChangesGuard;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DnBlueprint _template(String id, String name, {String? archivedAt}) =>
    DnBlueprint.fromJson({
      'id': id,
      'name': name,
      'archived_at': archivedAt,
      'design_hash': '',
    });

DnUser _user(String id, String first, String email, {bool deleted = false}) =>
    DnUser.fromJson({
      'id': id,
      'first_name': first,
      'last_name': 'Doe',
      'email': email,
      'is_deleted': deleted,
    });

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('Templates and Users tables', () {
    late ShellFixture fixture;

    Future<void> pump(
      WidgetTester tester,
      Widget screen, {
      required _Api api,
      DocuNinjaSession? session,
    }) async {
      fixture = await buildFixture(
        companies: [FakeCompany(id: 'co1', name: 'Acme')],
      );
      addTearDown(fixture.dispose);
      final s = session ?? _Session();
      addTearDown(s.dispose);
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Provider<DocuNinjaApi>.value(
            value: api,
            child: ChangeNotifierProvider<DocuNinjaSession?>.value(
              value: s,
              child: screen,
            ),
          ),
        ),
      );
      await _settle(tester);
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a wide pane draws React\'s template columns in a card, and '
        'a row\'s menu leads with Edit', (tester) async {
      _size(tester, 1200);
      await pump(
        tester,
        const DocuNinjaTemplatesScreen(),
        api: _Api(
          templates: [
            _template('b1', 'NDA'),
            _template('b2', 'Lease', archivedAt: '2026-01-01'),
          ],
        ),
      );
      expect(find.byType(DnTableHeader), findsOneWidget);
      for (final label in ['STATUS', 'NAME', 'TYPE']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byType(DecoratedSliver), findsOneWidget);
      expect(find.text('NDA'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final edit = tester.getTopLeft(find.text('Edit').last);
      final use = tester.getTopLeft(find.text('Use Template').last);
      expect(edit.dy, lessThan(use.dy), reason: 'Edit is the first item');
      await dispose(tester);
    });

    testWidgets('a narrow pane keeps the rows, and an empty wide table is '
        'one line inside the card', (tester) async {
      _size(tester, 400);
      await pump(
        tester,
        const DocuNinjaTemplatesScreen(),
        api: _Api(templates: [_template('b1', 'NDA')]),
      );
      expect(find.byType(DnTableHeader), findsNothing);
      expect(find.text('NDA'), findsOneWidget);
      await dispose(tester);

      _size(tester, 1200);
      await pump(tester, const DocuNinjaTemplatesScreen(), api: _Api());
      expect(find.byType(DnTableHeader), findsOneWidget);
      expect(find.byType(DnNoRecordsLine), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      await dispose(tester);
    });

    testWidgets('users: React\'s columns, New User in the AppBar, and the '
        'seat-limit alert when every seat is taken', (tester) async {
      _size(tester, 1200);
      await pump(
        tester,
        const DocuNinjaUsersScreen(),
        api: _Api(
          people: [
            _user('u1', 'Ann', 'ann@example.com'),
            _user('u2', 'Bob', 'bob@example.com', deleted: true),
          ],
          seats: 2,
        ),
        session: _Session(numUsers: 2),
      );
      for (final label in ['NAME', 'EMAIL', 'STATUS']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('ann@example.com'), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);
      // React's NumberOfUsersAlert, and the count beside the search.
      expect(find.text('Need more users? Upgrade your plan!'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Upgrade'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      // New User is the AppBar's `+`, off with no seat left.
      final add = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('New User'),
          matching: find.byType(IconButton),
        ),
      );
      expect(add.onPressed, isNull);
      await dispose(tester);
    });

    testWidgets('users: no alert while a seat is left', (tester) async {
      _size(tester, 1200);
      await pump(
        tester,
        const DocuNinjaUsersScreen(),
        api: _Api(people: [_user('u1', 'Ann', 'ann@example.com')], seats: 1),
        session: _Session(numUsers: 3),
      );
      expect(find.text('Need more users? Upgrade your plan!'), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
      final add = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('New User'),
          matching: find.byType(IconButton),
        ),
      );
      expect(add.onPressed, isNotNull);
      await dispose(tester);
    });
  });

  group('Settings tabs are sub-routes', () {
    EntityHandlers handlers(EntityType type, String routePath) =>
        EntityHandlers(
          type: type,
          wireName: type.name,
          apiPath: '/api/v1/${type.name}s',
          routePath: routePath,
          icon: Icons.business,
          dispatcher: DisabledEntityDispatcher(type),
        );

    /// The real app's `/docuninja/settings…` routes, under a bare
    /// `/docuninja`.
    List<RouteBase> settingsRoutes() {
      final app = buildRouter(
        isAuthenticated: () => true,
        postLoginRoute: () => '/clients',
        refreshListenable: ValueNotifier<int>(0),
        registry: EntityRegistry({
          for (final m in [...kWiredEntityModules, ...kDisabledEntityModules])
            m.type: m.toHandlers(DisabledEntityDispatcher(m.type)),
          EntityType.company: handlers(
            EntityType.company,
            '/settings/company_details',
          ),
          EntityType.user: handlers(EntityType.user, '/settings/account'),
        }, branchOrder: kBranchOrder),
      );
      addTearDown(app.dispose);
      GoRoute? docuninja(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute && r.path == '/docuninja') return r;
          final hit = docuninja(r.routes);
          if (hit != null) return hit;
        }
        return null;
      }

      return [
        for (final r in docuninja(app.configuration.routes)!.routes)
          if (r is GoRoute && r.path.startsWith('settings')) r,
      ];
    }

    Future<GoRouter> pump(WidgetTester tester, String location) async {
      _size(tester, 1200);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/docuninja',
            builder: (_, _) => const Scaffold(body: Text('DocuNinja home')),
            routes: settingsRoutes(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final session = _Session();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _GuardServices(UnsavedChangesGuard()),
          child: Provider<DocuNinjaApi>.value(
            value: _Api(),
            child: ChangeNotifierProvider<DocuNinjaSession?>.value(
              value: session,
              child: MaterialApp.router(
                theme: buildInTheme(InTheme.light),
                localizationsDelegates: kTestLocalizationsDelegates,
                supportedLocales: kTestSupportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    String location(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    TabController tabs(WidgetTester tester) =>
        tester.widget<TabBar>(find.byType(TabBar)).controller!;

    testWidgets('the bare page opens React\'s default tab, Email Templates', (
      tester,
    ) async {
      final router = await pump(tester, '/docuninja/settings');
      expect(location(router), '/docuninja/settings/email_templates');
      expect(tabs(tester).index, 1);
      // Save is in the AppBar, for the tab showing.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.widgetWithText(TextButton, 'Save'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tab opened by its address shows; picking another is its '
        'address, on the same page', (tester) async {
      final router = await pump(tester, '/docuninja/settings/notifications');
      expect(tabs(tester).index, 2);
      final screen = tester.state(find.byType(DocuNinjaSettingsScreen));

      await tester.tap(find.text('Email Settings'));
      await tester.pumpAndSettle();
      expect(location(router), '/docuninja/settings/email_settings');
      expect(tabs(tester).index, 0);
      // One page for every tab: the other tabs keep what they hold.
      expect(tester.state(find.byType(DocuNinjaSettingsScreen)), screen);

      router.go('/docuninja/settings/email_templates');
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 1);
    });

    testWidgets('an unknown tab opens the default one', (tester) async {
      final router = await pump(tester, '/docuninja/settings/nope');
      expect(location(router), '/docuninja/settings/email_templates');
    });

    testWidgets('a tab switch with unsaved edits asks nothing; leaving the '
        'page asks', (tester) async {
      final router = await pump(tester, '/docuninja/settings/email_settings');
      await tester.enterText(
        find.widgetWithText(TextField, 'From Name'),
        'Acme',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(location(router), '/docuninja/settings/notifications');

      router.go('/docuninja');
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });
}
