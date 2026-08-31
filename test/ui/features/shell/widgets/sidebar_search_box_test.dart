import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/shell/widgets/nav_history_buttons.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_search_box.dart';

import '../../../../_localization_helper.dart';

/// The sidebar's global-search box, and the toolbar row it shares with the
/// back/forward arrows (issue #101 moved it out of `SidebarHeader`, whose
/// full-width row cost the nav list ~52 px).
///
/// Global search reached the mobile UI late: the command palette had only the
/// `⌘/` shortcut and a hover-revealed icon on the Dashboard row, neither of
/// which exists on a phone. That is why this control is touch-only, and why
/// there is a wiring scan below — nothing widget-tests `InSidebar`, so without
/// it, deleting the mount would break no test at all.

const _kRowKey = Key('sidebar-toolbar-row');

/// Mirrors `in_sidebar.dart`'s nav-row padding. Hand-copied, so changing the
/// call site leaves the width tests green while the app truncates — the wiring
/// scan is what notices the mount, not this.
const _kRowPadding = EdgeInsets.fromLTRB(10, 4, 14, 0);

class _FakeRouter extends ChangeNotifier {
  String path = '/';
  void go(String next) {
    path = next;
    notifyListeners();
  }
}

AuthSession _session() => AuthSession(
  baseUrl: 'https://example.com',
  isHosted: true,
  accountId: 'acc',
  companies: const [],
  currentCompanyId: 'co_1',
);

/// The real app theme, not `ThemeData.light()` + the extension: only
/// `buildInTheme` sets `fontFamily: kSansFontFamily`, and without it the
/// label falls back to the test placeholder face (every glyph a full em
/// square) and the width assertions below measure fiction.
ThemeData _theme() => buildInTheme(InTheme.light);

