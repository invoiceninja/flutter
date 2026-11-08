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
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_document_screen.dart';

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

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> dispose(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

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
}
