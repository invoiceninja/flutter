import 'package:decimal/decimal.dart';

import 'package:admin/data/db/dao/id_remap_dao.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/recurring_expense_status.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/record_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/utils/notes_html.dart';

/// The Recurring Expenses report: one row per recurring expense.
///
/// The server has a recurring-invoice report and no recurring-expense one;
/// v1 built this from its local store. So it is built here, from the
/// recurring expenses the device holds after fetching the ones whose next
/// run falls in the range.
///
/// The range is the **next send date** — what v1 called the start date, and
/// the one date a schedule is about. It opens on all of them.
RecordReportSource<RecurringExpense> recurringExpensesReportSource({
  required RecurringExpenseRepository recurringExpenses,
  required ClientRepository clients,
  required VendorRepository vendors,
  required ExpenseCategoryRepository categories,
  required UserRepository users,
  required IdRemapDao idRemap,
  required Map<String, Currency> Function() currencies,
  required Map<String, PaymentType> Function() paymentTypes,
  required Future<String> Function() companyCurrencyId,
}) => RecordReportSource<RecurringExpense>(
  name: 'Recurring Expenses',
  fetchPage: (companyId, page, states, filters) =>
      recurringExpenses.ensurePageLoaded(
        companyId: companyId,
        page: page,
        states: states,
        extraFilters: filters,
        // A narrowed sweep of its own (CLAUDE.md § Sync).
        ignoreCursor: true,
      ),
  fetchFilters: recurringExpensesFetchFilters,
  readRecords: (query, states) => recurringExpenses
      .watchPage(
        companyId: query.companyId,
        loadedPages: kRecordReportAllPages,
        states: states,
      )
      .first,
  readLookups: (companyId, records) async {
    final clientIds = {
      for (final e in records)
        if (e.clientId.isNotEmpty) e.clientId,
    };
    final vendorIds = {
      for (final e in records)
        if (e.vendorId.isNotEmpty) e.vendorId,
    };
    final remap = await idRemap.resolveAllAnyType({...clientIds, ...vendorIds});
    String real(String id) => remap[id] ?? id;
    final clientRows = await clients.getByIds(
      companyId: companyId,
      ids: clientIds.map(real),
    );
    final vendorNames = await reportNamesById(
      vendorIds.map(real),
      (id) => vendors.watch(companyId: companyId, id: id).first,
      (v) => v.name,
    );
    final categoryRows = await categories
        .watchPage(
          companyId: companyId,
          loadedPages: kRecordReportAllPages,
          states: EntityState.values.toSet(),
        )
        .first;
    final userRows = await users.watchAllForPicker(companyId: companyId).first;
    return ReportLookups(
      names: {
        'client': {for (final c in clientRows) c.id: c.displayName},
        'vendor': vendorNames,
        'category': {for (final c in categoryRows) c.id: c.name},
        'user': {for (final u in userRows) u.id: u.displayName},
        'payment_type': {for (final t in paymentTypes().values) t.id: t.name},
      },
      extra: {
        'client': {for (final c in clientRows) c.id: c},
      },
      remap: remap,
      currencies: currencies(),
      companyCurrencyId: await companyCurrencyId(),
    );
  },
  build: (records, query, lookups) => buildRecurringExpensesPreview(
    recurringExpenses: records,
    query: query,
    lookups: lookups,
  ),
  namesToFetch: (records, query, lookups) {
    final kept = [
      for (final e in records)
        if (_matches(e, query, lookups)) e,
    ];
    return {
      'client': unnamedIds(lookups, 'client', kept.map((e) => e.clientId)),
      'vendor': unnamedIds(lookups, 'vendor', kept.map((e) => e.vendorId)),
    };
  },
  hydrateNames: (companyId, ids) async {
    await reportEnsureLoaded(
      ids['client'],
      (id) => clients.ensureLoaded(companyId: companyId, id: id),
    );
    await reportEnsureLoaded(
      ids['vendor'],
      (id) => vendors.ensureLoaded(companyId: companyId, id: id),
    );
  },
);

/// The list filters a refresh sends: the recurring expenses whose next run
/// is in the range.
///
/// The three-part `date_range` names the column (`QueryFilters::date_range`,
/// 5.13.23): `next_send_date_client`, the company-day date the API returns
/// as `next_send_date`. A server before that ignores the value and answers
/// every recurring expense — a superset, cut on the device.
Map<String, Set<String>> recurringExpensesFetchFilters(ReportQuery query) => {
  if (!query.isAllTime)
    'date_range': {
      'next_send_date_client,${query.start!.toIso()},${query.end!.toIso()}',
    },
};

