import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/router.dart' show buildRouter;
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_document_screen.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_documents_list.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_download.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_status_pill.dart';
import 'package:admin/utils/bidi.dart';

import '../shell/_shell_test_helpers.dart';

class _Api implements DocuNinjaApi {
  _Api(this.doc);

  DnDocument doc;

  @override
  Future<DnDocument> document(String id) async => doc;

  @override
  Future<List<DnTimelineEntry>> timeline(String id) async => const [];

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A real document (captured live), unwrapped from its `data` envelope.
class _ListApi implements DocuNinjaApi {
  final pages = <int>[];

  @override
  Future<DnPage<DnDocument>> documents({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = '',
    String sort = 'id|desc',
  }) async {
    pages.add(page);
    return DnPage(
      items: [
        for (var i = 0; i < 2; i++)
          DnDocument.fromJson({'id': 'd$page-$i', 'status_id': 1}),
      ],
      currentPage: page,
      lastPage: 3,
      total: 6,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _fixture() {
  final json =
      jsonDecode(
            File('test/fixtures/docuninja/document.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return Map<String, dynamic>.from(json['data'] as Map? ?? json);
}

DnDocument _doc({int status = 5, bool deleted = false, bool files = true}) {
  final json = _fixture()
    ..['status_id'] = status
    ..['is_deleted'] = deleted;
  if (!files) json['files'] = <Object>[];
  return DnDocument.fromJson(json);
}

/// A session answered with [admin] or a view-only role, that never runs a
/// handshake of its own.
class _Session extends DocuNinjaSession {
  _Session({required bool admin})
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
      'is_admin': admin,
      'is_owner': admin,
    };
    data['permissions'] = [
      {'model': 'documents', 'permission_id': 1, 'permissionable_id': null},
    ];
    value = DocuNinjaState(
      DocuNinjaAccess.ready,
      login: DnLogin.fromJson(data),
    );
  }

  @override
  Future<void> load({bool force = false}) async {}
}

class _NoLoginApi implements DocuNinjaLoginApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The DocuNinja document page (`/docuninja/:id`): which of React's actions
/// it offers, which of them ask first, and that its route is keyed by id.
void main() {
  group('route', () {
    EntityHandlers handlers(EntityType type, String routePath) =>
        EntityHandlers(
          type: type,
          wireName: type.name,
          apiPath: '/api/v1/${type.name}s',
          routePath: routePath,
          icon: Icons.business,
          dispatcher: DisabledEntityDispatcher(type),
        );

    GoRoute? find(List<RouteBase> routes, String path, String child) {
      for (final r in routes) {
        if (r is GoRoute && r.path == path) {
          for (final c in r.routes) {
            if (c is GoRoute && c.path == child) return c;
          }
        }
        final hit = find(r.routes, path, child);
        if (hit != null) return hit;
      }
      return null;
    }

    testWidgets('a document page is keyed by its id', (tester) async {
      final router = buildRouter(
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
      addTearDown(router.dispose);
      final route = find(router.configuration.routes, '/docuninja', ':id')!;
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      Widget built(String id) => route.builder!(
        context,
        GoRouterState(
          router.configuration,
          uri: Uri.parse('/docuninja/$id'),
          matchedLocation: '/docuninja/$id',
          fullPath: '/docuninja/:id',
          pathParameters: {'id': id},
          // go_router's own page key is the pattern, the same for every id.
          pageKey: const ValueKey('/docuninja/:id'),
        ),
      );
      // Going to a clone must build a new page, not reuse the original's
      // State and view model.
      expect(built('a').key, isNot(built('b').key));
      expect(built('a').key, built('a').key);
    });
  });

  group('actions', () {
    late ShellFixture fixture;

    Future<void> pump(
      WidgetTester tester,
      DnDocument doc, {
      DocuNinjaSession? session,
    }) async {
      fixture = await buildFixture(
        companies: [FakeCompany(id: 'co1', name: 'Acme')],
      );
      addTearDown(fixture.dispose);
      const screen = DocuNinjaDocumentScreen(id: 'doc1');
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Provider<DocuNinjaApi>.value(
            value: _Api(doc),
            child: session == null
                ? screen
                : ChangeNotifierProvider<DocuNinjaSession?>.value(
                    value: session,
                    child: screen,
                  ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    IconButton editButton(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Edit'),
        matching: find.byType(IconButton),
      ),
    );

    testWidgets('a view-only DocuNinja role is offered nothing it would be '
        'refused', (tester) async {
      final viewer = _Session(admin: false);
      addTearDown(viewer.dispose);
      await pump(tester, _doc(status: 5), session: viewer);
      expect(find.byTooltip('Edit'), findsNothing);
      await openMenu(tester);
      for (final label in ['Clone', 'Void', 'Archive', 'Delete', 'Options']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      await dispose(tester);

      final admin = _Session(admin: true);
      addTearDown(admin.dispose);
      await pump(tester, _doc(status: 5), session: admin);
      expect(find.byTooltip('Edit'), findsOneWidget);
      await openMenu(tester);
      for (final label in ['Clone', 'Void', 'Archive', 'Delete']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await dispose(tester);
    });

    testWidgets('Edit (the builder) is beside the menu until completed', (
      tester,
    ) async {
      await pump(tester, _doc(status: 1));
      expect(editButton(tester).onPressed, isNotNull);
      await dispose(tester);

      await pump(tester, _doc(status: 6));
      expect(
        editButton(tester).onPressed,
        isNull,
        reason: 'React disables Edit on a completed or voided document',
      );
      await dispose(tester);
    });

    testWidgets('View PDF needs a completed document with a file', (
      tester,
    ) async {
      await pump(tester, _doc(status: 6));
      await openMenu(tester);
      expect(find.text('View PDF'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('View PDF is not offered on a deleted document', (
      tester,
    ) async {
      await pump(tester, _doc(status: 6, deleted: true));
      await openMenu(tester);
      expect(find.text('View PDF'), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('nor on one without files', (tester) async {
      await pump(tester, _doc(status: 6, files: false));
      await openMenu(tester);
      expect(find.text('Download'), findsOneWidget, reason: 'menu is open');
      expect(find.text('View PDF'), findsNothing);
      await dispose(tester);
    });

    testWidgets('Archive asks first, with React\'s question', (tester) async {
      await pump(tester, _doc());
      await openMenu(tester);
      await tester.tap(find.text('Archive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Are you sure you want to archive this document?'),
        findsOneWidget,
      );
      await dispose(tester);
    });

    testWidgets('Clone asks first: it creates the copy at once', (
      tester,
    ) async {
      await pump(tester, _doc());
      await openMenu(tester);
      await tester.tap(find.text('Clone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Clone to a new document'), findsOneWidget);
      await dispose(tester);
    });
  });

  group('signers', () {
    late ShellFixture fixture;

    Future<void> pump(WidgetTester tester, DnDocument doc) async {
      fixture = await buildFixture(
        companies: [FakeCompany(id: 'co1', name: 'Acme')],
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Provider<DocuNinjaApi>.value(
            value: _Api(doc),
            child: const DocuNinjaDocumentScreen(id: 'doc1'),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> tapSendEmail(WidgetTester tester) async {
      final button = find.text('Send Email');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a signer\'s Send Email names that recipient, React\'s way', (
      tester,
    ) async {
      await pump(tester, _doc());
      // React's card: who on whose side, with Copy Link while it is sent.
      expect(find.text('Client Contact:'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      await tapSendEmail(tester);
      expect(find.text('Send Confirmation'), findsOneWidget);
      expect(
        find.text("We're going to send emails to the following:"),
        findsOneWidget,
      );
      // No name: the email alone, kept left-to-right.
      expect(
        find.text('- ${ltrIsolate('signer@example.com')}'),
        findsOneWidget,
      );
      expect(find.text('Are you sure?'), findsNothing);
      final send = tester.widget<PrimaryDialogAction>(
        find.byType(PrimaryDialogAction),
      );
      expect(send.label, 'Send');
      expect(send.autofocus, isFalse, reason: 'it emails a customer');
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      await dispose(tester);

      final json = _fixture()..['status_id'] = 5;
      final invitations = [
        for (final i in json['invitations'] as List)
          Map<String, dynamic>.from(i as Map),
      ];
      invitations.first['contact'] = {
        ...Map<String, dynamic>.from(invitations.first['contact'] as Map),
        'first_name': 'Ann',
        'last_name': 'Lee',
      };
      json['invitations'] = invitations;
      await pump(tester, DnDocument.fromJson(json));
      await tapSendEmail(tester);
      expect(
        find.text('- Ann Lee (${ltrIsolate('signer@example.com')})'),
        findsOneWidget,
      );
      await dispose(tester);
    });

    testWidgets('a finished document\'s signer offers no Send Email', (
      tester,
    ) async {
      await pump(tester, _doc(status: 6));
      expect(find.text('Client Contact:'), findsOneWidget);
      expect(find.text('Send Email'), findsNothing);
      expect(find.text('Copy Link'), findsNothing);
      await dispose(tester);
    });

    testWidgets('no signers: React\'s box into the builder', (tester) async {
      final json = _fixture()
        ..['status_id'] = 1
        ..['invitations'] = <Object>[];
      await pump(tester, DnDocument.fromJson(json));
      expect(find.text('Add Signatories'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Add Signatories'),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
      await dispose(tester);

      // A completed document cannot open the builder: the box is inert.
      final done = _fixture()
        ..['status_id'] = 6
        ..['invitations'] = <Object>[];
      await pump(tester, DnDocument.fromJson(done));
      final ink = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Add Signatories'),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.onTap, isNull);
      await dispose(tester);
    });
  });

  group('downloads', () {
    test('a 400 is React\'s "not ready"; anything else the generic retry', () {
      expect(
        dnFileErrorKey(const DocuNinjaException(400, 'not yet')),
        'not_ready_for_download',
      );
      expect(
        dnFileErrorKey(const DocuNinjaException(500, 'boom')),
        'an_error_occurred_try_again',
      );
      expect(dnFileErrorKey(StateError('x')), 'an_error_occurred_try_again');
    });

    testWidgets('dnSaveFile says so in a toast', (tester) async {
      final fixture = await buildFixture(
        companies: [FakeCompany(id: 'co1', name: 'Acme')],
      );
      addTearDown(fixture.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await dnSaveFile(
        context,
        fetch: () async => throw const DocuNinjaException(400, 'not yet'),
        fallbackName: 'doc',
      );
      await tester.pump();
      expect(find.text('File not ready for download'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('header', () {
    testWidgets('an active document shows only its status beside the title', (
      tester,
    ) async {
      final fixture = await buildFixture(
        companies: [FakeCompany(id: 'co1', name: 'Acme')],
      );
      addTearDown(fixture.dispose);
      Future<int> headerChildren(DnDocument doc) async {
        await tester.pumpWidget(
          wrapWithShell(
            fixture.services,
            Provider<DocuNinjaApi>.value(
              value: _Api(doc),
              child: DocuNinjaDocumentScreen(key: UniqueKey(), id: 'doc1'),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final wrap = tester.widget<Wrap>(
          find
              .ancestor(
                of: find.byType(DocuNinjaStatusPill),
                matching: find.byType(Wrap),
              )
              .first,
        );
        return wrap.children.length;
      }

      // A hidden pill would still cost the Wrap a gap, so none is passed.
      expect(await headerChildren(_doc()), 2);
      final archived = _fixture()..['archived_at'] = '2026-11-01T00:00:00Z';
      expect(await headerChildren(DnDocument.fromJson(archived)), 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('a first page that fits the window still pages on', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final api = _ListApi();
    final vm = DocuNinjaDocumentsViewModel(api: api);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(vm: vm, onOpen: (_) {}),
      ),
    );
    await vm.refresh();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Two rows never scroll, so only the after-layout check can ask for
    // more; it keeps going while the window is still not full.
    expect(api.pages, [1, 2, 3]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a long press starts selecting; a tap then ticks, not opens', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final vm = DocuNinjaDocumentsViewModel(api: _ListApi());
    addTearDown(vm.dispose);
    final opened = <String>[];
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(
          vm: vm,
          selectable: true,
          onOpen: (d) => opened.add(d.id),
          actionsFor: (_) => const Icon(Icons.more_vert, key: Key('row-menu')),
        ),
      ),
    );
    await vm.refresh();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('row-menu')), findsWidgets);

    final first = find.text('Untitled document').first;
    await tester.longPress(first);
    await tester.pump();
    expect(vm.isSelecting, isTrue);
    expect(vm.countSelected, 1);
    expect(opened, isEmpty);
    // Selecting: no row menus; the bulk actions are the menu.
    expect(find.byKey(const Key('row-menu')), findsNothing);

    await tester.tap(find.text('Untitled document').at(1));
    await tester.pump();
    expect(vm.countSelected, 2);
    expect(opened, isEmpty, reason: 'a tap ticks while selecting');

    vm.clearSelection();
    await tester.pump();
    await tester.tap(find.text('Untitled document').first);
    await tester.pump();
    expect(opened, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
