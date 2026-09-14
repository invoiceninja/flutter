import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/entity_list_status_tabs.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/billing_pipeline_card.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// The stateful half of the Invoices & Quotes panel. What is asserted here is
/// everything that is silent if it breaks: that it keeps itself alive when
/// scrolled out of the dashboard's `ListView`, that the company rebind and the
/// refresh hook fire, that a tab tap re-subscribes the right halves, and — the
/// one no other test in this repo could catch — that a quote-only tab never
/// asks the invoice side for a mode its DAO would ignore.

/// A one-value stream that survives re-subscription: the card's view model
/// listens once, but a tab switch or a rebuild listens again, and a
/// single-subscription stream would throw the second time.
Stream<T> _multi<T>(T value) => Stream<T>.multi((c) {
  c.add(value);
  c.close();
});

Invoice _invoice(String id, {InvoiceStatus? status}) => emptyInvoice().copyWith(
  id: id,
  number: id,
  clientId: 'c1',
  statusId: status ?? InvoiceStatus.sent,
  date: Date(2026, 9, 14),
  amount: Decimal.fromInt(100),
  balance: Decimal.fromInt(100),
  createdAt: DateTime.utc(2026, 9, 14),
);

Quote _quote(String id, {QuoteStatus? status}) => emptyQuote().copyWith(
  id: id,
  number: id,
  clientId: 'c1',
  statusId: status ?? QuoteStatus.draft,
  date: Date(2026, 9, 13),
  amount: Decimal.fromInt(50),
  balance: Decimal.fromInt(50),
  createdAt: DateTime.utc(2026, 9, 13),
);

class _FakeInvoiceRepo implements InvoiceRepository {
  _FakeInvoiceRepo({this.rows = const []});
  List<Invoice> rows;

  /// Throws *before* any `await`, the one shape that can outrun the caller's
  /// in-flight bookkeeping.
  bool throwSynchronously = false;
  int fetchAttempts = 0;
  final List<String?> watchedModes = [];
  final List<Map<String, Set<String>>> fetches = [];
  final List<bool> fetchIgnoredCursor = [];