/// The report's columns, the default ones first.
const List<String> kRecurringExpensesColumnIds = [
  'recurring_expense.number',
  'vendor.name',
  'recurring_expense.category_id',
  'recurring_expense.frequency_id',
  'recurring_expense.next_send_date',
  'recurring_expense.remaining_cycles',
  'recurring_expense.status',
  'recurring_expense.amount',
  'recurring_expense.net_amount',
  'recurring_expense.tax_amount',
  'client.name',
  'recurring_expense.transaction_reference',
  'recurring_expense.date',
  'recurring_expense.payment_date',
  'recurring_expense.payment_type_id',
  'recurring_expense.tax_rate1',
  'recurring_expense.tax_rate2',
  'recurring_expense.tax_rate3',
  'recurring_expense.public_notes',
  'recurring_expense.private_notes',
  'recurring_expense.assigned_user_id',
  'recurring_expense.user_id',
  'recurring_expense.custom_value1',
  'recurring_expense.custom_value2',
  'recurring_expense.custom_value3',
  'recurring_expense.custom_value4',
  'client.address1',
  'client.address2',
  'client.shipping_address1',
  'client.shipping_address2',
  'recurring_expense.currency_id',
  'recurring_expense.record_state',
];

ReportColumnSpec _text(String labelKey) =>
    (labelKey: labelKey, type: ReportColumnType.string, aggregation: null);

