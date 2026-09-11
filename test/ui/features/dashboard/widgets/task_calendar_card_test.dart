import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_card.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_grid_mini.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// The stateful half of the task-calendar panel. What is asserted here is
/// everything that is silent if it breaks: the two navigation strings, the
/// company rebind, the refresh hook, and — the one that no other test in this
/// repo could catch — that the card keeps itself alive when scrolled out of the
/// dashboard's `ListView`.

/// A one-value stream that survives re-subscription: the card's view model
/// listens once, but a rebuild that replaces the view model listens again, and
/// a single-subscription stream would throw the second time.
Stream<T> _oneShot<T>(T value) => Stream<T>.multi((c) {
  c.add(value);
  c.close();
});

class _FakeTaskRepo implements TaskRepository {
  int watchCalls = 0;
  final List<String> watchedCompanies = [];
  int fetchCalls = 0;

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) {
    watchCalls++;
    watchedCompanies.add(companyId);
    return _oneShot(const <Task>[]);
  }

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    states = const {},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    fetchCalls++;
    return false;
  }

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.tasks);
  @override
  final TaskRepository tasks;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: '5',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: 'en',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

/// See the sibling grid test: intl ships only `en_US` initialised, and the
/// app loads the rest through `GlobalMaterialLocalizations`.
Future<void> _loadDateSymbols() =>
    GlobalMaterialLocalizations.delegate.load(const Locale('en'));

/// `DashboardCardFooterLink` carries a `chevron_right` of its own, so the month
/// nav is located by its widget rather than by the glyph — the same
/// discrimination two same-icon triggers in one tree always need.
Finder _navIcon(IconData icon) => find.widgetWithIcon(IconButton, icon);

Date _monthOnScreen(WidgetTester tester) => tester
    .widget<TaskCalendarGridMini>(find.byType(TaskCalendarGridMini))
    .month;

/// Records where the card navigated, without a real shell.
class _Nav {
  String? location;
}

