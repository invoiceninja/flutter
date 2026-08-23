import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_mobile_app_bar.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// flutter#50: the mobile dashboard bar used to title with the active company
/// name, which truncated on most real names and made this the only screen in
/// the app whose bar isn't its own page name. It now reads "Dashboard" — the
/// same `'dashboard'` key the sidebar nav row uses.
///
/// Swapping the string was not enough on its own: with four actions the title
/// slot is 80 dp on a 360 dp phone and "Dashboard" measures 104, so the word
/// truncated anyway. `titleSpacing: 0` is what buys the difference, and
/// 'the title is not truncated on a 360 dp phone' below is what pins it.
///
/// The hamburger assertions guard a second thing found while making that
/// change: the leading slot used to be an unconditional `DrawerHamburger`,
/// while the drawer it opens is attached only below the global-nav breakpoint.
/// Between those two conditions (a window of 600–832 px, where the 232 px rail
/// leaves this screen under 600) the button rendered beside the persistent rail
/// and did nothing — `Scaffold.of(context).openDrawer()` no-ops against a null
/// drawer.
///
/// Pumped without a `Provider<Services>` harness, exactly like
/// `dashboard_top_bar_test.dart`. That is why the bar is its own widget: the
/// screen can't be pumped at all (its VM constructor runs `unawaited(_init())`
/// into real Drift watch streams).
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  // Loaded for the whole file, not inside one test: `flutter test` otherwise
  // renders a placeholder face whose every glyph is a full em square, which
  // makes "Dashboard" measure 198 dp instead of Inter Tight's 104 and turns any
  // width assertion into fiction. Scoping it to a single test made every later
  // test in the file inherit it by declaration order — so running a group in
  // isolation silently measured something else.
  setUpAll(_loadInterTight);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      // As in `dashboard_top_bar_test.dart`: the default 500 ms nav_state
      // debounce outlives the pump and trips the pending-Timer invariant.
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  /// Mirrors the screen: the drawer is attached on the same condition that
  /// decides the hamburger, so passing them independently here would hide the
  /// very mismatch these tests exist to pin.
  Future<void> pumpBar(
    WidgetTester tester, {
    bool showHamburger = true,
    VoidCallback? onNewInvoice,
    double? width,
    String? title,
  }) async {
    if (width != null) {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: title == null
            ? kTestLocalizationsDelegates
            : [_TitleOverrideDelegate(title)],
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          appBar: DashboardMobileAppBar(
            vm: vm,
            showHamburger: showHamburger,
            onNewInvoice: onNewInvoice,
          ),
          drawer: showHamburger ? const Drawer() : null,
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('titles with the page name, not the company', (tester) async {
    await pumpBar(tester);

    expect(find.text('Dashboard'), findsOneWidget);
  });

  // The company-name assertion this replaced could not fail — the widget has no
  // company parameter, so nothing it renders could ever have been one. This
  // pins what actually matters: the title is read from the `dashboard` key
  // rather than hardcoded, which is what keeps it translated.
  testWidgets('the title comes from the dashboard key, not a literal', (
    tester,
  ) async {
    await pumpBar(tester, title: 'Übersicht');

    expect(find.text('Übersicht'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('the title ellipsises rather than overflowing', (tester) async {
    await pumpBar(tester, onNewInvoice: () {});

    final title = tester.widget<Text>(find.text('Dashboard'));
    expect(
      title.overflow,
      TextOverflow.ellipsis,
      reason:
          'even with titleSpacing 0 a 320 dp handset leaves the title 72 dp, '
          'and "Pannello di Controllo" (it, 192 dp) overruns every phone',
    );
  });

  testWidgets('shows the hamburger below the global-nav breakpoint', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.byType(DrawerHamburger), findsOneWidget);
  });

  testWidgets('drops the hamburger once the persistent rail is up', (
    tester,
  ) async {
    await pumpBar(tester, showHamburger: false);

    expect(
      find.byType(DrawerHamburger),
      findsNothing,
      reason: 'the drawer is null there, so the button would open nothing',
    );
    expect(
      find.byIcon(Icons.menu),
      findsNothing,
      reason: 'no menu affordance of any kind in the leading slot',
    );
  });

  // Without a leading widget `NavigationToolbar` starts the title at
  // `leadingWidth + titleSpacing`, so a flat `titleSpacing: 0` renders it at
  // x=0 — and in this band x=0 is the sidebar's right border, because the shell
  // insets content with a bare `Positioned.fill(left: railWidth)`. The spacing
  // is conditional for exactly this reason; nothing else in the file measures
  // the no-hamburger layout.
  testWidgets('the title keeps its inset when the hamburger is gone', (
    tester,
  ) async {
    await pumpBar(
      tester,
      width: 468,
      showHamburger: false,
      onNewInvoice: () {},
    );

    expect(
      tester.getTopLeft(find.text('Dashboard')).dx,
      greaterThan(0),
      reason: 'the title would otherwise sit flush against the sidebar',
    );
  });

  testWidgets('renders the filter, settings and customize actions', (
    tester,
  ) async {
    await pumpBar(tester);

    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_customize_outlined), findsOneWidget);
  });

  testWidgets('the new-invoice action follows the module gate', (tester) async {
    await pumpBar(tester, onNewInvoice: () {});
    expect(find.byIcon(Icons.add), findsOneWidget);

    await pumpBar(tester);
    expect(
      find.byIcon(Icons.add),
      findsNothing,
      reason: 'null onNewInvoice means the invoices module is disabled',
    );
  });

  // The measurement that reflects what a user actually sees.
  //
  // 360 dp with every action is the tight case — the most common Android width,
  // and what flutter#50 was reported against. It is why the bar carries
  // `titleSpacing: 0`; with Material's default 16 the slot is 80 dp and the
  // title renders "Dashboa…". Sensitive to Inter Tight's metrics by design: if
  // a font bump pushes the word past the slot, the title starts truncating
  // again and this should fail.
  testWidgets('the title is not truncated on a 360 dp phone', (tester) async {
    await pumpBar(tester, width: 360, onNewInvoice: () {});

    final box = tester.renderObject<RenderBox>(find.text('Dashboard'));
    expect(
      box.size.width,
      greaterThanOrEqualTo(box.getMaxIntrinsicWidth(double.infinity)),
      reason:
          'the whole word must fit — a trailing ellipsis here is the bug '
          'flutter#50 reported',
    );
  });

  // The bar is at its widest when every action is present, and narrowest on a
  // 320 px handset. `Pannello di Controllo` is it.json's `dashboard` at time of
  // writing — the longest shipped translation, and the reason the title keeps
  // an explicit `overflow` the other screens' bare `Text` titles don't need.
  //
  // What this can and can't catch (same caveat `_responsive_helper.dart`
  // states): an ellipsised or clipped `Text` throws nothing, so dropping the
  // title's `overflow` keeps this group green — that is pinned directly by
  // 'the title ellipsises rather than overflowing' above. What these guard is
  // the *action row*: a hamburger plus four 48 dp icons against a 320 dp bar.
  group('across handset widths', () {
    for (final width in const <double>[320, 360, 414]) {
      testWidgets('@ ${width.toInt()}px with every action', (tester) async {
        await pumpBar(tester, width: width, onNewInvoice: () {});

        expect(
          tester.takeException(),
          isNull,
          reason: 'layout overflow at this width',
        );
      });

      testWidgets('@ ${width.toInt()}px with the longest locale', (
        tester,
      ) async {
        await pumpBar(
          tester,
          width: width,
          onNewInvoice: () {},
          title: 'Pannello di Controllo',
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'the actions must survive a title that eats the slack',
        );
        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    }
  });
}

/// Renders every key as English except `dashboard`, so a width sweep can stand
/// the bar up under a translation longer than any the English bundle has.
class _TitleOverrideDelegate extends LocalizationsDelegate<Localization> {
  const _TitleOverrideDelegate(this.title);

  final String title;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<Localization> load(Locale locale) => SynchronousFuture(
    Localization.forTesting(
      strings: {...enStrings(), 'dashboard': title},
      pending: pendingStrings(),
    ),
  );

  @override
  bool shouldReload(LocalizationsDelegate<Localization> old) => false;
}

/// Loads the bundled variable TTF so text measures at its real width. Without
/// it every glyph is a full em square and width assertions are meaningless.
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