final Map<String, ReportColumnSpec> _kColumns = {
  'recurring_expense.number': _text('number'),
  'vendor.name': _text('vendor'),
  'recurring_expense.category_id': _text('category'),
  'recurring_expense.frequency_id': _text('frequency'),
  'recurring_expense.next_send_date': (
    labelKey: 'next_send_date',
    type: ReportColumnType.date,
    aggregation: null,
  ),
  // A count left, never a figure to add up; "Endless" when there is no end.
  'recurring_expense.remaining_cycles': (
    labelKey: 'remaining_cycles',
    type: ReportColumnType.number,
    aggregation: ReportAggregation.none,
  ),
  'recurring_expense.status': _text('status'),
  // Tax included, as v1's: what each run costs.
  'recurring_expense.amount': (
    labelKey: 'amount',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  'recurring_expense.net_amount': (
    labelKey: 'net_amount',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  'recurring_expense.tax_amount': (
    labelKey: 'tax_amount',
    type: ReportColumnType.money,
    aggregation: null,
  ),
  'client.name': _text('client'),
  'recurring_expense.transaction_reference': _text('transaction_reference'),
  'recurring_expense.date': (
    labelKey: 'date',
    type: ReportColumnType.date,
    aggregation: null,
  ),
  'recurring_expense.payment_date': (
    labelKey: 'payment_date',
    type: ReportColumnType.date,
    aggregation: null,
  ),
  'recurring_expense.payment_type_id': _text('payment_type'),
  for (final n in const [1, 2, 3])
    'recurring_expense.tax_rate$n': (
      labelKey: 'tax_rate$n',
      type: ReportColumnType.number,
      aggregation: ReportAggregation.none,
    ),
  'recurring_expense.public_notes': _text('public_notes'),
  'recurring_expense.private_notes': _text('private_notes'),
  'recurring_expense.assigned_user_id': _text('assigned_user'),
  'recurring_expense.user_id': _text('created_by_user'),
  for (final n in const [1, 2, 3, 4])
    'recurring_expense.custom_value$n': _text('custom_value$n'),
  'client.address1': _text('client_address1'),
  'client.address2': _text('client_address2'),
  'client.shipping_address1': _text('client_shipping_address1'),
  'client.shipping_address2': _text('client_shipping_address2'),
  // The ISO code the view model reads each row's currency from.
  'recurring_expense.currency_id': _text('currency'),
  'recurring_expense.record_state': _text('record_state'),
};

/// The Status filter's values: the label key of the status v1 and the list
/// show (`calculatedStatusId` — "Pending" is active and never sent).
String recurringExpenseStatusKey(RecurringExpense e) =>
    kRecurringExpenseStatusLabelKey[e.calculatedStatusId] ?? 'draft';

bool _matches(RecurringExpense e, ReportQuery query, ReportLookups lookups) {
  if (e.isDeleted && !query.includeDeleted) return false;
  if (!reportIdMatches(query.clientIds, e.clientId, lookups) ||
      !reportIdMatches(query.vendorIds, e.vendorId, lookups) ||
      !reportIdMatches(query.categoryIds, e.categoryId, lookups)) {
    return false;
  }
  if (query.tagIds.isNotEmpty && !e.tagIds.any(query.tagIds.contains)) {
    return false;
  }
  final statuses = reportCsv(query.status);
  if (statuses.isNotEmpty &&
      !statuses.contains('all') &&
      !statuses.contains(recurringExpenseStatusKey(e))) {
    return false;
  }
  return reportDateInRange(e.nextSendDate, query);
}

/// The report's rows from [recurringExpenses] — every one that passes
/// [query]'s filters, soonest next run first.
ReportPreview buildRecurringExpensesPreview({
  required Iterable<RecurringExpense> recurringExpenses,
  required ReportQuery query,
  ReportLookups lookups = const ReportLookups(),
}) {
  final kept = [
    for (final e in recurringExpenses)
      if (_matches(e, query, lookups)) e,
  ];
  kept.sort((a, b) {
    final ad = a.nextSendDate;
    final bd = b.nextSendDate;
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
  String flatten(String notes) =>
      flat.putIfAbsent(notes, () => plainTextFromHtml(notes, singleLine: true));
  return ReportPreview(
    columns: reportColumnsOf(kRecurringExpensesColumnIds, _kColumns, query),
    rows: [for (final e in kept) _row(e, query, lookups, flatten)],
  );
}

ReportRow _row(
  RecurringExpense e,
  ReportQuery query,
  ReportLookups lookups,
  String Function(String) flatten,
) {
  final clientId = lookups.idOf(e.clientId);
  final vendorId = lookups.idOf(e.vendorId);
  final client = lookups.extra['client']?[clientId];
  final c = client is Client ? client : null;
  final currency = lookups.currencyOr(e.currencyId);
  final frequencyKey = kRecurringFrequencyLabelKey[e.frequencyId];
  final cells = <String, ReportCell>{
    'recurring_expense.number': reportText(e.number),
    'vendor.name': reportText(
      lookups.nameOf('vendor', e.vendorId),
      wire: 'vendor',
      id: vendorId,
    ),
    'recurring_expense.category_id': reportText(
      lookups.nameOf('category', e.categoryId),
    ),
    'recurring_expense.frequency_id': reportText(
      frequencyKey == null ? '' : query.label(frequencyKey),
    ),
    'recurring_expense.next_send_date': reportDate(e.nextSendDate),
    'recurring_expense.remaining_cycles': e.remainingCycles < 0
        ? ReportNumberCell(displayValue: query.label('endless'))
        : reportNumber(Decimal.fromInt(e.remainingCycles)),
    'recurring_expense.status': reportText(
      query.label(recurringExpenseStatusKey(e)),
    ),
    'recurring_expense.amount': reportMoney(e.grossAmount),
    'recurring_expense.net_amount': reportMoney(e.netAmount),
    'recurring_expense.tax_amount': reportMoney(e.taxAmountSum),
    'client.name': reportText(
      lookups.nameOf('client', e.clientId),
      wire: 'client',
      id: clientId,
    ),
    'recurring_expense.transaction_reference': reportText(
      e.transactionReference,
    ),
    'recurring_expense.date': reportDate(e.date),
    'recurring_expense.payment_date': reportDate(e.paymentDate),
    'recurring_expense.payment_type_id': reportText(
      lookups.nameOf('payment_type', e.paymentTypeId),
    ),
    'recurring_expense.tax_rate1': reportNumber(e.taxRate1),
    'recurring_expense.tax_rate2': reportNumber(e.taxRate2),
    'recurring_expense.tax_rate3': reportNumber(e.taxRate3),
    'recurring_expense.public_notes': reportText(flatten(e.publicNotes)),
    'recurring_expense.private_notes': reportText(flatten(e.privateNotes)),
    'recurring_expense.assigned_user_id': reportText(
      lookups.nameOf('user', e.assignedUserId),
    ),
    'recurring_expense.user_id': reportText(lookups.nameOf('user', e.userId)),
    'recurring_expense.custom_value1': reportText(e.customValue1),
    'recurring_expense.custom_value2': reportText(e.customValue2),
    'recurring_expense.custom_value3': reportText(e.customValue3),
    'recurring_expense.custom_value4': reportText(e.customValue4),
    'client.address1': reportText(c?.address1 ?? ''),
    'client.address2': reportText(c?.address2 ?? ''),
    'client.shipping_address1': reportText(c?.shippingAddress1 ?? ''),
    'client.shipping_address2': reportText(c?.shippingAddress2 ?? ''),
    'recurring_expense.currency_id': reportText(currency?.code ?? ''),
    'recurring_expense.record_state': reportRecordState(
      isDeleted: e.isDeleted,
      archivedAt: e.archivedAt,
      query: query,
    ),
  };
  final real = !e.id.startsWith('tmp_');
  return ReportRow(
    cells: [for (final id in kRecurringExpensesColumnIds) cells[id]!],
    recordWire: real ? 'recurring_expense' : null,
    recordId: real ? e.id : null,
    currencyId: currency?.id,
  );
}
