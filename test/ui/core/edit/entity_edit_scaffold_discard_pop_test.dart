// Regression test for the discard path on a CREATE route (issue #39).
//
// `/x/new` is a sibling of the list inside the entity `ShellRoute`
// (`buildEntityRouteBlock`), so nothing anywhere holds a second page. The
// scaffold's own `PopScope` still intercepts the Android back gesture on a
// dirty form and prompts — but the `context.pop()` that used to follow the
// user's "Discard" threw `GoError('There is nothing to pop')` inside an async
// callback, so Discard silently did nothing and the form stayed put.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/ui/core/edit/entity_edit_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

class _FakeServices implements Services {
  _FakeServices(this.unsavedChangesGuard);
  @override
  final UnsavedChangesGuard unsavedChangesGuard;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// `original == null` ⇒ create mode; a draft differing from it ⇒ dirty.
class _FakeVM extends GenericEditViewModel<String> {
  _FakeVM({required super.initialDraft});

  @override
  Future<SaveResult<String>> performSave() async =>
      SaveResult(entity: draft, outboxRowId: 1);
}

Future<void> simulateSystemBack(WidgetTester tester) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMessageCodec().encodeMessage(<String, dynamic>{
      'method': 'popRoute',
    }),
    (ByteData? _) {},
  );
}

void main() {
  String currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('discarding a dirty create form leaves for the list instead of '
      'throwing', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Create mode (`original == null`) reports dirty via `draftIsNonEmpty`,
    // which defaults to true — the same state a half-filled New form is in.
    final vm = _FakeVM(initialDraft: 'typed something');

    // The production route shape: `/products/new` is a SIBLING of `/products`,
    // so the shell Navigator holds exactly one page.
    final router = GoRouter(
      initialLocation: '/products/new',
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage<void>(
            key: const ValueKey('master_detail:/products'),
            child: MasterDetailLayout(
              basePath: '/products',
              list: const Scaffold(body: Center(child: Text('LIST'))),
              rightPane: child,
              hasPane: state.matchedLocation != '/products',
              viewMode: state.uri.queryParameters['view'],
            ),
          ),
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/products/new',
              builder: (_, _) => EntityEditScaffold<String>(
                vm: vm,
                canSave: true,
                titleBuilder: (_) => 'New Product',
                bodyBuilder: (_) => const SizedBox.shrink(),
                resetToEmpty: () {},
                onSaved: (_, _) {},
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(UnsavedChangesGuard()),
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await simulateSystemBack(tester);
    await tester.pumpAndSettle();

    // The dirty guard still fires — the fix must not cost us the prompt.
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(currentUri(router), '/products');
  });

  group('entityBasePathFromEditorPath', () {
    test('strips the editor segments an editor URL sits under', () {
      expect(entityBasePathFromEditorPath('/quotes/new'), '/quotes');
      expect(entityBasePathFromEditorPath('/quotes/q_1/edit'), '/quotes');
      expect(
        entityBasePathFromEditorPath('/settings/company_gateways/g_1/edit'),
        '/settings/company_gateways',
      );
      // Not an editor URL — nothing to strip.
      expect(entityBasePathFromEditorPath('/quotes/q_1'), '/quotes/q_1');
    });
  });
}
