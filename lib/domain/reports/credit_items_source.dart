import 'package:decimal/decimal.dart';

import 'package:admin/data/db/dao/id_remap_dao.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/client_settings_cascade.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/domain/billing/billing_doc_totals.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/record_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/utils/notes_html.dart';

/// The Credit Items report: one row per **line item** of each credit, the
/// credit's own figures on every line.
///
/// The server has an invoice-, quote- and recurring-invoice-item report and
/// no credit one; v1 built this from its local store. So it is built here
/// from the credits the device holds, after fetching the ones dated in the
/// range (`GET /credits?date_range=`).
///
/// Its columns are the invoice item report's, under `credit.` — the line
/// columns are `item.*`, so a credit's own amounts are counted once per
/// credit, not once per line (`ReportDefinition.lineItemPrefix`) — and v1's:
/// the net and gross line totals, the line's tax, its profit and markup.
RecordReportSource<Credit> creditItemsReportSource({
  required CreditRepository credits,
  required ClientRepository clients,
  required GroupSettingRepository groups,
  required IdRemapDao idRemap,
  required Map<String, Currency> Function() currencies,
  required Future<String> Function() companyCurrencyId,
}) => RecordReportSource<Credit>(
  name: 'Credit Items',
  fetchPage: (companyId, page, states, filters) => credits.ensurePageLoaded(
    companyId: companyId,
    page: page,
    states: states,
    extraFilters: filters,
    // A narrowed sweep of its own: the shared credit cursor is neither read
    // nor advanced (CLAUDE.md § Sync).
    ignoreCursor: true,
    // `filter_deleted_clients` narrows instead — see [creditItemsFetchFilters].
    excludeDeletedClients: false,
  ),
  fetchFilters: creditItemsFetchFilters,
  readRecords: (query, states) => credits
      .watchPage(
        companyId: query.companyId,
        loadedPages: kRecordReportAllPages,
        states: states,
        extraFilters: {
          if (!query.isAllTime)
            'date_range': {
              'date,${query.start!.toIso()},${query.end!.toIso()}',
            },
        },
      )
      .first,
  readLookups: (companyId, records) async {
    final ids = {
      for (final c in records)
        if (c.clientId.isNotEmpty) c.clientId,
    };
    final remap = await idRemap.resolveAllAnyType(ids);
    final rows = await clients.getByIds(
      companyId: companyId,
      ids: ids.map((id) => remap[id] ?? id),
    );
    // A credit is in its client's currency: the client's own, else its
    // group's, else the company's (`''` here).
    final byGroup =
        rows.any((c) => c.currencyId.isEmpty && c.groupSettingsId.isNotEmpty)
        ? await groupCurrencyIds(groups, companyId)
        : const <String, String>{};
    return ReportLookups(
      names: {
        'client': {for (final c in rows) c.id: c.displayName},
      },
      extra: {
        'client': {for (final c in rows) c.id: c},
        kClientCurrencyLookup: {
          for (final c in rows)
            c.id: c.currencyId.isNotEmpty
                ? c.currencyId
                : (byGroup[c.groupSettingsId] ?? ''),
        },
      },
      remap: remap,
      currencies: currencies(),
      companyCurrencyId: await companyCurrencyId(),
    );
  },
  build: (records, query, lookups) =>
      buildCreditItemsPreview(credits: records, query: query, lookups: lookups),
  namesToFetch: (records, query, lookups) => {
    'client': unnamedIds(lookups, 'client', [
      for (final c in records)
        if (_creditMatches(c, query, lookups)) c.clientId,
    ]),
  },
  // Uncapped: an unresolved client would put its credits in the company's
  // currency.
  uncappedNameKinds: const {'client'},
  hydrateNames: (companyId, ids) async {
    // One request per record (the list route takes no id filter), a few at
    // a time; `ensureLoaded` never throws and remembers a record the server
    // says is gone, so it is not asked for again on every run.
    for (final chunk in reportIdChunks(ids['client'] ?? const {}, 10)) {
      await Future.wait([
        for (final id in chunk)
          clients.ensureLoaded(companyId: companyId, id: id),
      ]);
    }
  },
);

