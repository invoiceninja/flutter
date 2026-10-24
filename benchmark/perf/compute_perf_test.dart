// Pure computation — no database, no widgets: the work behind an invoice's
// totals, a report, a notes field, and the payload a cold start parses.
//
// docs/performance-tracking.md. Run through `dart tools/perf/main.dart run`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/task_items_source.dart';
import 'package:admin/utils/legacy_html_markdown.dart';
import 'package:admin/utils/notes_html.dart';

import '../workloads.dart';
import '_perf.dart';

void main() {
  perfCalibration();

  final totals = totalsInputs();
  var next = 0;
  benchmark(
    'billing.invoice_totals',
    title: 'Invoice totals — one 50-line invoice with taxes and discounts',
    // The five inputs differ (inclusive / exclusive tax, amount / percent
    // discount), so a sample takes one of each.
    batch: totals.length,
    run: () => computeTotals(totals[next++ % totals.length], 2).total,
  );

  final preview = reportPreview();
  benchmark(
    'reports.group_and_sort',
    title: 'Report engine — 5,000 rows grouped by client, sorted by amount',
    batch: 2,
    run: () => const ReportEngine()
        .compute(
          preview: preview,
          ui: const ReportUiState(
            group: 'client.name',
            sortField: 'invoice.amount',
            sortAscending: false,
          ),
          exchangeRates: const {},
          companyCurrencyId: '1',
        )
        .totalRowCount,
  );

  // Task Items is built on the device from every task the company holds:
  // each entry of each task tested against the range, the survivors sorted.
  final tasks = taskItemsTasks();
  final thisMonth = ReportQuery(
    companyId: 'co',
    now: taskItemsNow,
    label: (key) => key,
    start: Date(2026, 10, 1),
    end: Date(2026, 10, 31),
  );
  benchmark(
    'reports.task_items_build',
    title: 'Task Items — "this month" from 600 tasks of 15 time entries',
    setUp: () => expect(
      buildTaskItemsPreview(tasks: tasks, query: thisMonth).rows,
      isNotEmpty,
    ),
    run: () =>
        buildTaskItemsPreview(tasks: tasks, query: thisMonth).rows.length,
  );

  final html = legacyHtml();
  benchmark(
    'rich_text.legacy_html_to_markdown',
    title: 'Notes field — 40 KB of legacy HTML folded to markdown',
    batch: 5,
    run: () => markdownFromLegacyHtml(html).length,
  );
  benchmark(
    'rich_text.notes_plain_text',
    title: 'Notes field — 40 KB of HTML rendered as plain text',
    batch: 5,
    run: () => plainTextFromHtml(html).length,
  );

  // A cold start's `/refresh?first_load=true`: two companies, every
  // browsable array populated. `fromFullSnapshot` drops those arrays before
  // typing anything, so nearly all of this is `jsonDecode` — SDK work the
  // calibration scales away. What it guards is the app's half: if the full
  // snapshot ever types its 4,200 browsable rows again (the cost
  // docs/startup-responsiveness.md removed), this jumps.
  final snapshotText = jsonEncode(_snapshot(rowsPerKey: 150));
  benchmark(
    'startup.snapshot_load',
    title:
        'Cold start — decode the full /refresh snapshot '
        '(${(snapshotText.length / 1024 / 1024).toStringAsFixed(1)} MB) and type '
        'what it keeps',
    setUp: () {
      final parsed = LoginResponseApi.fromFullSnapshot(
        jsonDecode(snapshotText) as Map<String, dynamic>,
      );
      expect(parsed.data, hasLength(2));
      expect(parsed.data.first.company.taskStatuses, hasLength(4));
    },
    samples: 9,
    run: () => LoginResponseApi.fromFullSnapshot(
      jsonDecode(snapshotText) as Map<String, dynamic>,
    ).data.length,
  );

  // A delta `/refresh` after the app was closed for a day: every browsable
  // array carries changed rows, and all of them are typed.
  late Map<String, dynamic> delta;
  benchmark(
    'sync.refresh_delta_parse',
    title: 'Delta /refresh — typing 50 changed rows of each of 14 entities',
    setUp: () {
      delta =
          jsonDecode(jsonEncode(_snapshot(rowsPerKey: 50, companies: 1)))
              as Map<String, dynamic>;
      final company = LoginResponseApi.fromJson(delta).data.single.company;
      expect(company.invoices, hasLength(50));
      expect(company.invoices.first.lineItems, hasLength(8));
      expect(company.clients.first.contacts, hasLength(2));
      expect(company.bankTransactions, hasLength(50));
    },
    batch: 2,
    run: () => LoginResponseApi.fromJson(delta).data.length,
  );

  // A receipt read waits on this after the engine: the slowest real-world
  // shape — a German supermarket bon, rows rebuilt from Vision's fragments.
  late List<OcrFragment> receipt;
  const receiptContext = ReceiptParseContext(
    today: Date(2026, 10, 25),
    dateOrder: DateOrder.dmy,
  );
  benchmark(
    'expenses.receipt_parse',
    title: 'Receipt OCR — rows rebuilt and parsed from one engine read',
    setUp: () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/receipts/vision/de_supermarket.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      receipt = [
        for (final f in fixture['fragments'] as List) ?OcrFragment.fromMap(f),
      ];
      expect(
        parseReceiptText(receipt, receiptContext).total?.value.toString(),
        '23.47',
      );
    },
    batch: 20,
    run: () => parseReceiptText(receipt, receiptContext).taxes.length,
  );

  late Map<String, dynamic> page;
  benchmark(
    'sync.invoice_page_parse',
    title: 'List page — typing one page of 50 invoices (8 lines each)',
    setUp: () {
      page =
          jsonDecode(
                jsonEncode({
                  'data': [for (var i = 0; i < 50; i++) invoiceJson(i)],
                }),
              )
              as Map<String, dynamic>;
      final parsed = InvoiceListApi.fromJson(page).data;
      expect(parsed, hasLength(50));
      expect(parsed.last.lineItems, hasLength(8));
    },
    batch: 10,
    run: () => InvoiceListApi.fromJson(page).data.length,
  );
}

