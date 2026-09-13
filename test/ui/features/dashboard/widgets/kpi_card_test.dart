import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_card.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_sparkline.dart';

import '../../../../_localization_helper.dart';

/// Serves a sentinel for `vs_prior` so the delta-suffix test proves the string
/// came out of the bundle. The real English value is literally "vs prior", so
/// asserting on that would pass just as happily against a hardcoded literal.
class _SentinelLocalizationDelegate
    extends LocalizationsDelegate<Localization> {
  const _SentinelLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) => SynchronousFuture(
    Localization.forTesting(
      strings: const {'vs_prior': 'VS_PRIOR_FROM_BUNDLE'},
    ),
  );

  @override
  bool shouldReload(LocalizationsDelegate<Localization> old) => false;
}

Future<void> _pump(
  WidgetTester tester, {
  List<double>? sparkline,
  List<LocalizationsDelegate<dynamic>> delegates = kTestLocalizationsDelegates,
  VoidCallback? onTap,
  String? semanticsLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: delegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 140,
            child: KpiCard(
              label: 'Outstanding',
              value: r'$1,000',
              deltaPercent: 4.2,
              goodDirection: GoodDirection.down,
              sparklineValues: sparkline,
              onTap: onTap,
              semanticsLabel: semanticsLabel,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders no sparkline when sparklineValues is null', (
    tester,
  ) async {
    await _pump(tester, sparkline: null);
    expect(find.byType(KpiSparkline), findsNothing);
    // The real period-over-period signal (delta chip) still renders.
    expect(find.byType(DeltaChip), findsOneWidget);
  });

  testWidgets('renders the sparkline when real values are provided', (
    tester,
  ) async {
    await _pump(tester, sparkline: const [1, 2, 3, 4, 5]);
    expect(find.byType(KpiSparkline), findsOneWidget);
  });

  // The delta suffix was a hardcoded English literal here while both sibling
  // call sites (chart hero, mobile hero) already went through `vs_prior` — the
  // hardcoded-string lint misses it because it only scans `Text('...')`.
  testWidgets('delta suffix comes from the localization bundle', (
    tester,
  ) async {
    await _pump(
      tester,
      sparkline: null,
      delegates: const [_SentinelLocalizationDelegate()],
    );
    expect(find.text('VS_PRIOR_FROM_BUNDLE'), findsOneWidget);
  });

  testWidgets('a clickable card is a button a screen reader can invoke', (
    tester,
  ) async {
    // `ExcludeSemantics` drops the whole subtree, taking the `InkWell`'s own
    // `Semantics(onTap:)` with it — so the wrapper has to re-declare the
    // action it already declares the role for. Without that the card is
    // announced as a button that TalkBack and switch access cannot activate.
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      onTap: () => taps++,
      semanticsLabel: 'Outstanding, one thousand dollars',
    );

    final node = tester.getSemantics(find.byType(KpiCard));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    // Through the semantics layer, not `tester.tap` — the point is that an
    // assistive technology can invoke it, which is exactly what was broken.
    tester.semantics.tap(
      find.semantics.byLabel('Outstanding, one thousand dollars'),
    );
    await tester.pump();
    expect(taps, 1, reason: 're-declaring the action must actually run it');
    handle.dispose();
  });

  testWidgets('a non-clickable card declares neither role nor action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, semanticsLabel: 'Outstanding, one thousand dollars');
    final data = tester.getSemantics(find.byType(KpiCard)).getSemanticsData();
    expect(data.flagsCollection.isButton, isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });
}
