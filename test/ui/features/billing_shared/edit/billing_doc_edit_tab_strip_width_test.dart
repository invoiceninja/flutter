import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/scroll_edge_fades.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_tab_strip.dart';

import '../../../../_localization_helper.dart';

/// The width budget behind invoiceninja/flutter#140, measured against the
/// real [BillingDocEditTabStrip] rather than a hand-built `TabBar` — the
/// alignment, the fades and the controller all ship from that one widget, so
/// that is what has to be measured.
///
/// The reporter's screenshot is a 1080-physical Android phone at dpr 2.625,
/// i.e. **411.4 logical px**, and the invoice edit strip was 581.6 px of
/// content in it — 1.42 screens, with no fade or any other cue that the last
/// two tabs existed. Three things caused that and only one was the `PDF` tab
/// they asked about:
///
///   as shipped                        581.6   -170
///   - the ungated E-Invoice tab       491.6    -80
///   - Material's 52 px startOffset    439.6    -28
///   - PDF out of the strip            382.0    +29   fits
///
/// This pins the last row, and the two middle rows as the reasons it is
/// reachable at all. It measures `maxScrollExtent`, which is exactly "how far
/// this strip can scroll" — zero means the reporter's ask is met.
///
/// **The bundled font is load-bearing.** `flutter test` substitutes a
/// square-per-glyph font that over-measures text by roughly half, so without
/// the `FontLoader` every number here is fiction in both directions.
Future<void> _loadFonts() async {
  await (FontLoader(kSansFontFamily)..addFont(
        Future.value(
          File(
            'assets/fonts/InterTight.ttf',
          ).readAsBytesSync().buffer.asByteData(),
        ),
      ))
      .load();
}

/// A phone at 1080 physical / dpr 2.625 — the reporter's device.
const double kPixelWidth = 411.4;

/// The five sections every billing-doc edit strip has, in order.
List<String> _fixedLabels() {
  final l10n = bundledLocalization();
  return [
    l10n.lookup('details'),
    l10n.lookup('contacts'),
    l10n.lookup('items'),
    l10n.lookup('notes'),
    l10n.lookup('settings'),
  ];
}

String _label(String key) => bundledLocalization().lookup(key);

List<BillingDocEditTab> _tabs(List<String> labels) => [
  for (final label in labels)
    (label: label, body: Center(child: Text('body:$label'))),
];

