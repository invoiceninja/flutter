import 'dart:async';

import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// After an edit, `goAfterEntitySave` pops back — and an editor at the
/// bottom of its stack has nothing to pop (Sentry FLUTTER-ADMIN-K:
/// `GoError: There is nothing to pop`).
void main() {
  late BuildContext editContext;

  GoRouter router() => GoRouter(
    initialLocation: '/expenses/e1/edit',
    routes: [
      GoRoute(
        path: '/expenses/:id',
        builder: (_, state) => Text('detail ${state.pathParameters['id']}'),
      ),
      // Top-level, not nested under the detail: the editor is alone on its
      // stack, as one restored at launch or opened by a `go` can be.
      GoRoute(
        path: '/expenses/:id/edit',
        builder: (context, _) => Builder(
          builder: (context) {
            editContext = context;
            return const Text('edit');
          },
        ),
      ),
    ],
  );

  testWidgets('an edit with nothing to pop goes to the record', (tester) async {
    final r = router();
    addTearDown(r.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));

    goAfterEntitySave(
      editContext,
      isCreate: false,
      basePath: '/expenses',
      savedId: 'e1',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('detail e1'), findsOneWidget);
  });

  testWidgets('an edit pushed over the record pops back to it', (tester) async {
    final r = router();
    addTearDown(r.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    r.go('/expenses/e1');
    await tester.pumpAndSettle();
    unawaited(r.push('/expenses/e1/edit'));
    await tester.pumpAndSettle();

    goAfterEntitySave(
      editContext,
      isCreate: false,
      basePath: '/expenses',
      savedId: 'e1',
    );
    await tester.pumpAndSettle();

    expect(find.text('detail e1'), findsOneWidget);
    expect(find.text('edit'), findsNothing);
  });
}
