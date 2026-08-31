import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart' show DisabledEntityDispatcher;
import 'package:admin/data/models/domain/search_result.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';

import '_shell_test_helpers.dart';

void main() {
  group('entityTypeForSearchGroup', () {
    test('maps every entity search group to its EntityType', () {
      expect(entityTypeForSearchGroup('clients'), EntityType.client);
      expect(entityTypeForSearchGroup('client_contacts'), EntityType.client);
      expect(entityTypeForSearchGroup('invoices'), EntityType.invoice);
      expect(entityTypeForSearchGroup('quotes'), EntityType.quote);
      expect(entityTypeForSearchGroup('credits'), EntityType.credit);
      expect(entityTypeForSearchGroup('payments'), EntityType.payment);
      expect(
        entityTypeForSearchGroup('recurrings'),
        EntityType.recurringInvoice,
      );
      expect(
        entityTypeForSearchGroup('recurring_invoices'),
        EntityType.recurringInvoice,
      );
      expect(entityTypeForSearchGroup('projects'), EntityType.project);
      expect(entityTypeForSearchGroup('tasks'), EntityType.task);
      expect(entityTypeForSearchGroup('products'), EntityType.product);
      expect(entityTypeForSearchGroup('expenses'), EntityType.expense);
      expect(entityTypeForSearchGroup('vendors'), EntityType.vendor);
      expect(entityTypeForSearchGroup('vendor_contacts'), EntityType.vendor);
    });

    test('purchase orders route through the registry, not the raw path', () {
      // Without this the group fell through to `context.go(r.path)`, skipping
      // the module + permission gate every other entity hit goes through.
      expect(
        entityTypeForSearchGroup('purchase_orders'),
        EntityType.purchaseOrder,
      );
    });

    test('settings + unknown groups → null (caller uses server path)', () {
      expect(entityTypeForSearchGroup('settings'), isNull);
      expect(entityTypeForSearchGroup('whatever'), isNull);
      expect(entityTypeForSearchGroup(''), isNull);
    });
  });

  group('deepLinkSearchHit — pasting a shared link', () {
    final registry = EntityRegistry({
      EntityType.client: EntityHandlers(
        type: EntityType.client,
        wireName: 'client',
        apiPath: '/api/v1/clients',
        routePath: '/clients',
        icon: Icons.circle,
        dispatcher: DisabledEntityDispatcher(EntityType.client),
        detailBuilder: (_, _) => const SizedBox.shrink(),
      ),
    });

    test('resolves a pasted record link to one hit', () {
      final hit = deepLinkSearchHit(
        '  invoiceninja://app/clients/abc?company=co1  ',
        registry,
      );
      expect(hit, isNotNull);
      expect(hit!.group, kDeepLinkSearchGroup);
      expect(hit.name, '/clients/abc');
      // The ORIGINAL uri, not the resolved route — activation hands it back to
      // DeepLinkRouter so a cross-company link still switches company.
      expect(hit.path, 'invoiceninja://app/clients/abc?company=co1');
    });

    test('ignores ordinary search text', () {
      expect(deepLinkSearchHit('acme corp', registry), isNull);
      expect(deepLinkSearchHit('', registry), isNull);
      expect(deepLinkSearchHit('https://example.test', registry), isNull);
    });

    test('ignores a link this build cannot route', () {
      expect(
        deepLinkSearchHit('invoiceninja://app/widgets/x', registry),
        isNull,
      );
    });
  });

  group('recordIdForSearchHit', () {
    SearchResult hit(
      String group, {
      required String id,
      required String path,
    }) => SearchResult(group: group, name: 'x', id: id, path: path);

    test('contact hits route by the PARENT id from `path`, not their own', () {
      // Elasticsearch branch: `id` is the CONTACT's hashed id, `path` carries
      // the parent. Routing by `id` opened a client that doesn't exist.
      expect(
        recordIdForSearchHit(
          hit('client_contacts', id: 'CONTACT9', path: '/clients/CLIENT1'),
        ),
        'CLIENT1',
      );
      expect(
        recordIdForSearchHit(
          hit('vendor_contacts', id: 'CONTACT9', path: '/vendors/VENDOR1'),
        ),
        'VENDOR1',
      );
    });

    test('non-ES fallback shape resolves identically', () {
      // `clientMap` puts the parent id in BOTH fields, so one code path covers
      // either backend.
      expect(
        recordIdForSearchHit(
          hit('client_contacts', id: 'CLIENT1', path: '/clients/CLIENT1'),
        ),
        'CLIENT1',
      );
    });

    test('degrades to `id` when the path is unusable', () {
      expect(
        recordIdForSearchHit(hit('client_contacts', id: 'FALLBACK', path: '')),
        'FALLBACK',
      );
      expect(
        recordIdForSearchHit(hit('client_contacts', id: 'FALLBACK', path: '/')),
        'FALLBACK',
      );
    });

    test('non-contact groups keep their own id', () {
      expect(
        recordIdForSearchHit(
          hit('clients', id: 'CLIENT1', path: '/clients/CLIENT1'),
        ),
        'CLIENT1',
      );
      // Invoices carry `/invoices/{id}/edit`; the trailing segment is NOT an id.
      expect(
        recordIdForSearchHit(
          hit('invoices', id: 'INV1', path: '/invoices/INV1/edit'),
        ),
        'INV1',
      );
    });
  });

  group('settings hits are served locally', () {
    test('SearchResult.isSettings identifies the group the palette drops', () {
      expect(
        const SearchResult(
          group: 'settings',
          name: 'x',
          id: '',
          path: '/settings/subscriptions',
        ).isSettings,
        isTrue,
      );
      expect(
        const SearchResult(
          group: 'clients',
          name: 'x',
          id: 'a',
          path: '/clients/a',
        ).isSettings,
        isFalse,
      );
    });

    test('every catalog section route is a registered app route', () {
      // The palette now navigates `hit.section.route`, so an unroutable entry
      // would reproduce the very dead-end this replaced — and `errorBuilder`
      // is registered at the ROOT, so it takes the whole shell down with it.
      final routes = File(
        'lib/ui/features/settings/settings_routes.dart',
      ).readAsStringSync();
      final modules = File('lib/app/entity_modules.dart').readAsStringSync();
      final registered =
          RegExp(
              r"path: '([a-z_]+)'",
            ).allMatches(routes).map((m) => m.group(1)!).toSet()
            ..addAll(
              RegExp(
                r"_leaf\(\s*'([a-z_/]+)'",
              ).allMatches(routes).map((m) => m.group(1)!),
            )
            ..addAll(
              RegExp(
                r"routePath: '/settings/([a-z_/]+)'",
              ).allMatches(modules).map((m) => m.group(1)!),
            );

      final sections = {for (final s in kSettingsSections) s.slug: s.route};
      expect(sections, isNotEmpty);
      final unroutable = [
        for (final entry in sections.entries)
          if (!registered.contains(entry.key)) '${entry.key} → ${entry.value}',
      ];
      expect(
        unroutable,
        isEmpty,
        reason:
            'These settings sections are reachable from the command palette '
            'but have no registered route:\n  ${unroutable.join('\n  ')}',
      );
    });
  });

  // Issue #101 was "poor information density" about the sidebar's Search box.
  // The palette it opens had the same defect on the same device: three
  // keyboard-only affordances rendered unconditionally, including the `Ctrl/`
  // chip visible in the reporter's Android screenshot. Scanned rather than
  // pumped — these assert the *shape* of the source, which a pumped test can
  // only observe indirectly.
  group('phone chrome (issue #101)', () {
    // Comments stripped: these scans assert what the widget *does*, and the
    // prose explaining a guard names the very identifiers the guard forbids —
    // the `_onChanged` check below first went red against the comment that
    // documents why the close button must not call it.
    final palette = File('lib/ui/features/shell/widgets/command_palette.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('both hint spread sites are gated on isPhone', () {
      // The footer is one `_keyboardHints` definition spread twice, so the
      // check is a short marker per site — the earlier version scanned a fixed
      // 900-char window back from each hint literal against an actual distance
      // of 604, i.e. ~300 chars of slack before a couple of added comment
      // lines turned CI red with no behaviour change.
      final spreads = RegExp(
        r'\.\.\._keyboardHints\(',
      ).allMatches(palette).toList();
      expect(
        spreads,
        hasLength(2),
        reason: 'the hints render under both the results and recents lists',
      );
      for (final m in spreads) {
        expect(
          palette.substring(m.start - 20, m.start).contains('if (!phone)'),
          isTrue,
          reason:
              'a keyboard hint row still renders on a phone, where none of '
              'the arrow / Enter / Esc keys can be pressed',
        );
      }
      expect(
        RegExp(r"'Esc'").allMatches(palette),
        hasLength(1),
        reason:
            'one definition, two spread sites — a second literal means the '
            'block was copied back and the two states can now diverge',
      );
    });

    test('the card keeps its keycap and its touch-gated close button', () {
      // `_buildField`'s `phone: false` half is the tablet/desktop card. The
      // close button is gated on touch rather than on `!isPhone`: a tablet
      // mounts the sidebar's Search box on `Env.isTouchPrimary` but is not
      // `isPhone`, so it lands on the card and needs a visible way out.
      final suffix = palette.indexOf('suffixIcon:');
      expect(suffix, isNot(-1));
      final slot = palette.substring(suffix, suffix + 2000);

      expect(
        slot.contains('KeyCapRow('),
        isTrue,
        reason:
            'one cap per glyph — `[Ctrl][/]`, never a single `Ctrl/` cap '
            '(invoiceninja/flutter#103)',
      );
      // Scoped to the chip, NOT `slot`: the close button four lines later
      // legitimately dims its icon with the same token.
      final chip = palette.substring(
        suffix,
        palette.indexOf('if (touch)', suffix),
      );
      expect(
        chip.contains('tokens.ink3'),
        isFalse,
        reason:
            'the chip uses the default cap ink like every other KeyCap in '
            'the app; it was the only dimmed one',
      );
      expect(
        slot.contains('if (touch)'),
        isTrue,
        reason:
            'the close button is gated on touch, not isPhone: a tablet can '
            'reach this card and needs a visible way out of it',
      );
      expect(slot.contains('Icons.close'), isTrue);
    });

    test('the card close button closes — it never doubles as a clear', () {
      // Scoped to the FIRST `Icons.close`, which is `_buildField`'s card
      // branch. The phone page's second one is the clear button, which
      // legitimately calls `_controller.clear()` — through `_reset`, never
      // through `_onChanged`.
      final close = palette.indexOf('Icons.close');
      expect(close, isNot(-1));
      final button = palette.substring(close, close + 1200);

      expect(
        button.contains('Navigator.of(context).pop()'),
        isTrue,
        reason: 'tapping it must always leave the palette',
      );
      // Clearing through `_onChanged('')` arms the debounce into `_run('')`,
      // and `SearchApi.search` omits the `search` param for a blank query, so
      // the server answers with an unfiltered page (up to 1000 clients) under
      // an empty field instead of the Recents list.
      expect(
        button.contains('_onChanged'),
        isFalse,
        reason: 'a clear must reset _results/_selected itself, not refetch',
      );
      expect(
        button.contains('_controller.clear()'),
        isFalse,
        reason: 'this button closes; clearing is the phone page\'s job',
      );
    });

    test('clearing bumps the request sequence, not just the debounce', () {
      // Cancelling `_debounce` does nothing to a request already in flight:
      // `_run` only discards a late response via `seq != _reqSeq`. Without the
      // bump, tapping clear mid-flight repopulates the list under an empty
      // field.
      final reset = palette.indexOf('void _reset() {');
      expect(reset, isNot(-1));
      final body = palette.substring(reset, reset + 400);
      expect(body.contains('_debounce?.cancel()'), isTrue);
      expect(body.contains('_reqSeq++'), isTrue);
    });
  });

  // Issue #102: the palette floated over the screen behind it through a
  // 0.18 scrim, and on a phone that screen is an entity list whose own search
  // box is pinned in the app bar — two search fields ~20 px apart. These are
  // pumped, not scanned: what changed is the presentation, and the gate needs
  // a real viewport (`flutter test`'s default 800x600 has shortestSide == 600,
  // so `isPhone` is false out of the box) plus a real target platform.
  group('the phone palette is a page, not a card (issue #102)', () {
    late ShellFixture fixture;

    setUp(() async {
      fixture = await buildFixture(
        companies: const [FakeCompany(id: 'c1', name: 'Acme')],
      );
    });

    tearDown(() async => fixture.dispose());

    const phone = Size(412, 915);
    const desktop = Size(1200, 800);

    /// Opens the palette at [size] on [platform] and runs [body] against it.
    ///
    /// The platform override is set *before* `pumpWidget` (`wrapWithShell`
    /// bakes `ThemeData`'s platform in at build time) and cleared in a
    /// `finally` — `flutter_test` verifies the foundation debug vars at the
    /// end of the test *body*, before any `addTearDown` callback runs, so a
    /// tear-down reset is too late and fails every test that sets one.
    ///
    /// `tester.view.physicalSize`, not `setSurfaceSize`: `WidgetsApp` inserts
    /// its own `MediaQuery.fromView` inside `MaterialApp`, so a surface-size
    /// override never reaches `Breakpoints.isPhone` — the test would silently
    /// exercise the desktop branch and pass.
    Future<void> withPalette(
      WidgetTester tester, {
      required Size size,
      required TargetPlatform platform,
      required Future<void> Function() body,
    }) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          wrapWithShell(
            fixture.services,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showCommandPalette(context),
                child: const Text('trigger'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('trigger'));
        await tester.pumpAndSettle();
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('fills the viewport, so nothing shows through behind it', (
      tester,
    ) async {
      await withPalette(
        tester,
        size: phone,
        platform: TargetPlatform.android,
        body: () async {
          expect(find.byType(Dialog), findsOneWidget);
          // Measure the Scaffold, NOT the Dialog: `Dialog` renders an
          // `AnimatedPadding` wrapping an `Align`, so its own box is the full
          // screen on *either* branch and asserting on it passes vacuously
          // against the card (verified by forcing the card branch).
          final surface = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scaffold),
          );
          expect(
            surface,
            findsOneWidget,
            reason: 'the phone presentation is a page: Scaffold + AppBar',
          );
          expect(
            tester.getSize(surface),
            phone,
            reason:
                'a card that shrink-wraps to its field leaves the list — and '
                'the list\'s own pinned search box — legible behind the '
                'scrim (#102)',
          );
        },
      );
    });

    testWidgets('paints under the notch, and the strips are not a barrier', (
      tester,
    ) async {
      // The one assertion that pins `useSafeArea: false`. Left at the default
      // the surface stops below the status bar and that strip stays bare
      // `ModalBarrier` — the page showing through exactly where the list's
      // title sits, and (the barrier being dismissible) a tap beside the
      // gesture bar closing the page. Physical px; devicePixelRatio is 1.0.
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPadding);

      await withPalette(
        tester,
        size: phone,
        platform: TargetPlatform.android,
        body: () async {
          final surface = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scaffold),
          );
          expect(
            tester.getSize(surface),
            phone,
            reason: 'the page owns the insets, not a SafeArea above it',
          );
          expect(
            tester.getTopLeft(surface),
            Offset.zero,
            reason: 'edge to edge — the AppBar supplies the status-bar pad',
          );
        },
      );
    });

    testWidgets('carries a back arrow that closes it, and no keycap', (
      tester,
    ) async {
      await withPalette(
        tester,
        size: phone,
        platform: TargetPlatform.android,
        body: () async {
          expect(
            find.byType(KeyCap),
            findsNothing,
            reason: 'no keyboard to press ⌘/ on',
          );
          expect(find.byIcon(Icons.arrow_back), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        },
      );
    });

    testWidgets('names what it searches, rather than just "Search"', (
      tester,
    ) async {
      await withPalette(
        tester,
        size: phone,
        platform: TargetPlatform.android,
        body: () async {
          // The reporter's users read a lone magnifier as "search *this
          // page*". `search_placeholder` is a real Transifex key, so this
          // keeps its translation.
          expect(find.text('Find invoices, clients, and more'), findsOneWidget);
        },
      );
    });

    testWidgets('clear empties the field without closing the page', (
      tester,
    ) async {
      await withPalette(
        tester,
        size: phone,
        platform: TargetPlatform.android,
        body: () async {
          await tester.enterText(find.byType(TextField), 'acme');
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.close), findsOneWidget);

          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          expect(
            find.byIcon(Icons.close),
            findsNothing,
            reason: 'the clear action only exists while the field has text',
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller?.text,
            isEmpty,
          );
          expect(
            find.byType(Dialog),
            findsOneWidget,
            reason: 'clear clears; it must not double as a close',
          );
        },
      );
    });

    // #103: the field's `⌘ /` chip was a bordered mono keycap while the row
    // directly under it was flat sans text joined by `·` — two treatments of
    // one idea ~40 px apart. These pin the footer's new shape, and the gate
    // that keeps a louder hint from claiming a key that does nothing.
    testWidgets('the footer only offers keys that currently do something', (
      tester,
    ) async {
      await withPalette(
        tester,
        size: desktop,
        platform: TargetPlatform.macOS,
        body: () async {
          // `buildFixture` installs a fail-fast client, so the search rejects
          // and the palette lands on "No records found" — where `_move` and
          // `_select` both early-return.
          await tester.enterText(find.byType(TextField), 'acme');
          // `_onChanged` doesn't setState; nothing rebuilds until the debounce
          // fires `_run`. Plain `pump`, never `pumpAndSettle`: a still-running
          // LinearProgressIndicator would hang it for the 10-minute timeout.
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          expect(find.text('No records found'), findsOneWidget);
          expect(
            find.text('Navigate'),
            findsNothing,
            reason: 'there is nothing to move through',
          );
          expect(find.text('Select'), findsNothing);
          expect(
            find.text('Close'),
            findsOneWidget,
            reason: 'Esc still works, so it is still offered',
          );
          // The 2 field-chip caps plus Esc.
          expect(find.byType(KeyCap), findsNWidgets(3));
        },
      );
    });

    testWidgets('a populated footer is keycaps, with no middot separators', (
      tester,
    ) async {
      await withPalette(
        tester,
        size: desktop,
        platform: TargetPlatform.macOS,
        body: () async {
          // A pasted deep link resolves locally in `_run` — synchronous
          // results with no network and no recents timer to drain.
          await tester.enterText(
            find.byType(TextField),
            'invoiceninja://app/clients/abc',
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          expect(find.text('Navigate'), findsOneWidget);
          expect(find.text('Select'), findsOneWidget);
          expect(find.text('Close'), findsOneWidget);
          // ⌘ / in the field, then ↑ ↓ Enter Esc in the footer.
          expect(find.byType(KeyCap), findsNWidgets(6));
          expect(
            find.textContaining('·'),
            findsNothing,
            reason: 'the separators are gone — a cap is its own visual unit',
          );
        },
      );
    });

    testWidgets('a desktop window keeps the floating card', (tester) async {
      await withPalette(
        tester,
        size: desktop,
        platform: TargetPlatform.macOS,
        body: () async {
          expect(find.byIcon(Icons.arrow_back), findsNothing);
          // One cap per glyph: `⌘` + `/` on macOS. The card is at rest (no
          // query, no recents), so `sections` is empty and the footer's own
          // caps aren't up yet.
          expect(find.byType(KeyCap), findsNWidgets(2));
          expect(find.text('⌘'), findsOneWidget);
          expect(find.text('/'), findsOneWidget);
          expect(
            tester.getSize(find.byType(ClipRRect)).width,
            lessThanOrEqualTo(680),
            reason: 'the Spotlight card is unchanged on desktop',
          );
        },
      );
    });
  });
}
