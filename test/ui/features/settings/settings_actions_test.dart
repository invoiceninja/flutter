// Regression guard for the Settings "Sign out" pending-outbox check. The
// company picker's switch / sign-out paths already quiesce the outbox before
// wiping the session; this proves the Settings → Sign out action does too, so
// an unsynced offline edit can't be silently dropped on logout.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/features/settings/settings_actions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/_shell_test_helpers.dart';

void main() {
  testWidgets(
    'Settings sign-out with a pending outbox row surfaces the unsynced-changes '
    'guard instead of logging out silently',
    (tester) async {
      final fixture = await buildFixture(
        companies: const [
          FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        ],
        currentCompanyId: 'c1',
      );
      addTearDown(fixture.dispose);

      // Park one pending outbox row for the active company.
      await fixture.db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'c1',
          entityType: 'client',
          entityId: 'x',
          mutationKind: 'update',
          payload: '{}',
          idempotencyKey: 'k',
          createdAt: 0,
          nextAttemptAt: 0,
          requiresPassword: const Value(false),
        ),
      );

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => SettingsActions.signOut(context),
              child: const Text('trigger-signout'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger → generic "sign out?" confirm appears first.
      await tester.tap(find.text('trigger-signout'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Confirm sign-out (the confirm dialog's only FilledButton). The
      // pending-outbox guard must intercept before logout/DB wipe.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Unsynced changes'), findsOneWidget);
      expect(find.text('Sync first'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Cancel the guard → still signed in, session (and its DB) intact.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.services.auth.session.value?.currentCompanyId, 'c1');

      // The recently-viewed controller arms a debounce timer when restore()
      // first set the session; dispose it before the binding's pending-timer
      // check (ShellFixture.dispose doesn't touch it — no double-dispose).
      fixture.services.recentlyViewed.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Settings sign-out with an unsaved (dirty) editor surfaces the '
      'discard-changes guard instead of logging out silently', (tester) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    // Register an always-dirty editor so the in-memory guard must prompt.
    // Teardown order (LIFO): unregister runs before source.dispose, so the
    // guard's listener is removed before the notifier is torn down.
    final source = ValueNotifier<int>(0);
    addTearDown(source.dispose);
    final unregister = fixture.services.unsavedChangesGuard.register(
      isDirty: () => true,
      source: source,
    );
    addTearDown(unregister);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => SettingsActions.signOut(context),
            child: const Text('trigger-signout'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger → generic "sign out?" confirm; confirm it (its only
    // FilledButton). The in-memory dirty guard must intercept before logout.
    await tester.tap(find.text('trigger-signout'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);

    // Keep editing → aborts sign-out, still signed in.
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(fixture.services.auth.session.value?.currentCompanyId, 'c1');

    fixture.services.recentlyViewed.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'forceResync surfaces a failure snackbar when the server is unreachable '
    'and leaves the active session intact (orchestration error path)',
    (tester) async {
      // forceResync now fans out across every entity via
      // Services.resyncAllEntities (a full auth refresh + per-entity
      // refreshAll). The fan-out and dirty-row preservation are covered by the
      // per-entity repo tests (e.g. client_repository_test's "ensurePageLoaded
      // preserves is_dirty=true rows") and auth_repository_test; this guards
      // the orchestration's error handling — an unreachable server must report
      // failure rather than a misleading "complete", without crashing or
      // dropping the session.
      final fixture = await buildFixture(
        companies: const [
          FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        ],
        currentCompanyId: 'c1',
        online: true, // attempt the request so the fail-fast client errors
      );
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => SettingsActions.forceResync(context),
              child: const Text('trigger-resync'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('trigger-resync'));
      await tester.pumpAndSettle();

      // Default failureKey = resync_failed; either the leading auth refresh
      // throws or every entity refresh is collected as failed — both report it.
      // The failure now surfaces via the global toast host (no more SnackBar).
      expect(find.text('Resync failed'), findsOneWidget);
      expect(fixture.services.auth.session.value?.currentCompanyId, 'c1');

      // Cancel the toast's auto-dismiss timer before the body ends (flutter_test
      // checks for pending timers before addTearDown runs).
      fixture.services.toasts.clearAll();
      fixture.services.recentlyViewed.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('forceResync still reports once the initiating widget is gone '
      '(issue #14: the sidebar Sync button outlives its screen)', (
    tester,
  ) async {
    // A pass started from the sidebar runs for tens of seconds, and the user
    // routinely navigates away before it lands. `forceResync` captures the
    // toast queue before its first await precisely so the result survives —
    // this pins that contract. Without it the toast is silently dropped.
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
      online: true,
    );
    addTearDown(fixture.dispose);

    var showTrigger = true;
    late StateSetter setOuterState;

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        StatefulBuilder(
          builder: (context, setState) {
            setOuterState = setState;
            return showTrigger
                ? TextButton(
                    onPressed: () => SettingsActions.forceResync(context),
                    child: const Text('trigger-resync'),
                  )
                : const Text('trigger-gone');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('trigger-resync'));
    await tester.pump();

    // Unmount the initiating widget mid-pass, the way navigating away does.
    setOuterState(() => showTrigger = false);
    await tester.pumpAndSettle();
    expect(find.text('trigger-resync'), findsNothing);

    // The toast host is a Stack sibling of the body, not a descendant of the
    // trigger, so the outcome still reaches the user.
    expect(find.text('Resync failed'), findsOneWidget);

    fixture.services.toasts.clearAll();
    fixture.services.recentlyViewed.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
