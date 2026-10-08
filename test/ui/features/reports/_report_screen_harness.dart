import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/data/repositories/schedule_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/views/report_screen.dart';
import 'package:admin/ui/features/reports/views/reports_gallery_screen.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

/// The bundled faces, so text measures as it does in the app. Without them
/// every glyph is a square of the font size, which hides exactly the
/// overflow a layout test is for.
Future<void> loadReportTestFonts() async {
  final fonts = [
    (kSansFontFamily, 'assets/fonts/InterTight.ttf'),
    (kMonoFontFamily, 'assets/fonts/JetBrainsMono.ttf'),
  ];
  // The icon font lives in the SDK, not the repo; with it a render shows
  // glyphs rather than boxes. Layout does not depend on it, so a machine
  // where it cannot be found loses nothing but the pictures.
  final flutter = Platform.environment['FLUTTER_ROOT'];
  if (flutter != null) {
    final icons = File(
      '$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) fonts.add(('MaterialIcons', icons.path));
  }
  for (final (family, file) in fonts) {
    final loader = FontLoader(family)
      ..addFont(Future.value(File(file).readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }
}

class NullStaticsService implements StaticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers every run with [preview] (or throws [error]), and counts them.
class FixtureReportsRepo implements ReportsRepository {
  FixtureReportsRepo(this.preview);

  ReportPreview preview;
  ReportError? error;
  final List<List<String>> requests = [];

  /// What a run for the period before answers with; null answers every
  /// run with [preview].
  ReportPreview? comparePreview;
  final List<ReportPayload> compareRequests = [];

  /// What a file-only report's export answers with; null fails it.
  String? exportCsv;
  ReportExportFormat exportFormat = ReportExportFormat.csv;
  int exports = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #runPreview) {
      requests.add(
        List<String>.from(
          invocation.namedArguments[#reportKeys] as List? ?? const [],
        ),
      );
      final e = error;
      if (e != null) return Future<ReportPreview>.error(e);
      // The comparison asks for the period before as a custom range; every
      // fixture's own range is a preset.
      final payload = invocation.namedArguments[#payload] as ReportPayload?;
      final earlier = comparePreview;
      if (earlier != null && payload?.datePreset == ReportDatePreset.custom) {
        compareRequests.add(payload!);
        return Future<ReportPreview>.value(earlier);
      }
      return Future<ReportPreview>.value(preview);
    }
    if (invocation.memberName == #runExport) {
      exports++;
      final e = error;
      if (e != null) return Future<ReportExportResult>.error(e);
      final csv = exportCsv;
      if (csv == null) {
        return Future<ReportExportResult>.error(
          const ReportError(kind: ReportErrorKind.serverError),
        );
      }
      return Future<ReportExportResult>.value(
        ReportExportResult(
          bytes: Uint8List.fromList(utf8.encode(csv)),
          hash: 'hash',
          format: exportFormat,
        ),
      );
    }
    if (invocation.memberName == #cachedPreview) {
      return Future<({ReportPreview preview, DateTime fetchedAt})?>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeAuth implements AuthRepository {
  final ValueNotifier<AuthSession?> _session = ValueNotifier(null);
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeTags implements TagRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #watchAll) {
      return Stream.value(const <Tag>[]);
    }
    throw UnimplementedError(invocation.memberName.toString());
  }
}

class _FakeDesigns implements DesignRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #watchAll) {
      return Stream.value(const <Design>[]);
    }
    throw UnimplementedError(invocation.memberName.toString());
  }
}

/// The real registry entries — route paths and icons — over a dispatcher
/// that is never reached: the gallery draws each report's icon from here, and
/// a row link resolves its destination here.
EntityRegistry reportTestRegistry() => EntityRegistry({
  for (final spec in kWiredEntityModules)
    spec.type: spec.toHandlers(DisabledEntityDispatcher(spec.type)),
});

class FakeSchedules implements ScheduleRepository {
  /// What the app "already holds"; a test sets it before pumping.
  List<Schedule> held = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #watchPage) return Stream.value(held);
    throw UnimplementedError(invocation.memberName.toString());
  }
}

/// Saved report views in memory. Not the real repository over the test
/// database: a live Drift watch stream under a mounted widget makes
/// `pumpAndSettle` wait for ever.
class FakeSavedViews implements SavedViewsRepository {
  final List<SavedReportView> views = [];
  final _changed = StreamController<void>.broadcast();
  var _next = 0;

  void _emit() => _changed.add(null);

  @override
  Stream<List<SavedReportView>> watchReportViews(String companyId) async* {
    yield List.of(views);
    await for (final _ in _changed.stream) {
      yield List.of(views);
    }
  }

  @override
  Future<SavedReportView?> reportView(String viewId) async =>
      views.where((v) => v.id == viewId).firstOrNull;