/// The `/login` / `/refresh` envelope: [companies] companies, each carrying
/// [rowsPerKey] rows of every browsable entity. Invoices and clients are
/// realistic; the other twelve are every field their DTO has, at its default
/// (a row parsed from a stub and re-encoded), which is what the per-field
/// parse cost depends on.
Map<String, dynamic> _snapshot({required int rowsPerKey, int companies = 2}) {
  final stubs = _fullRows();
  return {
    'data': [
      for (var c = 0; c < companies; c++)
        {
          'company': {
            'id': 'co_$c',
            'name': 'Company $c',
            'settings': {'currency_id': '1', 'name': 'Company $c'},
            'task_statuses': [
              for (final name in ['Backlog', 'Ready', 'In progress', 'Done'])
                {'id': 'ts_${c}_$name', 'name': name},
            ],
            'tax_rates': [
              {'id': 'tr_$c', 'name': 'VAT', 'rate': 20},
            ],
            for (final key in kBrowsableDeltaJsonKeys)
              key: [
                for (var i = 0; i < rowsPerKey; i++)
                  switch (key) {
                    'invoices' => invoiceJson(i),
                    'clients' => clientJson(i),
                    _ => {...stubs[key]!, 'id': '${key}_${c}_$i'},
                  },
              ],
          },
          'token': {'token': 'tok_$c', 'name': 'web'},
          'account': {'id': 'acc_1', 'plan': 'pro'},
          'user': {
            'id': 'u_1',
            'first_name': 'Pat',
            'last_name': 'Admin',
            'email': 'pat@example.com',
          },
        },
    ],
    'static': {
      'currencies': [
        for (var i = 1; i <= 160; i++)
          {
            'id': '$i',
            'name': 'Currency $i',
            'code': 'C$i',
            'symbol': r'$',
            'precision': 2,
            'thousand_separator': ',',
            'decimal_separator': '.',
            'exchange_rate': 1,
          },
      ],
    },
  };
}

/// Every browsable DTO with all of its fields: a one-field stub parsed and
/// re-encoded (the trick `login_response_full_snapshot_test` uses).
Map<String, Map<String, dynamic>> _fullRows() {
  final parsed = LoginResponseApi.fromJson({
    'data': [
      {
        'company': {
          'id': 'stub',
          for (final key in kBrowsableDeltaJsonKeys)
            key: [
              {'id': 'row', 'updated_at': 1},
            ],
        },
        'token': {'token': 't', 'name': 't'},
        'account': {'id': 'a'},
      },
    ],
  });
  final encoded = jsonDecode(jsonEncode(parsed.toJson())) as Map;
  final company = ((encoded['data'] as List).single as Map)['company'] as Map;
  return {
    for (final key in kBrowsableDeltaJsonKeys)
      key: Map<String, dynamic>.from((company[key] as List).single as Map),
  };
}