/// Props the card is rebuilt with, swappable **without** remounting.
///
/// The card's own `didUpdateWidget` branches — the company rebind and the
/// refresh re-arm — are only exercised when the element survives the pump. A
/// helper that builds a fresh `GoRouter` per call would mint a new navigator
/// `GlobalKey` and re-inflate the whole subtree, and both branches would be
/// satisfied by the remount alone: a new view model watches the new company,
/// and the constructor's own fetch supplies the second request. Swapping a
/// `ValueNotifier` instead is what makes those assertions mean anything.
class _Props {
  const _Props({this.companyId = 'co', this.refreshNonce});
  final String companyId;
  final DateTime? refreshNonce;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required _FakeTaskRepo repo,
  required _Nav nav,
  required ValueNotifier<_Props> props,
  bool tall = false,
  ScrollController? controller,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ListView(
            controller: controller,
            children: [
              // Tall enough to push the card past the sliver's cache extent
              // when the test scrolls, which is what exercises keep-alive.
              if (tall) const SizedBox(height: 2000),
              ValueListenableBuilder<_Props>(
                valueListenable: props,
                builder: (context, p, _) => DashboardTaskCalendarCard(
                  companyId: p.companyId,
                  formatter: _formatter,
                  refreshNonce: p.refreshNonce,
                ),
              ),
              if (tall) const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, state) {
          nav.location = state.uri.toString();
          return const Scaffold(body: Text('tasks'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    Provider<Services>.value(
      value: _FakeServices(repo),
      child: MaterialApp.router(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(_loadDateSymbols);

  testWidgets('View all opens the full calendar view', (tester) async {
    final nav = _Nav();
    await _pumpCard(
      tester,
      repo: _FakeTaskRepo(),
      nav: nav,
      props: ValueNotifier(const _Props()),
    );
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(nav.location, '/tasks?view=calendar');
  });

  testWidgets('tapping a day opens that day in the daily view', (tester) async {
    // Both strings are spelled once in the card and are silent if typo'd —
    // go_router would simply render its error screen.
    final nav = _Nav();
    await _pumpCard(
      tester,
      repo: _FakeTaskRepo(),
      nav: nav,
      props: ValueNotifier(const _Props()),
    );
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(nav.location, startsWith('/tasks?view=daily&date='));
    expect(nav.location, matches(RegExp(r'date=\d{4}-\d{2}-\d{2}$')));
  });

  testWidgets('Today is hidden on the current month and appears once off it', (
    tester,
  ) async {
    // An always-on Today would do nothing on the very month the panel opens to.
    await _pumpCard(
      tester,
      repo: _FakeTaskRepo(),
      nav: _Nav(),
      props: ValueNotifier(const _Props()),
    );
    expect(find.byIcon(Icons.today_outlined), findsNothing);

    await tester.tap(_navIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.byIcon(Icons.today_outlined), findsOneWidget);

    await tester.tap(_navIcon(Icons.today_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.today_outlined), findsNothing);
  });

  testWidgets('a company change rebinds the watch in place', (tester) async {
    final repo = _FakeTaskRepo();
    final props = ValueNotifier(const _Props());
    addTearDown(props.dispose);
    await _pumpCard(tester, repo: repo, nav: _Nav(), props: props);
    expect(repo.watchedCompanies, ['co']);

    final before = tester.state<State<DashboardTaskCalendarCard>>(
      find.byType(DashboardTaskCalendarCard),
    );

    props.value = const _Props(companyId: 'other');
    await tester.pump();

    expect(repo.watchedCompanies.last, 'other');
    // The State survived, so `didUpdateWidget` is what rebound — a helper that
    // re-inflates the subtree instead would satisfy the line above on its own
    // and leave the branch untested. (The month resetting is correct here: a
    // new company gets a new view model.)
    expect(
      tester.state<State<DashboardTaskCalendarCard>>(
        find.byType(DashboardTaskCalendarCard),
      ),
      same(before),
    );
  });

  testWidgets("the dashboard's FIRST refresh stamp does not refetch", (
    tester,
  ) async {
    // `lastRefreshed` starts null and is stamped when the dashboard's own load
    // lands — which carries no task data, since `refreshAll` walks the
    // cache-backed kinds only. Re-arming on that edge made every cold start
    // fetch the window twice, the second walk racing the constructor's.
    final repo = _FakeTaskRepo();
    final props = ValueNotifier(const _Props());
    addTearDown(props.dispose);
    await _pumpCard(tester, repo: repo, nav: _Nav(), props: props);
    expect(repo.fetchCalls, 1);

    props.value = _Props(refreshNonce: DateTime(2026, 6, 15, 12));
    await tester.pump();
    await tester.pump();
    expect(repo.fetchCalls, 1, reason: 'null → first stamp is not a refresh');
  });

  testWidgets('a later refresh stamp re-arms the window fetch', (tester) async {
    // Pull-to-refresh runs the cache-backed kinds only, so without this hook
    // the one gesture a user makes on a stale dashboard skips this panel.
    final repo = _FakeTaskRepo();
    final props = ValueNotifier(
      _Props(refreshNonce: DateTime(2026, 6, 15, 12)),
    );
    addTearDown(props.dispose);
    await _pumpCard(tester, repo: repo, nav: _Nav(), props: props);
    expect(repo.fetchCalls, 1);

    props.value = _Props(refreshNonce: DateTime(2026, 6, 15, 13));
    await tester.pump();
    await tester.pump();
    expect(repo.fetchCalls, 2);
  });

  testWidgets('it survives the wide grid\'s IntrinsicHeight', (tester) async {
    // `_MultiColumnGrid` wraps each two-column row in `IntrinsicHeight` and
    // stretches its children, so the card is asked for its intrinsic height and
    // then laid out taller than it wants. A `LayoutBuilder` anywhere under it
    // would throw on that query in debug and silently answer 0 in release —
    // and `dashboard_screen_test.dart` never builds the body, so nothing else
    // in the suite exercises this shape.
    final repo = _FakeTaskRepo();
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(repo),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DashboardTaskCalendarCard(
                        companyId: 'co',
                        formatter: _formatter,
                        refreshNonce: null,
                      ),
                    ),
                    // A taller sibling, so the card really is stretched rather
                    // than being the one that sets the row's height.
                    const Expanded(child: SizedBox(height: 900)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TaskCalendarGridMini), findsOneWidget);
    // Stretched, but the grid keeps its own geometry: the slack falls below it
    // rather than inflating the week rows out of square.
    expect(
      tester.getSize(find.byType(TaskCalendarGridMini)).height,
      lessThan(900),
    );
  });

  testWidgets('it survives being scrolled out of the dashboard list', (
    tester,
  ) async {
    // The finding no other test here could see: both dashboard bodies are
    // lazily-collected `ListView`s and this panel is appended LAST, so it
    // starts off-screen. Without `AutomaticKeepAliveClientMixin` the state —
    // view model, Drift subscription, the month the user paged to, the fetch
    // latch — is collected past the cache extent, and scrolling back would
    // reset the month and re-request.
    final repo = _FakeTaskRepo();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pumpCard(
      tester,
      repo: repo,
      nav: _Nav(),
      props: ValueNotifier(const _Props()),
      tall: true,
      controller: controller,
    );

    controller.jumpTo(2000);
    await tester.pumpAndSettle();
    await tester.tap(_navIcon(Icons.chevron_right));
    await tester.pump();

    final month = _monthOnScreen(tester);
    final watchesBefore = repo.watchCalls;
    final fetchesBefore = repo.fetchCalls;

    // Far past the cache extent, then back.
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    controller.jumpTo(2000);
    await tester.pumpAndSettle();

    expect(
      _monthOnScreen(tester),
      month,
      reason: 'the month the user paged to must survive a scroll',
    );
    expect(repo.watchCalls, watchesBefore, reason: 'no re-subscription');
    expect(repo.fetchCalls, fetchesBefore, reason: 'no re-request');
  });
}