  @override
  Future<SavedReportView> createReportView({
    required String companyId,
    required String name,
    required String reportIdentifier,
    required Map<String, dynamic> state,
  }) async {
    final view = SavedReportView(
      id: 'view${_next++}',
      name: name,
      reportIdentifier: reportIdentifier,
      // Through JSON, as the table would hold it.
      state: jsonDecode(jsonEncode(state)) as Map<String, dynamic>,
      updatedAt: 0,
    );
    views.add(view);
    _emit();
    return view;
  }

  @override
  Future<void> updateReportView({
    required String viewId,
    required String reportIdentifier,
    required Map<String, dynamic> state,
  }) async {
    final at = views.indexWhere((v) => v.id == viewId);
    if (at < 0) return;
    views[at] = SavedReportView(
      id: viewId,
      name: views[at].name,
      reportIdentifier: reportIdentifier,
      state: jsonDecode(jsonEncode(state)) as Map<String, dynamic>,
      updatedAt: 1,
    );
    _emit();
  }

  @override
  Future<void> delete(String viewId) async {
    views.removeWhere((v) => v.id == viewId);
    _emit();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeReportServices implements Services {
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final EntityRegistry entityRegistry = reportTestRegistry();
  @override
  final SearchFocusRegistry searchFocus = SearchFocusRegistry();
  @override
  final FakeSchedules schedules = FakeSchedules();
  @override
  final FakeSavedViews savedViews = FakeSavedViews();
  @override
  final TagRepository tags = _FakeTags();
  @override
  final DesignRepository designs = _FakeDesigns();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _usd = {
  'id': '1',
  'name': 'US Dollar',
  'code': 'USD',
  'symbol': r'$',
  'precision': 2,
  'thousand_separator': ',',
  'decimal_separator': '.',
  'swap_currency_symbol': false,
  'exchange_rate': 1,
};

const _gbp = {
  'id': '2',
  'name': 'British Pound',
  'code': 'GBP',
  'symbol': '£',
  'precision': 2,
  'thousand_separator': ',',
  'decimal_separator': '.',
  'swap_currency_symbol': false,
  'exchange_rate': 1,
};

const _eur = {
  'id': '3',
  'name': 'Euro',
  'code': 'EUR',
  'symbol': '€',
  'precision': 2,
  'thousand_separator': '.',
  'decimal_separator': ',',
  'swap_currency_symbol': false,
  'exchange_rate': 1,
};

Formatter reportTestFormatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: {
    '1': Currency.fromMap(_usd),
    '2': Currency.fromMap(_gbp),
    '3': Currency.fromMap(_eur),
  },
  countries: const {},
  dateFormats: {
    CompanyFormatSettings.fallback.dateFormatId: const DatetimeFormat(
      id: '5',
      format: 'MMM d, y',
    ),
  },
);

ReportColumn reportTestColumn(String id, String label) => ReportColumn(
  identifier: id,
  displayLabel: label,
  type: inferColumnType(id),
);

const _clients = [
  'Acme Industrial',
  'Birch & Vine Studio',
  'Cobalt Freight',
  'Dunmore Legal',
  'Eastgate Dental',
  'Fennel Kitchen Co.',
  'Greywater Marine',
  'Halden Architects',
  'Ironbridge Tooling',
  'Juniper Health',
  'Kestrel Media',
  'Lowland Brewing',
];

const _statuses = ['Paid', 'Paid', 'Paid', 'Sent', 'Partial', 'Draft'];

/// An invoice report as the server answers one: [rows] invoices across the
/// months of [year], twelve clients, mixed statuses, and — with
/// [twoCurrencies] — every fifth client billed in euros.
///
/// Deterministic: the same arguments always build the same report.
ReportPreview invoiceReportFixture({
  int rows = 214,
  int year = 2026,
  bool twoCurrencies = false,
}) {
  var seed = 7;
  int next(int mod) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % mod;
  }

  final out = <ReportRow>[];
  for (var i = 0; i < rows; i++) {
    final client = next(_clients.length);
    // Weighted towards the middle of the year, so the series has a shape.
    final month = 1 + ((next(12) + next(12)) ~/ 2);
    final day = 1 + next(27);
    final status = _statuses[next(_statuses.length)];
    final amount = Decimal.fromInt(180 + next(4200) + (client == 0 ? 2600 : 0));
    final balance = switch (status) {
      'Paid' => Decimal.zero,
      'Partial' => (amount * Decimal.parse('0.4')).round(scale: 2),
      _ => amount,
    };
    final euro = twoCurrencies && client % 5 == 4;
    final date = Date(year, month, day);
    out.add(
      ReportRow(
        cells: [
          ReportStringCell(
            value: _clients[client],
            displayValue: _clients[client],
            entityWire: 'client',
            entityId: 'c$client',
          ),
          ReportStringCell(
            value: 'INV-${(1000 + i)}',
            displayValue: 'INV-${(1000 + i)}',
          ),
          ReportDateCell(value: date),
          ReportDateCell(value: Date(year, month, day).addDays(30)),
          ReportStringCell(value: status, displayValue: status),
          ReportNumberCell(value: amount, isMoney: true),
          ReportNumberCell(value: balance, isMoney: true),
          ReportNumberCell(value: amount - balance, isMoney: true),
          ReportStringCell(
            value: euro ? 'EUR' : 'USD',
            displayValue: euro ? 'EUR' : 'USD',
          ),
          ReportStringCell(value: 'PO-${next(900)}', displayValue: ''),
          ReportStringCell(value: 'i$i', displayValue: 'i$i'),
        ],
      ),
    );
  }
  return ReportPreview(
    columns: [
      reportTestColumn('client.name', 'Client'),
      reportTestColumn('invoice.number', 'Number'),
      reportTestColumn('invoice.date', 'Date'),
      reportTestColumn('invoice.due_date', 'Due Date'),
      reportTestColumn('invoice.status', 'Status'),
      reportTestColumn('invoice.amount', 'Amount'),
      reportTestColumn('invoice.balance', 'Balance'),
      reportTestColumn('invoice.paid_to_date', 'Paid to Date'),
      reportTestColumn('client.currency_id', 'Currency'),
      reportTestColumn('invoice.po_number', 'PO Number'),
      reportTestColumn('invoice.id', 'Id'),
    ],
    rows: out,
  );
}

final kDesktop = TargetPlatformVariant.only(TargetPlatform.macOS);
final kPhone = TargetPlatformVariant.only(TargetPlatform.iOS);

/// One of the server's own report files, as saved under
/// `test/domain/reports/fixtures/`.
String reportFileFixture(String name) =>
    File('test/domain/reports/fixtures/$name.csv').readAsStringSync();

/// What a test holds on to after [pumpReports].
class ReportScreenHarness {
  ReportScreenHarness(this.vm, this.repo, this.router, this.db);

