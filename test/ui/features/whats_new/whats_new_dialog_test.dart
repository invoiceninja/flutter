import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/ui/core/widgets/feature_row.dart';
import 'package:admin/ui/features/whats_new/whats_new_dialog.dart';

import '../../../_localization_helper.dart';

const _withHighlights = ReleaseNotes(
  version: '2.0.2',
  highlights: [
    ReleaseHighlight(
      icon: Icons.bar_chart_outlined,
      title: 'Reports, rebuilt',
      body: 'Charts and saved views.',
      target: ReleaseHighlightRoute('/reports', permission: 'view_reports'),
    ),
    ReleaseHighlight(
      icon: Icons.work_outline,
      title: 'Project analytics',
      body: 'A burn-up chart.',
      target: ReleaseHighlightRoute('/projects', module: EntityType.project),
    ),
    ReleaseHighlight(
      icon: Icons.search,
      title: 'Smarter search',
      body: 'Finds more.',
    ),
  ],
  items: [
    ReleaseNoteItem('Added: Reports rebuilt.'),
    ReleaseNoteItem(
      'Fixed: Big amounts keep their cents '
      '[#176](https://github.com/invoiceninja/flutter/issues/176)',
    ),
    ReleaseNoteItem('Updated: Search finds more.'),
  ],
);

const _fixesOnly = ReleaseNotes(
  version: '2.0.1',
  items: [ReleaseNoteItem('Fixed: A crash on save.')],
);

/// Opens the dialog the way the app does — through `showDialog` with the
/// barrier off — so the result each way out pops with is observable.
class _Harness {
  Future<WhatsNewResult?>? result;

  Future<void> open(
    WidgetTester tester, {
    List<ReleaseNotes> releases = const [_withHighlights],
    String? since,
    bool Function(ReleaseHighlightTarget)? reachable,
    Size size = const Size(1280, 900),
    double textScale = 1,
    TextDirection direction = TextDirection.ltr,
    bool arm = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => result = showDialog<WhatsNewResult>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => WhatsNewDialog(
                    releases: releases,
                    since: since,
                    reachable: reachable ?? (_) => true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (arm) await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('leads with the release and its highlights, the full list '
      'folded behind See all', (tester) async {
    await _Harness().open(tester);
    expect(find.text("What's new in v2.0.2"), findsOneWidget);
    expect(
      find.text('Welcome to the new version of Invoice Ninja'),
      findsOneWidget,
    );
    expect(find.byType(FeatureRow), findsNWidgets(3));
    expect(find.text('See all 3 changes'), findsOneWidget);
    expect(find.text('Reports rebuilt.'), findsNothing);

    await tester.tap(find.text('See all 3 changes'));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('IMPROVED'), findsOneWidget);
    expect(find.text('FIXED'), findsOneWidget);
    // The issue link is dropped, not printed as a bare "#176".
    expect(find.text('Big amounts keep their cents'), findsOneWidget);
    expect(find.textContaining('#176'), findsNothing);
    expect(find.text('Show fewer'), findsOneWidget);
  });

  testWidgets('a release with no highlights opens on its full list, with '
      'nothing to fold', (tester) async {
    await _Harness().open(tester, releases: const [_fixesOnly]);
    expect(find.text('A crash on save.'), findsOneWidget);
    expect(find.textContaining('See all'), findsNothing);
  });

  testWidgets('a highlight the user cannot open is left out', (tester) async {
    await _Harness().open(
      tester,
      reachable: (t) =>
          t is ReleaseHighlightRoute && t.module != EntityType.project,
    );
    expect(find.text('Reports, rebuilt'), findsOneWidget);
    expect(find.text('Project analytics'), findsNothing);
    expect(find.text('Smarter search'), findsOneWidget, reason: 'no target');
  });

  testWidgets('tapping a highlight closes with where it leads', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.tap(find.text('Reports, rebuilt'));
    await tester.pumpAndSettle();
    final result = await h.result;
    expect(result, isA<WhatsNewOpenRoute>());
    expect((result! as WhatsNewOpenRoute).path, '/reports');
  });

  group('every way out', () {
    for (final (name, finder) in [
      ('Got it', find.text('Got it!')),
      ('the ✕', find.byTooltip('Close')),
    ]) {
      testWidgets('$name closes it', (tester) async {
        final h = _Harness();
        await h.open(tester);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(await h.result, isA<WhatsNewClosed>());
      });
    }

    testWidgets('Esc closes it, though the barrier is off', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await h.result, isA<WhatsNewClosed>());
    });

    testWidgets('Feedback closes it and asks for the contact form', (
      tester,
    ) async {
      final h = _Harness();
      await h.open(tester);
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      expect(await h.result, isA<WhatsNewFeedback>());
    });

    testWidgets('a click or Enter in the first half-second is ignored', (
      tester,
    ) async {
      final h = _Harness();
      await h.open(tester, arm: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.text('Got it!'));
      await tester.pump();
      expect(find.text("What's new in v2.0.2"), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();
      expect(await h.result, isA<WhatsNewClosed>());
    });
  });

  testWidgets('a catch-up names where it started, and folds the older '
      'releases to a count', (tester) async {
    await _Harness().open(
      tester,
      releases: const [_withHighlights, _fixesOnly],
      since: '2.0.0',
    );
    expect(find.text("What's new in v2.0.2"), findsOneWidget);
    expect(find.text('Including the changes since v2.0.0'), findsOneWidget);
    await tester.tap(find.text('See all 4 changes'));
    await tester.pumpAndSettle();
    expect(find.text('v2.0.2'), findsOneWidget);
    expect(find.text('v2.0.1 · 1 change'), findsOneWidget);
    expect(find.text('A crash on save.'), findsNothing);

    await tester.tap(find.text('v2.0.1 · 1 change'));
    await tester.pumpAndSettle();
    expect(find.text('A crash on save.'), findsOneWidget);
  });

  group('fits', () {
    for (final (name, size, scale, direction) in [
      ('a phone', const Size(360, 640), 1.0, TextDirection.ltr),
      ('a phone at 1.4× text', const Size(360, 640), 1.4, TextDirection.ltr),
      ('a landscape phone', const Size(740, 360), 1.0, TextDirection.ltr),
      ('right to left', const Size(1280, 900), 1.0, TextDirection.rtl),
    ]) {
      testWidgets(name, (tester) async {
        await _Harness().open(
          tester,
          size: size,
          textScale: scale,
          direction: direction,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.textContaining('See all'));
        await tester.tap(find.textContaining('See all'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Got it!'), findsOneWidget);
      });
    }
  });
}