void main() {
  late _FakeRouter router;
  late ValueNotifier<AuthSession?> session;
  late NavHistoryController history;
  late int taps;

  // File-scoped, not per-test: `flutter test` otherwise renders a placeholder
  // face whose every glyph is a full em square, which would make `Rechercher`
  // measure 130 px instead of Inter Tight's 64.5 and turn every width
  // assertion below into fiction.
  setUpAll(_loadInterTight);

  setUp(() {
    router = _FakeRouter();
    session = ValueNotifier<AuthSession?>(_session());
    history = NavHistoryController(
      changes: router,
      currentPath: () => router.path,
      navigate: router.go,
      session: session,
    );
    taps = 0;
  });

  tearDown(() {
    history.dispose();
    session.dispose();
  });

  /// The real composition from `in_sidebar.dart`: arrows leading, search box
  /// taking the rest. [searchLabel] swaps the `search` string for a longer
  /// translation without touching the rest of the bundle.
  Widget wrapRow({
    required double railWidth,
    bool touch = true,
    bool compact = false,
    bool showSearch = true,
    double textScale = 1.0,
    String? searchLabel,
  }) {
    return ChangeNotifierProvider<NavHistoryController>.value(
      value: history,
      child: MaterialApp(
        theme: _theme(),
        localizationsDelegates: searchLabel == null
            ? kTestLocalizationsDelegates
            : [_SearchOverrideDelegate(searchLabel)],
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: railWidth,
                  child: Padding(
                    padding: compact
                        ? const EdgeInsets.only(top: 4)
                        : _kRowPadding,
                    child: Row(
                      key: _kRowKey,
                      children: [
                        NavHistoryButtons(compact: compact, touch: touch),
                        if (showSearch)
                          Expanded(
                            child: SidebarSearchBox(onTap: () => taps++),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('the box itself', () {
    testWidgets('renders and invokes the callback', (tester) async {
      await tester.pumpWidget(wrapRow(railWidth: 280));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      await tester.tap(find.byType(SidebarSearchBox));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('meets the touch-target floor on both surfaces', (
      tester,
    ) async {
      for (final width in [280.0, 232.0]) {
        await tester.pumpWidget(wrapRow(railWidth: width));
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byType(SidebarSearchBox));
        expect(
          size.width,
          greaterThanOrEqualTo(InSizes.touchTarget),
          reason: 'rail width $width',
        );
        expect(size.height, greaterThanOrEqualTo(InSizes.touchTarget));
      }
    });

    testWidgets('does not overflow at 1.4x text scale', (tester) async {
      // Minimum-only constraints: the box grows with the label's line box
      // rather than clipping Inter Tight's descenders.
      await tester.pumpWidget(wrapRow(railWidth: 232, textScale: 1.4));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the toolbar row', () {
    testWidgets('lays out at the drawer and rail widths without overflow', (
      tester,
    ) async {
      for (final width in [280.0, 232.0]) {
        await tester.pumpWidget(wrapRow(railWidth: width));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'rail width $width');
        // 44, not 48: `_HistoryButton` sets `tapTargetSize: shrinkWrap`, so
        // `materialTapTargetSize: padded` can't inflate the arrows to
        // `kMinInteractiveDimension` and push the row 4 px taller.
        expect(tester.getSize(find.byKey(_kRowKey)).height, 44);
      }
    });

    testWidgets('the collapsed rail has zero slack and must stay bare', (
      tester,
    ) async {
      // 2x32 arrows fill 64 px exactly, with no horizontal padding — which is
      // why `InSidebar` gates the box off here. Any change to
      // `_HistoryButton`'s compact width overflows silently under the
      // sidebar's `ClipRect`.
      await tester.pumpWidget(
        wrapRow(railWidth: 64, compact: true, showSearch: false),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Measure the arrows, not the Row: `SizedBox(width: 64)` is a tight
      // constraint and the Row is `MainAxisSize.max`, so the Row reports 64
      // whatever its children do. Over-fill is caught by `takeException`
      // above; under-fill is what this line is for — the pair must still
      // exactly fill the rail, because `NavHistoryButtons` centres itself in
      // compact mode and centring is invisible when free space is zero.
      expect(tester.getSize(find.byType(NavHistoryButtons)).width, 64);
    });
  });

  group('label truncation', () {
    // The tightest surface in the app: the 232-px rail, where the box is 120
    // wide and the label slot 82. `Rechercher` (fr, the widest bundled
    // `search`) is 64.5 px at 13 pt, so this had ~3.5 px of slack before the
    // box's padding was trimmed from 8 to 6 — it truncated from 1.06x, below
    // the app's own Large setting. `composeTextScaler` multiplies the OS
    // scaler, so an iPad at iOS Larger Text hits that at Normal.
    for (final scale in [1.0, kTextScaleLarge]) {
      testWidgets('the longest bundled label fits the 232 rail at ${scale}x', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrapRow(railWidth: 232, textScale: scale, searchLabel: 'Rechercher'),
        );
        await tester.pumpAndSettle();

        final box = tester.renderObject<RenderBox>(find.text('Rechercher'));
        expect(
          box.size.width,
          greaterThanOrEqualTo(box.getMaxIntrinsicWidth(double.infinity)),
          reason:
              'a trailing ellipsis here leaves a magnifier beside two nav '
              'arrows with no readable label',
        );
      });
    }

    testWidgets('degrades to an ellipsis at Extra Large, and no further', (
      tester,
    ) async {
      // The honest boundary. 1.4 x 64.5 px = 90.3 in an 82 px slot, so the
      // widest bundled label *does* ellipsize at the top of the app's own
      // scale ladder — asserting only 1.0 and 1.2 above would be green over
      // exactly the range where the invariant holds and silent past it.
      // Accepted: the magnifier still identifies the control, and the box is
      // 44 px tall either way. What must NOT happen is an overflow.
      await tester.pumpWidget(
        wrapRow(
          railWidth: 232,
          textScale: kTextScaleExtraLarge,
          searchLabel: 'Rechercher',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final box = tester.renderObject<RenderBox>(find.text('Rechercher'));
      expect(
        box.size.width,
        lessThan(box.getMaxIntrinsicWidth(double.infinity)),
        reason:
            'if this ever passes the slot grew — widen the sweep above to '
            'kTextScaleExtraLarge and delete this test',
      );
    });
  });

  group('wiring', () {
    // Mirrors `nav_history_buttons_test.dart` / `resync_wiring_test.dart` /
    // `sidebar_nav_item_test.dart`: nothing widget-tests `InSidebar`, so this
    // is the only thing standing between a refactor and mobile global search
    // silently disappearing again.
    final sidebar = File(
      'lib/ui/features/shell/widgets/in_sidebar.dart',
    ).readAsStringSync();

    test('InSidebar mounts SidebarSearchBox, gated on touch', () {
      const marker = 'SidebarSearchBox(';
      final start = sidebar.indexOf(marker);
      expect(start, isNot(-1), reason: 'no SidebarSearchBox construction?');

      // The gate expression, not a particular statement form — this pinned
      // `if (touch && !collapsed)` and went red the day the mount became a
      // ternary, reporting a removed gate that was right there.
      expect(
        sidebar.contains('touch && !collapsed'),
        isTrue,
        reason:
            'the box is touch-only (desktop has ⌘/ and the Dashboard hover '
            'icon) and has no room in the 64-px collapsed rail',
      );

      final body = sidebar.substring(
        start,
        (start + 600).clamp(0, sidebar.length),
      );
      expect(
        body.contains('onBeforeModal'),
        isTrue,
        reason:
            'the drawer must pop before the palette opens, or the modal '
            'stacks on top of an open drawer',
      );
      expect(
        body.contains('showCommandPalette(context)'),
        isTrue,
        reason: 'the box exists to open the command palette',
      );
      expect(
        sidebar.indexOf('onBeforeModal', start),
        lessThan(sidebar.indexOf('showCommandPalette(context)', start)),
        reason: 'pop the drawer first, then open the palette',
      );
    });
  });
}

/// Renders every key as English except `search`, so the width sweep can stand
/// the box up under a translation longer than the English bundle has.
/// `Localization.forTesting` returns an instance, and the shared
/// `SyncLocalizationDelegate` is `const` and hard-wires the English bundle —
/// there is no injection seam without a local delegate. The `enStrings()`
/// spread is load-bearing: with a one-key map `NavHistoryButtons`'
/// `context.tr('go_back')` renders the raw key.
class _SearchOverrideDelegate extends LocalizationsDelegate<Localization> {
  const _SearchOverrideDelegate(this.search);

  final String search;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) => SynchronousFuture(
    Localization.forTesting(
      strings: {...enStrings(), 'search': search},
      pending: pendingStrings(),
    ),
  );

  @override
  bool shouldReload(LocalizationsDelegate<Localization> old) => false;
}

/// Loads the bundled variable TTF so text measures at its real width.
Future<void> _loadInterTight() async {
  final loader = FontLoader(kSansFontFamily)
    ..addFont(
      Future.value(
        File(
          'assets/fonts/InterTight.ttf',
        ).readAsBytesSync().buffer.asByteData(),
      ),
    );
  await loader.load();
}
