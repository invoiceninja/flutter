import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

/// Answers every preview with the columns it was asked for — the server
/// echoes `report_keys` — or [defaults] for a plain run.
class _EchoRepo implements ReportsRepository {
  _EchoRepo(this.defaults, {this.unknown = const {}});

  final List<String> defaults;

  /// Keys this server doesn't have: asked for, never returned.
  final Set<String> unknown;
  final List<List<String>> previewReportKeys = [];

  /// The last answer, stored like the real cache: by payload alone.
  ({ReportPreview preview, DateTime fetchedAt})? remembered;

  @override
  Future<({ReportPreview preview, DateTime fetchedAt})?> cachedPreview({
    required String companyId,
    required String reportIdentifier,
    required ReportPayload payload,
    List<String> addedColumns = const [],
    FormattedNumberStyle? numberStyle,
  }) async => remembered;

  @override
  Future<ReportPreview> runPreview({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    List<String> addedColumns = const [],
    FormattedNumberStyle? numberStyle,
    String? companyId,
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    previewReportKeys.add(reportKeys);
    final ids = [
      for (final id in reportKeys.isEmpty ? defaults : reportKeys)
        if (!unknown.contains(id)) id,
    ];
    final preview = ReportPreview(
      columns: [
        for (final id in ids)
          ReportColumn(
            identifier: id,
            displayLabel: id,
            type: inferColumnType(id),
          ),
      ],
      rows: [
        ReportRow(
          cells: [
            for (final id in ids)
              inferColumnType(id) == ReportColumnType.money
                  ? ReportNumberCell(value: Decimal.fromInt(5), isMoney: true)
                  : ReportStringCell(value: id, displayValue: id),
          ],
        ),
      ],
    );
    remembered = (preview: preview, fetchedAt: DateTime.now());
    return preview;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullStaticsService implements StaticsService {
  @override
  Future<Map<String, dynamic>> fetch({
    bool includeStatic = true,
    bool? includeData,
  }) async => const <String, dynamic>{};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _paymentDefaults = [
  'client.name',
  'payment.number',
  'payment.date',
  'payment.amount',
  'payment.currency',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StaticsRepository statics;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    statics = StaticsRepository(db: db, service: _NullStaticsService());
  });

  tearDown(() async {
    await db.close();
  });

  ReportsViewModel paymentVm(
    _EchoRepo repo, {
    Map<String, String> customFields = const {},
  }) {
    final vm = ReportsViewModel(
      repo: repo,
      statics: statics,
      initialReport: 'payment',
      companyCurrencyId: () async => null,
      customFieldLabels: () async => customFields,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  test('offers the client and contact fields the result lacks', () async {
    final vm = paymentVm(_EchoRepo(_paymentDefaults));
    expect(vm.relatedColumnGroups, isEmpty, reason: 'nothing to append to');
    await vm.runReport();

    final groups = vm.relatedColumnGroups;
    expect([for (final g in groups) g.labelKey], ['client', 'contact']);
    final client = [for (final o in groups.first.columns) o.id];
    expect(client, contains('client.city'));
    expect(client, contains('client.balance'));
    // Already in the result.
    expect(client, isNot(contains('client.name')));
    // No custom field is configured, so none is offered.
    expect(client.where((id) => id.contains('custom_value')), isEmpty);
  });

  test('a configured custom field is offered under its own label', () async {
    final vm = paymentVm(
      _EchoRepo(_paymentDefaults),
      customFields: {'client2': 'Region', 'contact1': ''},
    );
    await vm.runReport();
    final offers = [
      for (final g in vm.relatedColumnGroups)
        for (final o in g.columns)
          if (o.id.contains('custom_value')) o,
    ];
    expect([for (final o in offers) o.id], ['client.custom_value2']);
    expect(offers.single.label, 'Region');
  });

  test('an added column is fetched with the known set, and shows', () async {
    final repo = _EchoRepo(_paymentDefaults);
    final vm = paymentVm(repo);
    await vm.runReport();
    expect(repo.previewReportKeys.single, isEmpty);
    final visibleBefore = vm.visibleColumnIds;

    vm.addColumns(['client.city', 'contact.email', 'payment.not_offered']);
    expect(vm.isParamDirty, isTrue, reason: 'the fetch changed');
    await vm.runReport();

    expect(repo.previewReportKeys.last, [
      ..._paymentDefaults,
      'client.city',
      'contact.email',
    ]);
    expect(vm.isParamDirty, isFalse);
    expect(vm.visibleColumnIds, {
      ...visibleBefore,
      'client.city',
      'contact.email',
    });
    expect(vm.columnOrder.sublist(vm.columnOrder.length - 2), [
      'client.city',
      'contact.email',
    ]);
    // Offered no longer: the result carries it.
    final offered = {
      for (final g in vm.relatedColumnGroups)
        for (final o in g.columns) o.id,
    };
    expect(offered, isNot(contains('client.city')));
  });

  // After the first run with an added column the result *contains* it, so
  // a "skip if already present" guard would drop it on the next run.
  test('a second run still asks for it exactly once', () async {
    final repo = _EchoRepo(_paymentDefaults);
    final vm = paymentVm(repo);
    await vm.runReport();
    vm.addColumns(['client.city']);
    await vm.runReport();
    await vm.runReport();
    expect(repo.previewReportKeys.last, [..._paymentDefaults, 'client.city']);
  });

  test('hiding an added column keeps it fetched, unseen', () async {
    final repo = _EchoRepo(_paymentDefaults);
    final vm = paymentVm(repo);
    await vm.runReport();
    vm.addColumns(['client.city']);
    await vm.runReport();
    vm.setVisibleColumns(
      vm.visibleColumnIds.difference({'client.city'}),
      order: vm.columnOrder,
    );
    await vm.runReport();
    expect(repo.previewReportKeys.last, contains('client.city'));
    expect(vm.visibleColumnIds, isNot(contains('client.city')));
  });

  test('a client figure is not added up across payments', () async {
    final vm = paymentVm(_EchoRepo(_paymentDefaults));
    await vm.runReport();
    vm.addColumns(['client.balance']);
    await vm.runReport();
    final column = vm.run.preview!.columns.firstWhere(
      (c) => c.identifier == 'client.balance',
    );
    expect(column.effectiveAggregation, ReportAggregation.none);
  });

  test(
    'the added columns are part of the view, and a reset forgets them',
    () async {
      final repo = _EchoRepo(_paymentDefaults);
      final vm = paymentVm(repo);
      await vm.runReport();
      vm.addColumns(['client.city']);
      await vm.runReport();
      expect(vm.reportViewState()['addedColumns'], ['client.city']);

      vm.resetEverything();
      expect(vm.addedColumnIds, isEmpty);
      await vm.runReport();
      expect(repo.previewReportKeys.last, isEmpty);
    },
  );

  test('a saved view brings its added columns back', () async {
    final repo = _EchoRepo(_paymentDefaults);
    final vm = paymentVm(repo);
    await vm.runReport();
    vm.addColumns(['client.city']);
    await vm.runReport();
    final saved = vm.reportViewState();

    final repo2 = _EchoRepo(_paymentDefaults);
    final vm2 = paymentVm(repo2);
    vm2.applyReportView('v1', saved);
    await vm2.runReport();
    expect(vm2.addedColumnIds, ['client.city']);
    expect(repo2.previewReportKeys.last, contains('client.city'));
  });

  // The cache is keyed on the payload alone, so after a reset the result the
  // augmented run stored answers the plain request — fresh, so nothing ran,
  // and the dropped column came back as though the server returned it by
  // default, to be asked for by every later run.
  test(
    'a reset is not answered by the result that carried the column',
    () async {
      final repo = _EchoRepo(_paymentDefaults);
      final vm = ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: 'payment',
        companyId: 'co1',
        autoRun: true,
        autoRunDebounce: const Duration(milliseconds: 5),
      );
      addTearDown(vm.dispose);
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 40));

      await vm.open('payment');
      vm.addColumns(['client.city']);
      await settle();
      expect(repo.previewReportKeys.last, contains('client.city'));

      vm.resetEverything();
      await settle();
      expect(repo.previewReportKeys.last, isEmpty);
      expect(
        vm.run.preview!.columns.map((c) => c.identifier),
        isNot(contains('client.city')),
      );
      final offered = {
        for (final g in vm.relatedColumnGroups)
          for (final o in g.columns) o.id,
      };
      expect(offered, contains('client.city'));
    },
  );

  test('a custom field is headed by the label the company gave it', () async {
    final repo = _EchoRepo(['purchase_order.number', 'vendor.name']);
    final vm = ReportsViewModel(
      repo: repo,
      statics: statics,
      initialReport: 'purchase_order',
      companyCurrencyId: () async => null,
      customFieldLabels: () async => {'vendor1': 'Region'},
    );
    addTearDown(vm.dispose);
    await vm.runReport();
    vm.addColumns(['vendor.custom_value1']);
    await vm.runReport();
    final column = vm.run.preview!.columns.firstWhere(
      (c) => c.identifier == 'vendor.custom_value1',
    );
    expect(column.displayLabel, 'Region');
  });

  // Owed for good, the request never matched a result: the report read as
  // needing a Run on every open, skipped every remembered result, and
  // ticking the column again did nothing.
  test('a column the server does not return is forgotten, not owed', () async {
    final repo = _EchoRepo(_paymentDefaults, unknown: {'client.city'});
    final vm = paymentVm(repo);
    await vm.runReport();
    vm.addColumns(['client.city']);
    await vm.runReport();
    expect(repo.previewReportKeys.last, contains('client.city'));

    expect(vm.addedColumnIds, isEmpty);
    expect(vm.isParamDirty, isFalse);
    expect(vm.reportViewState().containsKey('addedColumns'), isFalse);
  });

  test('one a cold run could not ask for yet is still owed', () async {
    final repo = _EchoRepo(_paymentDefaults);
    final vm = paymentVm(repo);
    // No result yet, so no known set to append it to.
    vm.addColumns(['client.city']);
    await vm.runReport();
    expect(repo.previewReportKeys.last, isEmpty);
    expect(vm.addedColumnIds, ['client.city']);
    expect(vm.isParamDirty, isTrue);

    await vm.runReport();
    expect(repo.previewReportKeys.last, contains('client.city'));
    expect(vm.isParamDirty, isFalse);
  });
}