/// [ReportLookups.extra] kind holding each client's effective currency id —
/// its own, else its group's, else `''` for the company's.
const String kClientCurrencyLookup = 'client_currency';

/// The list filters a refresh sends: the credits dated in the range, of
/// clients that are not deleted — what `CreditExport` reads.
///
/// `date_range` is the two-part `start,end`, which every server version
/// applies to `credits.date` (`QueryFilters::date_range`; the three-part
/// `date,start,end` is only read since 5.13.23). `filter_deleted_clients`
/// keeps an archived client's credits, which the list's own
/// `without_deleted_clients` would drop and the server's credit report keeps.
Map<String, Set<String>> creditItemsFetchFilters(ReportQuery query) => {
  'filter_deleted_clients': {'true'},
  if (!query.isAllTime)
    'date_range': {'${query.start!.toIso()},${query.end!.toIso()}'},
};

/// The report's columns, the default ones first.
const List<String> kCreditItemsColumnIds = [
  'client.name',
  'credit.number',
  'credit.date',
  'item.product_key',
  'item.notes',
  'item.quantity',
  'item.cost',
  'item.line_total',
  'item.discount',
  'item.tax_amount',
  'item.net_total',
  'item.gross_line_total',
  'item.product_cost',
  'item.profit',
  'item.markup',
  'item.tax_names',
  'item.tax_rates',
  'item.custom_value1',
  'item.custom_value2',
  'item.custom_value3',
  'item.custom_value4',
  'credit.status',
  'credit.due_date',
  'client.number',
  'client.id_number',
  'contact.email',
  'client.currency_id',
  'credit.record_state',
];