  @override
  Stream<List<Invoice>> watchRecent({
    required String companyId,
    required int limit,
    String? badgeModeId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    watchedModes.add(badgeModeId);
    return _multi(rows);
  }

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) {
    fetchAttempts++;
    if (throwSynchronously) throw StateError('boom');
    fetches.add(extraFilters);
    fetchIgnoredCursor.add(ignoreCursor);
    return Future<bool>.value(false);
  }

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeQuoteRepo implements QuoteRepository {
  _FakeQuoteRepo({this.rows = const []});
  List<Quote> rows;

  /// Makes `ensurePageLoaded` report another page, so a bounded walk walks.
  bool hasMore = false;
  final List<String?> watchedModes = [];
  final List<Map<String, Set<String>>> fetches = [];

  @override
  Stream<List<Quote>> watchRecent({
    required String companyId,
    required int limit,
    String? badgeModeId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    watchedModes.add(badgeModeId);
    return _multi(rows);
  }

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    fetches.add(extraFilters);
    return hasMore;
  }

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeClientRepo implements ClientRepository {
  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {}

  @override
  Client? peek({required String companyId, required String id}) => null;

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      _multi<Client?>(null);

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

EntityHandlers _handlers(
  EntityType type,
  String wire,
  String route,
  List<SidebarBadgeMode> modes,
) => EntityHandlers(
  type: type,
  wireName: wire,
  apiPath: route,
  routePath: route,
  icon: Icons.receipt_long,
  dispatcher: _NoopDispatcher(),
  badgeModes: modes,
  // Non-null so `entityRecordPath` resolves to `/<route>/<id>` rather than
  // appending `/edit` — the panel opens the detail screen.
  detailBuilder: (_, _) => const SizedBox.shrink(),
);

class _NoopDispatcher implements SyncDispatcher {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// `ClientNameLabel` reads the active company off the session to scope its
/// lookup, so a card that renders a single row needs this seam too.
class _FakeAuth implements AuthRepository {
  @override
  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({
    required this.invoices,
    required this.quotes,
    required this.clients,
  });
  @override
  final InvoiceRepository invoices;
  @override
  final QuoteRepository quotes;
  @override
  final ClientRepository clients;
  @override
  final AuthRepository auth = _FakeAuth();

  final List<(EntityType, String)> counted = [];

  // The card builds its tab set from the two entities' own `badgeModes` and
  // resolves a row tap through `routePath`, so both have to be real — the
  // catalogs especially: with the default two-mode fallback the strip would
  // collapse to `All` and every tab assertion here would pass vacuously.
  @override
  final EntityRegistry entityRegistry = EntityRegistry({
    EntityType.invoice: _handlers(
      EntityType.invoice,
      'invoice',
      '/invoices',
      kInvoiceBadgeModes,
    ),
    EntityType.quote: _handlers(
      EntityType.quote,
      'quote',
      '/quotes',
      kQuoteBadgeModes,
    ),
  });

  @override
  Stream<int> watchEntityCount(
    EntityType type,
    String companyId, {
    String modeId = 'total',
  }) {
    counted.add((type, modeId));
    return _multi(0);
  }

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

class _Nav {
  String? location;
}

/// Props swappable **without** remounting, so `didUpdateWidget`'s branches are
/// genuinely exercised rather than satisfied by a fresh element.
class _Props {
  const _Props({this.companyId = 'co', this.refreshNonce, this.initialTabId});
  final String companyId;
  final DateTime? refreshNonce;

  /// Swappable so a test can deliver the restored tab AFTER mount, which is
  /// the only ordering production ever produces.
  final String? initialTabId;
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeServices services,
  required _Nav nav,
  ValueNotifier<_Props>? props,
  bool narrow = true,
  bool tall = false,
  String? initialTabId,
  void Function(String?)? onTabChanged,
  ScrollController? controller,
}) async {
  final p = props ?? ValueNotifier(const _Props());
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ListView(
            controller: controller,
            children: [
              if (tall) const SizedBox(height: 2000),
              ValueListenableBuilder<_Props>(
                valueListenable: p,
                builder: (context, v, _) => DashboardBillingPipelineCard(
                  companyId: v.companyId,
                  formatter: _formatter,
                  refreshNonce: v.refreshNonce,
                  narrow: narrow,
                  includeInvoices: true,
                  includeQuotes: true,
                  initialTabId: v.initialTabId ?? initialTabId,
                  onTabChanged: onTabChanged ?? (_) {},
                ),
              ),
              if (tall) const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
      for (final path in ['/invoices', '/quotes'])
        GoRoute(
          path: path,
          builder: (context, state) {
            nav.location = state.uri.toString();
            return Scaffold(body: Text('list $path'));
          },
        ),
      GoRoute(
        path: '/invoices/:id',
        builder: (context, state) {
          nav.location = state.uri.toString();
          return const Scaffold(body: Text('invoice'));
        },
      ),
      GoRoute(
        path: '/quotes/:id',
        builder: (context, state) {
          nav.location = state.uri.toString();
          return const Scaffold(body: Text('quote'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    Provider<Services>.value(
      value: services,
      child: MaterialApp.router(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

_FakeServices _services({
  List<Invoice> invoices = const [],
  List<Quote> quotes = const [],
}) => _FakeServices(
  invoices: _FakeInvoiceRepo(rows: invoices),
  quotes: _FakeQuoteRepo(rows: quotes),
  clients: _FakeClientRepo(),
);

/// intl ships only `en_US` initialised; the app loads the rest through
/// `GlobalMaterialLocalizations`, and a row that formats a date needs them.
Future<void> _loadDateSymbols() =>
    GlobalMaterialLocalizations.delegate.load(const Locale('en'));

int _selectedIndex(WidgetTester tester) => tester
    .widget<EntityListStatusTabs>(find.byType(EntityListStatusTabs))
    .selectedIndex;

void main() {
  setUpAll(_loadDateSymbols);

  testWidgets('renders the strip with All selected', (tester) async {
    await _pump(tester, services: _services(), nav: _Nav());
    expect(find.byType(EntityListStatusTabs), findsOneWidget);
    final strip = tester.widget<EntityListStatusTabs>(
      find.byType(EntityListStatusTabs),
    );
    expect(strip.selectedIndex, 0);
    // Wrapped, not scrolled: the whole point is that no count is off-screen.
    expect(strip.wrap, isTrue);
    expect(strip.tabs.map((t) => t.labelKey), [
      'all',
      'draft',
      'unpaid',
      'sent',
      'approved',
      'rejected',
      'expired',
    ]);
  });

  testWidgets('a quote-only tab never asks the invoice side for its mode', (
    tester,
  ) async {
    // THE test. `InvoiceDao.badgeModePredicate` returns null for 'approved',
    // and both DAO seams treat null as "no narrowing" — so forwarding the tab's
    // own id to both halves would list and count EVERY invoice in the company,
    // and it would type-check.
    final services = _services();
    await _pump(tester, services: services, nav: _Nav());

    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();

    final invoiceRepo = services.invoices as _FakeInvoiceRepo;
    final quoteRepo = services.quotes as _FakeQuoteRepo;
    expect(
      invoiceRepo.watchedModes,
      isNot(contains('approved')),
      reason: 'invoices do not participate in Approved',
    );
    expect(quoteRepo.watchedModes, contains('approved'));
    expect(
      services.counted,
      isNot(contains((EntityType.invoice, 'approved'))),
      reason: 'the count seam fails open the same way the row seam does',
    );
    expect(services.counted, contains((EntityType.quote, 'approved')));
  });

  testWidgets('a mixed tab subscribes both halves', (tester) async {
    final services = _services();
    await _pump(tester, services: services, nav: _Nav());
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    expect(
      (services.invoices as _FakeInvoiceRepo).watchedModes,
      contains('draft'),
    );
    expect((services.quotes as _FakeQuoteRepo).watchedModes, contains('draft'));
  });

  testWidgets('the top-up ignores the cursor, or it fetches only a delta', (
    tester,
  ) async {
    // An unnarrowed fetch is not a "narrowed fetch", so without `ignoreCursor`
    // `shouldReadCursor` sends the `updated_at >=` watermark and returns the
    // delta rather than a true first page — which would make the local-only
    // Rejected tab's top-up do nothing at all.
    final services = _services();
    await _pump(tester, services: services, nav: _Nav());
    await tester.pumpAndSettle();
    final repo = services.invoices as _FakeInvoiceRepo;
    expect(repo.fetchIgnoredCursor, isNotEmpty);
    expect(repo.fetchIgnoredCursor.every((v) => v), isTrue);
  });

  testWidgets('the All tab costs one request per entity, not five', (
    tester,
  ) async {
    // `All` is the tab the panel opens on, so this runs on the app's LANDING
    // route for both entities. A five-page walk each would add ten requests to
    // the cold-start fan-out to fill five rows that page 1 — sorted
    // newest-first — already contains.
    final services = _services();
    await _pump(tester, services: services, nav: _Nav());
    await tester.pumpAndSettle();
    expect((services.invoices as _FakeInvoiceRepo).fetches, hasLength(1));
    expect((services.quotes as _FakeQuoteRepo).fetches, hasLength(1));
  });

  testWidgets('a local-only tab walks pages; a server-narrowed one does not', (
    tester,
  ) async {
    // Rejected sends nothing (the server has no `client_status=rejected`), so
    // its rows can sit arbitrarily deep and the walk is the only mechanism it
    // has to reach the cache. Draft narrows server-side, so page 1 is enough.
    final deep = _FakeQuoteRepo()..hasMore = true;
    final services = _FakeServices(
      invoices: _FakeInvoiceRepo(),
      quotes: deep,
      clients: _FakeClientRepo(),
    );
    await _pump(tester, services: services, nav: _Nav());
    await tester.pumpAndSettle();
    deep.fetches.clear();

    await tester.tap(find.text('Rejected'));
    await tester.pumpAndSettle();
    expect(deep.fetches.length, greaterThan(1));
    expect(deep.fetches.every((f) => f.isEmpty), isTrue, reason: 'unnarrowed');

    deep.fetches.clear();
    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    expect(deep.fetches, hasLength(1));
    expect(deep.fetches.single, {
      'client_status': {'approved'},
    });
  });

  testWidgets('a synchronously-throwing fetch does not latch the tab off', (
    tester,
  ) async {
    // `_sweep` is `async`, so a throw before its first suspension runs the
    // body — `catch` and `finally` included — SYNCHRONOUSLY, i.e. before the
    // caller can store the in-flight future. A `finally` that released the key
    // there would leave an already-completed future parked in the map forever:
    // every later attempt returns it instantly, the tab is never marked
    // loaded, and `invalidateLoadedTabs` (which clears only `_loadedTabs`)
    // cannot recover it. Production repos suspend first, so only a
    // sync-throwing double reaches this — which is exactly what the widget
    // suites use.
    final throwing = _FakeInvoiceRepo()..throwSynchronously = true;
    final services = _FakeServices(
      invoices: throwing,
      quotes: _FakeQuoteRepo(),
      clients: _FakeClientRepo(),
    );
    await _pump(tester, services: services, nav: _Nav());
    await tester.pumpAndSettle();

    // The SAME bucket, twice — a different tab would take a different key and
    // pass either way, which is what makes this the only shape that catches it.
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    final afterFirst = throwing.fetchAttempts;
    expect(afterFirst, greaterThan(0), reason: 'it tried once');

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    expect(
      throwing.fetchAttempts,
      greaterThan(afterFirst),
      reason:
          'a failed sweep must release its key — otherwise the completed '
          'future stays parked and this bucket can never be retried',
    );
  });

  testWidgets('rows merge both entities, newest first', (tester) async {
    final services = _services(
      invoices: [_invoice('i1')], // 2026-09-14
      quotes: [_quote('q1')], // 2026-09-13
    );
    await _pump(tester, services: services, nav: _Nav());
    await tester.pumpAndSettle();
    final iy = tester.getTopLeft(find.textContaining('i1')).dy;
    final qy = tester.getTopLeft(find.textContaining('q1')).dy;
    expect(iy, lessThan(qy), reason: 'the later date leads');
  });

  testWidgets('a row opens its own record, by entity type', (tester) async {
    final nav = _Nav();
    await _pump(
      tester,
      services: _services(quotes: [_quote('q1')]),
      nav: nav,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('q1'));
    await tester.pumpAndSettle();
    expect(nav.location, '/quotes/q1');
  });

  testWidgets('the footer links carry the tab as a badge_mode intent', (
    tester,
  ) async {
    final nav = _Nav();
    await _pump(tester, services: _services(), nav: nav);
    await tester.tap(find.text('Expired'));
    await tester.pumpAndSettle();

    // Quote-only tab → one link, and it goes to quotes.
    expect(find.text('Invoices'), findsNothing);
    // The footer sits below the 600 px test viewport on this card.
    await tester.ensureVisible(find.text('Quotes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();
    expect(nav.location, '/quotes');
  });

  testWidgets('a user tap persists the tab; the initial render does not', (
    tester,
  ) async {
    final changes = <String?>[];
    await _pump(
      tester,
      services: _services(),
      nav: _Nav(),
      onTabChanged: changes.add,
    );
    expect(changes, isEmpty, reason: 'hydrate must not rewrite nav_state');
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    expect(changes, ['draft']);
  });

  testWidgets('a restored tab is selected; an unavailable one heals to All', (
    tester,
  ) async {
    await _pump(
      tester,
      services: _services(),
      nav: _Nav(),
      initialTabId: 'expired',
    );
    expect(
      tester
          .widget<EntityListStatusTabs>(find.byType(EntityListStatusTabs))
          .selectedIndex,
      6,
    );

    await _pump(
      tester,
      services: _services(),
      nav: _Nav(),
      initialTabId: 'not_a_mode',
    );
    expect(
      tester
          .widget<EntityListStatusTabs>(find.byType(EntityListStatusTabs))
          .selectedIndex,
      0,
      reason: 'an unknown stored tab degrades to All, not to nothing selected',
    );
  });

  testWidgets('a tab restored AFTER mount is still applied', (tester) async {
    // The ordering that actually happens in production, and the one the
    // mount-time test above cannot reach. `DashboardViewModel._hydrate` is an
    // async Drift read that does NOT notify, while the dashboard body mounts as
    // soon as its formatter resolves — which on a warm navigation is a
    // microtask. So the card mounts with a null `initialTabId` and only later
    // receives the restored one through a rebuild.
    final props = ValueNotifier(const _Props());
    addTearDown(props.dispose);
    await _pump(
      tester,
      services: _services(),
      nav: _Nav(),
      props: props,
      initialTabId: null,
    );
    expect(_selectedIndex(tester), 0, reason: 'mounts on All');

    props.value = const _Props(initialTabId: 'expired');
    await tester.pumpAndSettle();
    expect(
      _selectedIndex(tester),
      6,
      reason: 'the late-arriving restored tab must still apply',
    );
  });

  testWidgets('a tap before hydrate beats the late restored tab', (
    tester,
  ) async {
    // The latch that makes the fix above safe: a slow `nav_state` read must
    // never yank the user off a tab they have already chosen.
    final props = ValueNotifier(const _Props());
    addTearDown(props.dispose);
    await _pump(
      tester,
      services: _services(),
      nav: _Nav(),
      props: props,
      initialTabId: null,
    );
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 1);

    props.value = const _Props(initialTabId: 'expired');
    await tester.pumpAndSettle();
    expect(
      _selectedIndex(tester),
      1,
      reason: 'the user has already picked; hydrate must not clobber it',
    );
  });

  testWidgets('it survives being scrolled out of the dashboard list', (
    tester,
  ) async {
    // Both dashboard bodies are lazily-collected `ListView`s, so without
    // `AutomaticKeepAliveClientMixin` the card is garbage-collected past the
    // cache extent — taking the selected tab, the subscriptions and the fetch
    // latches with it.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      services: _services(),
      nav: _Nav(),
      tall: true,
      controller: controller,
    );
    // The card sits behind a 2000 px spacer, so bring it on screen first.
    controller.jumpTo(1900);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft'));
    await tester.pumpAndSettle();

    controller.jumpTo(3500);
    await tester.pumpAndSettle();
    controller.jumpTo(1900);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EntityListStatusTabs>(find.byType(EntityListStatusTabs))
          .selectedIndex,
      1,
      reason: 'the selected tab must survive the scroll',
    );
  });

  testWidgets('a refresh re-arms the fetch, but the first stamp does not', (
    tester,
  ) async {
    final services = _services();
    final props = ValueNotifier(const _Props());
    addTearDown(props.dispose);
    await _pump(tester, services: services, nav: _Nav(), props: props);
    await tester.pumpAndSettle();
    final repo = services.invoices as _FakeInvoiceRepo;
    final initial = repo.fetches.length;

    // null -> first stamp is the dashboard's initial load completing, not a
    // refresh. Re-arming on it makes every cold start fetch twice.
    props.value = _Props(refreshNonce: DateTime.utc(2026, 9, 14));
    await tester.pumpAndSettle();
    expect(
      repo.fetches.length,
      initial,
      reason: 'first stamp is not a refresh',
    );

    props.value = _Props(refreshNonce: DateTime.utc(2026, 9, 15));
    await tester.pumpAndSettle();
    expect(repo.fetches.length, greaterThan(initial));
  });

  testWidgets('a company switch rebinds the view model', (tester) async {
    final services = _services();
    final props = ValueNotifier(const _Props());
    addTearDown(props.dispose);
    await _pump(tester, services: services, nav: _Nav(), props: props);
    await tester.pumpAndSettle();
    final repo = services.invoices as _FakeInvoiceRepo;
    final before = repo.watchedModes.length;

    props.value = const _Props(companyId: 'other');
    await tester.pumpAndSettle();
    expect(repo.watchedModes.length, greaterThan(before));
  });
}