Future<void> _pumpStrip(
  WidgetTester tester, {
  required List<String> labels,
  required double width,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 420,
                child: BillingDocEditTabStrip(tabs: _tabs(labels)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// How far the strip can scroll. Scoped to the `TabBar`'s own scrollable —
/// the `TabBarView` below it is a `Scrollable` too.
double _scrollExtent(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .maxScrollExtent;

Future<double> _extentFor(
  WidgetTester tester, {
  required List<String> labels,
  required double width,
  double textScale = 1.0,
}) async {
  await _pumpStrip(tester, labels: labels, width: width, textScale: textScale);
  return _scrollExtent(tester);
}

void main() {
  setUpAll(_loadFonts);

  group('the narrow billing-doc edit strip', () {
    testWidgets('fits a 411 px phone once PDF and E-Invoice are out', (
      tester,
    ) async {
      expect(
        await _extentFor(tester, labels: _fixedLabels(), width: kPixelWidth),
        0,
        reason:
            'five sections must not scroll on the device #140 was reported '
            'from',
      );
    });

    testWidgets('fits every phone the app targets down to 393 px', (
      tester,
    ) async {
      for (final width in const [393.0, 411.4, 430.0]) {
        expect(
          await _extentFor(tester, labels: _fixedLabels(), width: width),
          0,
          reason: 'no horizontal scroll at ${width}px',
        );
      }
    });

    testWidgets('re-adding either dropped tab would break the fit', (
      tester,
    ) async {
      for (final key in const ['pdf', 'e_invoice']) {
        expect(
          await _extentFor(
            tester,
            labels: [..._fixedLabels(), _label(key)],
            width: kPixelWidth,
          ),
          greaterThan(0),
          reason: 'a sixth tab ($key) puts the strip back over budget',
        );
      }
    });

    testWidgets('still scrolls where it honestly must — and that is what the '
        'edge fades are for', (tester) async {
      // A 360 px phone and Large text each blow the budget on their own; so
      // does German, whose labels are spelled out here rather than read from
      // `de.json` (the test bundle is English) — illustrative, not derived.
      expect(
        await _extentFor(tester, labels: _fixedLabels(), width: 360),
        greaterThan(0),
      );
      expect(
        await _extentFor(
          tester,
          labels: _fixedLabels(),
          width: kPixelWidth,
          textScale: 1.3,
        ),
        greaterThan(0),
      );
      expect(
        await _extentFor(
          tester,
          labels: const [
            'Details',
            'Kontakte',
            'Element',
            'Notizen',
            'Einstellungen',
          ],
          width: kPixelWidth,
        ),
        greaterThan(0),
      );
    });
  });

  group('the edge fades', () {
    // `scroll_edge_fades_test.dart` drives the leaf over a
    // `SingleChildScrollView`; every SHIPPED use wraps a `TabBar`, which
    // scrolls through its own controller inside a `ScrollConfiguration`.
    // That is a different notification path and it is the only one that
    // ships, so it gets asserted here against the real strip.
    testWidgets('a strip that fits draws neither fade', (tester) async {
      await _pumpStrip(tester, labels: _fixedLabels(), width: kPixelWidth);
      expect(find.byKey(ScrollEdgeFades.leadingFadeKey), findsNothing);
      expect(find.byKey(ScrollEdgeFades.trailingFadeKey), findsNothing);
    });

    testWidgets('an overflowing strip says so, without anyone scrolling', (
      tester,
    ) async {
      await _pumpStrip(tester, labels: _fixedLabels(), width: 320);
      expect(
        find.byKey(ScrollEdgeFades.leadingFadeKey),
        findsNothing,
        reason: 'sitting at minScrollExtent',
      );
      expect(find.byKey(ScrollEdgeFades.trailingFadeKey), findsOneWidget);
    });

    testWidgets('the pair follows the strip to its end', (tester) async {
      await _pumpStrip(tester, labels: _fixedLabels(), width: 320);
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(TabBar),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(find.byKey(ScrollEdgeFades.leadingFadeKey), findsOneWidget);
      expect(
        find.byKey(ScrollEdgeFades.trailingFadeKey),
        findsNothing,
        reason: 'nothing left beyond the end',
      );
    });
  });

  group('a changing tab count', () {
    // The one path that exercises this in production is the E-Invoice gate
    // landing a frame or two after mount and growing the strip under a live
    // `TabBar` + `TabBarView`; a resize across `Breakpoints.wide` shrinks it
    // the same way. A fixed `length:` throws on the grow and renders nothing
    // underlined on the shrink, and `SingleTickerProviderStateMixin` throws
    // "multiple tickers were created" on either.
    testWidgets('grows without throwing, keeping the selected tab', (
      tester,
    ) async {
      await _pumpStrip(tester, labels: _fixedLabels(), width: kPixelWidth);
      await tester.tap(find.text(_label('items')));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);

      await _pumpStrip(
        tester,
        labels: [..._fixedLabels(), _label('e_invoice')],
        width: kPixelWidth,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(_label('e_invoice')), findsOneWidget);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        2,
        reason: 'the user should not be moved off the tab they were reading',
      );
    });

    testWidgets('shrinks without stranding the index past the end', (
      tester,
    ) async {
      await _pumpStrip(
        tester,
        labels: [..._fixedLabels(), _label('pdf')],
        width: 700,
      );
      await tester.tap(find.text(_label('pdf')));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 5);

      await _pumpStrip(tester, labels: _fixedLabels(), width: kPixelWidth);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
        4,
        reason: 'clamped to the new last tab, not left out of range',
      );
      expect(find.text('body:${_label('settings')}'), findsOneWidget);
    });
  });
}
