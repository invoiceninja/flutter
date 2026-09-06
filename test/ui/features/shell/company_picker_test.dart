import 'dart:convert';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/sync_repository.dart' show kMaxAttempts;
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/company_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '_shell_test_helpers.dart';

/// Pumps the picker as a pushed ROUTE rather than as the tree root, so
/// `Navigator.maybePop()` inside it actually pops. Rooted at `home` the pop
/// finds nothing to pop and the State stays mounted — which hides every bug in
/// the code that runs *after* the pop (a stale-context toast lookup resolves
/// fine, so a swallowed error still looks delivered).
///
/// Mirrors `showCompanyPicker`'s real shape in two ways that matter:
///  * **non-opaque**, like the `PopupRoute` it really uses. An opaque route
///    puts everything below it offstage, including `wrapWithShell`'s
///    `ToastHost` — toasts would then be unfindable for reasons that have
///    nothing to do with the code under test.
///  * **re-provides `Services`**, because the pushed route mounts under
///    MaterialApp's Navigator, which sits above `wrapWithShell`'s provider.
///
/// Leaves the picker on screen, ready to tap.
Future<void> _pumpRoutedPicker(
  WidgetTester tester,
  ShellFixture fixture,
) async {
  await tester.pumpWidget(
    wrapWithShell(
      fixture.services,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).push(
            PageRouteBuilder<void>(
              opaque: false,
              pageBuilder: (_, _, _) => Provider<Services>.value(
                value: fixture.services,
                child: const CompanyPicker(fillWidth: true),
              ),
            ),
          ),
          child: const Text('open picker'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open picker'));
  await tester.pumpAndSettle();
}

/// Minimal `/api/v1/refresh` body. `company` and `account` are the only
/// required blocks on `UserCompanyApi`; `token` is deliberately optional (a
/// null there used to drop the whole company — issue #16).
///
/// The plan, company allowance and owner/admin flags are set on purpose:
/// `buildFixture` seeds those into Drift, but the background heal that
/// `restore()` kicks off overwrites both the account row and the per-company
/// flags from whatever this returns. Leave them at their defaults and the
/// picker's "New company" row silently becomes the upgrade CTA (free plan) or
/// an inert "only the account owner can add companies" row — confusing ways for
/// an unrelated test to fail.
String _refreshEnvelope(List<({String id, String name, String token})> cos) =>
    jsonEncode({
      'data': [
        for (final c in cos)
          {
            'is_owner': true,
            'is_admin': true,
            'company': {'id': c.id, 'name': c.name},
            'token': {'token': c.token},
            'account': {
              'id': 'acct1',
              'default_company_id': cos.first.id,
              'plan': 'pro',
              'hosted_company_count': 10,
            },
          },
      ],
    });

Future<void> _drain(WidgetTester tester, ShellFixture fixture) async {
  // `auth.switchCompany` re-runs the Services.build closure and restarts the
  // RefreshScheduler's periodic timer. flutter_test asserts `!timersPending`
  // at the end of the test body (before addTearDown), so stop it here.
  fixture.services.refreshScheduler.stop();
  // Switching also bumps `auth.session`, which RecentlyViewedController
  // listens to: `_onSession` arms a 400 ms persist-debounce Timer. Same
  // `!timersPending` deadline applies — cancel it here (dispose() cancels
  // the timer + drops the session listener; ShellFixture.dispose() does not
  // touch this controller, so there's no double-dispose).
  fixture.services.recentlyViewed.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows every company and marks the active one', (tester) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co'),
        FakeCompany(id: 'c2', name: 'Stark Industries'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acme Co'), findsOneWidget);
    expect(find.text('Stark Industries'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await _drain(tester, fixture);
  });

  testWidgets('a single company reads as an account menu, not a switcher', (
    tester,
  ) async {
    // Issue #104 made this sheet the destination of the single-company mobile
    // drawer's only account affordance, so it has to read as one. With nothing
    // to switch to, the tinted fill + "Active" caption + trailing check are
    // three redundant "this is selected" marks on a list of one, and the row
    // they decorate is inert (`_pick` short-circuits a tap on the active
    // company to a bare `maybePop`) — which reads as a switcher that failed.
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acme Co'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    // The company, New company, Sign out — an account menu.
    expect(find.text('New Company'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);

    await _drain(tester, fixture);
  });

  // The Log Out row shipped with NO confirmation: `confirmIfDirty` and
  // `confirmPendingOutboxIfAny` are both silent no-ops when nothing is dirty,
  // which is the common case, so one tap wiped every company's local DB.
  testWidgets('Log Out confirms before touching the session', (tester) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    // Routed, not rooted: `_signOut` pops the picker on success, and rooted at
    // `home` a `maybePop` finds nothing to pop and the State stays mounted —
    // so the "still open" assertion below would pass whatever the code did.
    await _pumpRoutedPicker(tester, fixture);

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsNothing);
    expect(
      fixture.services.auth.session.value?.currentCompanyId,
      'c1',
      reason: 'Cancel must leave the session untouched',
    );
    expect(
      find.byType(CompanyPicker),
      findsOneWidget,
      reason: 'and must not close the picker',
    );

    await _drain(tester, fixture);
  });

  // The picker used to own its guards inline; it now delegates to
  // `SettingsActions.signOut`. This is what proves the delegation kept them.
  testWidgets('confirming Log Out still reaches the pending-outbox guard', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

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
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Unsynced changes'), findsOneWidget);
    expect(find.text('Sync first'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.services.auth.session.value?.currentCompanyId, 'c1');

    await _drain(tester, fixture);
  });

  testWidgets('passes settings.company_logo through to CompanyAvatar', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(
          id: 'c1',
          name: 'Acme Co',
          logoUrl: 'https://example.com/logo.png',
        ),
        FakeCompany(id: 'c2', name: 'Stark Industries'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    final avatars = tester
        .widgetList<CompanyAvatar>(find.byType(CompanyAvatar))
        .toList();
    final acmeAvatar = avatars.firstWhere((a) => a.seed == 'c1');
    final starkAvatar = avatars.firstWhere((a) => a.seed == 'c2');
    // Cache-busted with `?v=<updatedAt>` (see cacheBustedLogoUrl) so a logo
    // replace — same server URL — still invalidates the image cache.
    expect(acmeAvatar.logoUrl, startsWith('https://example.com/logo.png'));
    expect(acmeAvatar.logoUrl, contains('?v='));
    expect(starkAvatar.logoUrl, isNull);

    await _drain(tester, fixture);
  });

  testWidgets('New Company action opens a confirm dialog (owner)', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co', isOwner: true)],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Company'));
    await tester.pumpAndSettle();

    // Confirm dialog rendered. The `add_company` localization key is reused
    // for both the title and the FilledButton, so the literal "Add Company"
    // appears twice inside the same AlertDialog.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Add Company'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.text(
        'A new company will be created on your account. '
        'You can rename and configure it after.',
      ),
      findsOneWidget,
    );

    // Cancel — picker stays mounted, no network call made.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('New Company'), findsOneWidget);

    await _drain(tester, fixture);
  });

  testWidgets('New Company action is disabled for non-owners', (tester) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co', isOwner: false)],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    // The disabled-reason subtitle is rendered inline so mobile users can
    // see why the action isn't available (Tooltip wouldn't fire on tap).
    expect(
      find.text('Only the account owner can add companies'),
      findsOneWidget,
    );

    // Tapping the disabled row is a no-op — the confirm dialog must not open.
    await tester.tap(find.text('New Company'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);

    await _drain(tester, fixture);
  });

  testWidgets('switching without pending outbox calls auth.switchCompany', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        FakeCompany(id: 'c2', name: 'Stark Industries', token: 'tok-c2'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stark Industries'));
    await tester.pumpAndSettle();

    expect(fixture.services.auth.session.value?.currentCompanyId, 'c2');

    await _drain(tester, fixture);
  });

  testWidgets('switching with pending outbox surfaces the confirm dialog', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        FakeCompany(id: 'c2', name: 'Stark Industries', token: 'tok-c2'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    // Park one pending outbox row for c1 so the picker has to prompt.
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
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stark Industries'));
    await tester.pumpAndSettle();

    expect(find.text('Unsynced changes'), findsOneWidget);
    expect(find.text('Sync first'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    // Cancel and confirm the active company didn't change.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.services.auth.session.value?.currentCompanyId, 'c1');

    await _drain(tester, fixture);
  });

  testWidgets('online + pending row that resolves during precheck skips the '
      'dialog and switches', (tester) async {
    // Setup: online, plus a row primed to die on its next attempt
    // (attempts = kMaxAttempts - 1). The precheck's silent flushNow will
    // hit the real ApiClient → http.Client, fail with NetworkException,
    // trip _retryWithBackoff → _markDead. The row leaves the pending
    // state, pendingCountFor returns 0, and the dialog stays away.
    //
    // This proves the silent-flush precheck branch — not a Mock of the
    // sync engine. The actual code path runs end-to-end.
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        FakeCompany(id: 'c2', name: 'Stark Industries', token: 'tok-c2'),
      ],
      currentCompanyId: 'c1',
      online: true,
    );
    addTearDown(fixture.dispose);

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
        attempts: const Value(kMaxAttempts - 1),
        requiresPassword: const Value(false),
      ),
    );

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const CompanyPicker(fillWidth: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stark Industries'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unsynced changes'),
      findsNothing,
      reason:
          'precheck flushNow resolved the row (marked dead), so no dialog '
          'should appear',
    );
    expect(
      fixture.services.auth.session.value?.currentCompanyId,
      'c2',
      reason: 'switch must go through after the silent flush',
    );

    await _drain(tester, fixture);
  });

  testWidgets('a failed New Company reports the error', (tester) async {
    // A failed add must reach the user. The picker pops itself before
    // `addCompany` resolves, so this covers the ordering that actually ships:
    // the delayed client makes the POST outlast the pop animation, the way a
    // real network round-trip does (the fixture's default fail-fast client
    // rejects first and leaves the State mounted, which is not the real case).
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        FakeCompany(id: 'c2', name: 'Stark Industries', token: 'tok-c2'),
      ],
      currentCompanyId: 'c1',
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        throw http.ClientException('offline (delayed test fixture)');
      }),
    );
    addTearDown(fixture.dispose);

    await _pumpRoutedPicker(tester, fixture);

    await tester.tap(find.text('New Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Company'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to add company'), findsOneWidget);

    await _drain(tester, fixture);
  });

  testWidgets('stays open with a spinner while the switch is in flight, then '
      'dismisses', (tester) async {
    // A token-less company sends `switchCompany` through a healing /refresh
    // before it can answer. The picker used to dismiss itself up front, so that
    // wait happened behind an unchanged shell with no feedback at all — the
    // exact "nothing happens" the issue reports. Hold the picker until the
    // switch resolves and mark the row that's working.
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        FakeCompany(id: 'c2', name: 'Stark Industries', token: ''),
      ],
      currentCompanyId: 'c1',
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        throw http.ClientException('offline (delayed test fixture)');
      }),
    );
    addTearDown(fixture.dispose);

    await _pumpRoutedPicker(tester, fixture);
    await tester.tap(find.text('Stark Industries'));
    // `pump`, not `pumpAndSettle` — an indeterminate CircularProgressIndicator
    // never settles, so settling here would skip straight past the state under
    // test (same reason `sidebar_header_test` uses bare pumps).
    await tester.pump();

    expect(
      find.byType(CompanyPicker),
      findsOneWidget,
      reason: 'the picker must stay up while the switch is in flight',
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(
      find.byType(CompanyPicker),
      findsNothing,
      reason: 'and dismiss once it resolves',
    );

    await _drain(tester, fixture);
  });

  testWidgets('a create that succeeds but cannot be activated does not say the '
      'add failed', (tester) async {
    // `addCompany` POSTs, then re-pulls /refresh to find the new company. When
    // that second step can't produce an activatable company the POST has still
    // succeeded — the company exists. Reporting "Failed to add company" there
    // invites the user to create a duplicate.
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1', isOwner: true),
      ],
      httpClient: MockClient((req) async {
        if (req.url.path == '/api/v1/companies') {
          return http.Response('{}', 200); // create succeeds
        }
        if (req.url.path == '/api/v1/refresh') {
          // ...but the new company never comes back.
          return http.Response(
            _refreshEnvelope([(id: 'c1', name: 'Acme Co', token: 'tok-c1')]),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );
    addTearDown(fixture.dispose);

    await _pumpRoutedPicker(tester, fixture);
    await tester.tap(find.text('New Company'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Company'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Company created'), findsOneWidget);
    expect(find.textContaining('Failed to add company'), findsNothing);

    await _drain(tester, fixture);
  });

  testWidgets('a company with no usable token surfaces an error instead of '
      'closing silently', (tester) async {
    // Issue #16. The roster and the token map have different sources, so a
    // company can be listed with no token behind it. `switchCompany` used to
    // return silently and the picker navigated anyway — the overlay closed,
    // the route reset, and the user stayed in the old company with no clue
    // why. The healing refresh can't help here (the fixture's HTTP client is
    // fail-fast), so this exercises the give-up path.
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
        FakeCompany(id: 'c2', name: 'Stark Industries', token: ''),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    await _pumpRoutedPicker(tester, fixture);

    await tester.tap(find.text('Stark Industries'));
    await tester.pumpAndSettle();

    expect(
      fixture.services.auth.session.value?.currentCompanyId,
      'c1',
      reason: 'a token-less company must not become active',
    );
    expect(
      find.text("Couldn't switch to Stark Industries"),
      findsOneWidget,
      reason: 'the failure has to reach the user, not just the log',
    );

    await _drain(tester, fixture);
  });
}