const Map<String, ReportColumnSpec> _kColumns = {
  'client.name': (
    labelKey: 'client',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'credit.number': (
    labelKey: 'credit_number',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'credit.date': (
    labelKey: 'credit_date',
    type: ReportColumnType.date,
    aggregation: null,
  ),
  'item.product_key': (
    labelKey: 'product_key',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.notes': (
    labelKey: 'description',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.quantity': (
    labelKey: 'quantity',
    type: ReportColumnType.number,
    aggregation: null,
  ),
  // The unit price, which v1 called the price and the server's item report
  // `cost`.
  'item.cost': (
    labelKey: 'price',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  // Quantity times price, less the line's discount — the server's
  // `line_total`, tax included where the credit's taxes are inclusive.
  'item.line_total': (
    labelKey: 'line_total',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  // A percentage or an amount, as the credit says: never totalled.
  'item.discount': (
    labelKey: 'discount',
    type: ReportColumnType.number,
    aggregation: ReportAggregation.none,
  ),
  'item.tax_amount': (
    labelKey: 'tax_amount',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  'item.net_total': (
    labelKey: 'net_total',
    type: ReportColumnType.money,
    aggregation: ReportAggregation.sum,
  ),
  'item.gross_line_total': (
    labelKey: 'gross_line_total',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  // In the company's currency, as the product's cost is.
  'item.product_cost': (
    labelKey: 'product_cost',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  'item.profit': (
    labelKey: 'profit',
    type: ReportColumnType.money,
    aggregation: ReportAggregation.sum,
  ),
  // A percentage of the cost.
  'item.markup': (
    labelKey: 'markup',
    type: ReportColumnType.number,
    aggregation: ReportAggregation.none,
  ),
  'item.tax_names': (
    labelKey: 'tax_names',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.tax_rates': (
    labelKey: 'tax_rates',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.custom_value1': (
    labelKey: 'custom_value1',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.custom_value2': (
    labelKey: 'custom_value2',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.custom_value3': (
    labelKey: 'custom_value3',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'item.custom_value4': (
    labelKey: 'custom_value4',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'credit.status': (
    labelKey: 'status',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'credit.due_date': (
    labelKey: 'due_date',
    type: ReportColumnType.date,
    aggregation: null,
  ),
  'client.number': (
    labelKey: 'client_number',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'client.id_number': (
    labelKey: 'client_id_number',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'contact.email': (
    labelKey: 'client_email',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  // The ISO code the view model reads each row's currency from.
  'client.currency_id': (
    labelKey: 'currency',
    type: ReportColumnType.string,
    aggregation: null,
  ),
  'credit.record_state': (
    labelKey: 'record_state',
    type: ReportColumnType.string,
    aggregation: null,
  ),
};

/// Whether [credit] is one of [query]'s, line filters aside.
bool _creditMatches(Credit credit, ReportQuery query, ReportLookups lookups) {
  if (credit.isDeleted && !query.includeDeleted) return false;
  // `CreditExport` keeps the credits of a client that is not deleted — an
  // archived one's included.
  final client = lookups.extra['client']?[lookups.idOf(credit.clientId)];
  if (client is Client && client.isDeleted) return false;
  if (!reportIdMatches(query.clientIds, credit.clientId, lookups)) {
    return false;
  }
  if (query.tagIds.isNotEmpty && !credit.tagIds.any(query.tagIds.contains)) {
    return false;
  }
  final statuses = reportCsv(query.status);
  if (statuses.isNotEmpty &&
      !statuses.contains('all') &&
      !statuses.contains(credit.statusId.labelKey)) {
    return false;
  }
  return reportDateInRange(credit.date, query);
}

/// The report's rows from [credits] — a row per line item of every credit
/// that passes [query]'s filters, oldest credit first.
ReportPreview buildCreditItemsPreview({
  required Iterable<Credit> credits,
  required ReportQuery query,
  ReportLookups lookups = const ReportLookups(),
}) {
  final kept = [
    for (final c in credits)
      if (_creditMatches(c, query, lookups)) c,
  ];
  kept.sort((a, b) {
    final ad = a.date;
    final bd = b.date;
    if (ad != null && bd != null) {
      final byDate = ad.compareTo(bd);
      if (byDate != 0) return byDate;
    } else if (ad != bd) {
      return ad == null ? 1 : -1;
    }
    final byNumber = a.number.compareTo(b.number);
    return byNumber != 0 ? byNumber : a.id.compareTo(b.id);
  });
  final flat = <String, String>{};
  final rows = <ReportRow>[];
  for (final credit in kept) {
    final clientId = lookups.idOf(credit.clientId);
    final client = lookups.extra['client']?[clientId];
    final currencyId = lookups.extra[kClientCurrencyLookup]?[clientId];
    final currency = lookups.currencyOr(currencyId is String ? currencyId : '');
    final precision = currency?.precision ?? 2;
    final input = credit.totalsInput;
    final subtotal = computeSubtotal(input, precision);
    for (final item in credit.lineItems) {
      if (query.productKeys.isNotEmpty &&
          !query.productKeys.contains(item.productKey)) {
        continue;
      }
      rows.add(
        _row(
          credit: credit,
          item: item,
          client: client is Client ? client : null,
          clientId: clientId,
          currency: currency,
          precision: precision,
          subtotal: subtotal,
          query: query,
          lookups: lookups,
          flat: flat,
        ),
      );
    }
  }
  return ReportPreview(
    columns: reportColumnsOf(kCreditItemsColumnIds, _kColumns, query),
    rows: rows,
  );
}

ReportRow _row({
  required Credit credit,
  required LineItem item,
  required Client? client,
  required String clientId,
  required Currency? currency,
  required int precision,
  required Decimal subtotal,
  required ReportQuery query,
  required ReportLookups lookups,
  required Map<String, String> flat,
}) {
  final input = credit.totalsInput;
  final lineTotal = computeLineTotal(
    item,
    isAmountDiscount: credit.isAmountDiscount,
    precision: precision,
  );
  final tax = computeLineTaxAmount(item, input, precision, subtotal: subtotal);
  final inclusive = credit.usesInclusiveTaxes;
  final net = inclusive ? lineTotal - tax : lineTotal;
  final gross = inclusive ? lineTotal : lineTotal + tax;
  // The product's cost is in the company's currency; the line in the
  // credit's. `exchange_rate` is the credit's currency per company unit (0
  // is the legacy "no conversion").
  final rate = credit.exchangeRate == Decimal.zero
      ? Decimal.one
      : credit.exchangeRate;
  final companyCurrency = lookups.companyCurrencyId.isEmpty
      ? null
      : lookups.companyCurrencyId;
  final cost = item.productCost * item.quantity;
  final profit = (net / rate).toDecimal(scaleOnInfinitePrecision: 10) - cost;
  final markup = cost == Decimal.zero
      ? null
      : ((profit * Decimal.fromInt(100)) / cost)
            .toDecimal(scaleOnInfinitePrecision: 10)
            .round(scale: 2);
  String flatten(String notes) =>
      flat.putIfAbsent(notes, () => plainTextFromHtml(notes, singleLine: true));
  String joined(Iterable<String> parts) =>
      parts.where((p) => p.isNotEmpty).join(', ');
  Contact? primary;
  if (client != null && client.contacts.isNotEmpty) {
    primary = client.contacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => client.contacts.first,
    );
  }
  final taxed = [
    (item.taxName1, item.taxRate1),
    (item.taxName2, item.taxRate2),
    (item.taxName3, item.taxRate3),
  ].where((t) => t.$2 != Decimal.zero || t.$1.isNotEmpty);
  final cells = <String, ReportCell>{
    'client.name': reportText(
      lookups.nameOf('client', credit.clientId),
      wire: 'client',
      id: clientId,
    ),
    'credit.number': reportText(credit.number),
    'credit.date': reportDate(credit.date),
    'item.product_key': reportText(item.productKey),
    'item.notes': reportText(flatten(item.notes)),
    'item.quantity': reportNumber(item.quantity),
    'item.cost': reportMoney(item.cost),
    'item.line_total': reportMoney(lineTotal),
    'item.discount': reportNumber(item.discount),
    'item.tax_amount': reportMoney(tax),
    'item.net_total': reportMoney(net),
    'item.gross_line_total': reportMoney(gross),
    'item.product_cost': ReportNumberCell(
      value: item.productCost,
      isMoney: true,
      currencyId: companyCurrency,
      displayValue: item.productCost.toString(),
    ),
    'item.profit': ReportNumberCell(
      value: profit,
      isMoney: true,
      currencyId: companyCurrency,
      displayValue: profit.toString(),
    ),
    'item.markup': ReportNumberCell(
      value: markup,
      displayValue: markup == null ? '' : '$markup%',
    ),
    'item.tax_names': reportText(joined(taxed.map((t) => t.$1))),
    'item.tax_rates': reportText(joined(taxed.map((t) => '${t.$2}%'))),
    'item.custom_value1': reportText(item.customValue1),
    'item.custom_value2': reportText(item.customValue2),
    'item.custom_value3': reportText(item.customValue3),
    'item.custom_value4': reportText(item.customValue4),
    'credit.status': reportText(query.label(credit.statusId.labelKey)),
    'credit.due_date': reportDate(credit.dueDate),
    'client.number': reportText(client?.number ?? ''),
    'client.id_number': reportText(client?.idNumber ?? ''),
    'contact.email': reportText(primary?.email ?? ''),
    'client.currency_id': reportText(currency?.code ?? ''),
    'credit.record_state': reportRecordState(
      isDeleted: credit.isDeleted,
      archivedAt: credit.archivedAt,
      query: query,
    ),
  };
  final real = !credit.id.startsWith('tmp_');
  return ReportRow(
    cells: [for (final id in kCreditItemsColumnIds) cells[id]!],
    recordWire: real ? 'credit' : null,
    recordId: real ? credit.id : null,
    currencyId: currency?.id,
  );
}