  final ReportsViewModel vm;
  final FixtureReportsRepo repo;
  final GoRouter router;
  final AppDatabase db;
}

/// Mount the two Reports routes under a stand-in for `ReportsHost`: the same
/// view model, the same formatter scope, the real route shape.
///
/// [location] is where the app opens (`/reports`, `/reports/invoice`…).
/// [size] is the *pane* — there is no sidebar here.
///
/// `flutter test` runs as Android, which sizes every control for a finger.
/// A test of a wide pane wants [kDesktop] as its `variant:`; one of a phone
/// can say [kPhone] or leave the default.
Future<ReportScreenHarness> pumpReports(
  WidgetTester tester, {
  required ReportPreview preview,
  String location = '/reports/invoice',
  Size size = const Size(1200, 900),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  bool autoRun = true,
  DateTime Function()? now,
  void Function(FixtureReportsRepo repo)? configure,
  void Function(FakeReportServices services)? services,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final statics = StaticsRepository(db: db, service: NullStaticsService());
  await tester.runAsync(
    () => statics.applyStatic({
      'currencies': [_usd, _gbp, _eur],
    }),
  );
  final repo = FixtureReportsRepo(preview);
  configure?.call(repo);
  final vm = ReportsViewModel(
    repo: repo,
    statics: statics,
    companyId: 'company',
    fetchRowIds: true,
    autoRun: autoRun,
    companyCurrencyId: () async => '1',
    now: now,
    autoRunDebounce: Duration.zero,
  );
  addTearDown(vm.dispose);
  final formatter = reportTestFormatter();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ChangeNotifierProvider<ReportsViewModel>.value(
              value: vm,
              child: FormatterScope(formatter: formatter, child: child),
            ),
        routes: [
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsGalleryScreen(),
            routes: [
              GoRoute(
                path: ':report',
                builder: (context, state) => ReportScreen(
                  reportId: state.pathParameters['report']!,
                  starterIndex: int.tryParse(
                    state.uri.queryParameters[kReportStarterViewParam] ?? '',
                  ),
                  viewId: state.uri.queryParameters[kReportSavedViewParam],
                ),
              ),
            ],
          ),
          // Where a row link lands; the destination itself is not under test.
          GoRoute(
            path: '/:entity/:id',
            builder: (context, state) =>
                Scaffold(body: Text('record ${state.uri.path}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  final fakeServices = FakeReportServices();
  services?.call(fakeServices);
  await tester.pumpWidget(
    Provider<Services>.value(
      value: fakeServices,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildInTheme(
          brightness == Brightness.dark ? InTheme.dark : InTheme.light,
        ),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(textDirection: direction, child: child!),
        ),
      ),
    ),
  );
  await settleReports(tester);
  return ReportScreenHarness(vm, repo, router, db);
}

/// Let a run land. It is real async work — Drift, the fixture's futures —
/// which a fake-clock `pump` alone does not advance, and `pumpAndSettle`
/// never returns while a relative-time ticker is mounted.
Future<void> settleReports(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The fake [Services] the harness mounted.
FakeReportServices reportTestServicesOf(BuildContext context) =>
    Provider.of<Services>(context, listen: false) as FakeReportServices;
