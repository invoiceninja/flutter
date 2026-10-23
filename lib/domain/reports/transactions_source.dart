import 'package:admin/data/db/dao/id_remap_dao.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/repositories/bank_account_repository.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/record_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/utils/notes_html.dart';

/// The Transactions report: one row per bank transaction.
///
/// The server has no report of bank transactions; v1 built this from its
/// local store. So it is built here, from the transactions the device holds
/// after fetching the ones dated in the range (`GET /bank_transactions
/// ?date_range=`).
///
/// It reads the transactions the Transactions list does: the list route's
/// `active_banks` default stays on, so a transaction of a deleted bank
/// account is in neither.
RecordReportSource<BankTransaction> transactionsReportSource({
  required BankTransactionRepository transactions,
  required BankAccountRepository bankAccounts,
  required VendorRepository vendors,
  required ExpenseCategoryRepository categories,
  required InvoiceRepository invoices,
  required ExpenseRepository expenses,
  required PaymentRepository payments,
  required IdRemapDao idRemap,
  required Map<String, Currency> Function() currencies,
  required Future<String> Function() companyCurrencyId,
}) => RecordReportSource<BankTransaction>(
  name: 'Transactions',
  fetchPage: (companyId, page, states, filters) =>
      transactions.ensurePageLoaded(
        companyId: companyId,
        page: page,
        states: states,
        extraFilters: filters,
        // A narrowed sweep of its own (CLAUDE.md § Sync).
        ignoreCursor: true,
      ),
  fetchFilters: transactionsFetchFilters,
  readRecords: (query, states) => transactions
      .watchPage(
        companyId: query.companyId,
        loadedPages: kRecordReportAllPages,
        states: states,
        dateStart: query.start?.toIso(),
        dateEnd: query.end?.toIso(),
      )
      .first,
  readLookups: (companyId, records) async {
    final ids = _linkedIds(records);
    final remap = await idRemap.resolveAllAnyType({
      for (final set in ids.values) ...set,
    });
    Iterable<String> real(String kind) =>
        (ids[kind] ?? const <String>{}).map((id) => remap[id] ?? id);
    // Read once: the name and the type both come from the account.
    final accounts = await reportRecordsById(
      real('bank_account'),
      (id) => bankAccounts.watch(companyId: companyId, id: id).first,
    );
    final names = <String, Map<String, String>>{
      'vendor': await reportNamesById(
        real('vendor'),
        (id) => vendors.watch(companyId: companyId, id: id).first,
        (v) => v.name,
      ),
      'invoice': await reportNamesById(
        real('invoice'),
        (id) => invoices.watch(companyId: companyId, id: id).first,
        (r) => r.number,
      ),
      'expense': await reportNamesById(
        real('expense'),
        (id) => expenses.watch(companyId: companyId, id: id).first,
        (r) => r.number,
      ),
      'payment': await reportNamesById(
        real('payment'),
        (id) => payments.watch(companyId: companyId, id: id).first,
        (r) => r.number,
      ),
      'bank_account': {
        for (final MapEntry(:key, :value) in accounts.entries) key: value.name,
      },
      'bank_account_type': {
        for (final MapEntry(:key, :value) in accounts.entries)
          key: value.type.trim(),
      },
      'category': {
        for (final c
            in await categories
                .watchPage(
                  companyId: companyId,
                  loadedPages: kRecordReportAllPages,
                  states: EntityState.values.toSet(),
                )
                .first)
          c.id: c.name,
      },
    };
    return ReportLookups(
      names: names,
      remap: remap,
      currencies: currencies(),
      companyCurrencyId: await companyCurrencyId(),
    );
  },
  build: (records, query, lookups) => buildTransactionsPreview(
    transactions: records,
    query: query,
    lookups: lookups,
  ),
  namesToFetch: (records, query, lookups) {
    final ids = _linkedIds([
      for (final t in records)
        if (_matches(t, query)) t,
    ]);
    return {
      for (final kind in const [
        'vendor',
        'invoice',
        'expense',
        'payment',
        'bank_account',
      ])
        kind: unnamedIds(lookups, kind, ids[kind] ?? const {}),
    };
  },
  hydrateNames: (companyId, ids) async {
    await reportEnsureLoaded(
      ids['vendor'],
      (id) => vendors.ensureLoaded(companyId: companyId, id: id),
    );
    await reportEnsureLoaded(
      ids['invoice'],
      (id) => invoices.ensureLoaded(companyId: companyId, id: id),
    );
    await reportEnsureLoaded(
      ids['expense'],
      (id) => expenses.ensureLoaded(companyId: companyId, id: id),
    );
    await reportEnsureLoaded(
      ids['payment'],
      (id) => payments.ensureLoaded(companyId: companyId, id: id),
    );
    await reportEnsureLoaded(
      ids['bank_account'],
      (id) => bankAccounts.ensureLoaded(companyId: companyId, id: id),
    );
  },
);

/// The records [transactions] name, by kind.
Map<String, Set<String>> _linkedIds(Iterable<BankTransaction> transactions) {
  final out = <String, Set<String>>{
    'vendor': {},
    'invoice': {},
    'expense': {},
    'payment': {},
    'bank_account': {},
  };
  for (final t in transactions) {
    if (t.vendorId.isNotEmpty) out['vendor']!.add(t.vendorId);
    out['invoice']!.addAll(t.linkedInvoiceIds);
    out['expense']!.addAll(t.linkedExpenseIds);
    if (t.paymentId.isNotEmpty) out['payment']!.add(t.paymentId);
    if (t.bankAccountId.isNotEmpty) out['bank_account']!.add(t.bankAccountId);
  }
  return out;
}

/// The list filters a refresh sends: the transactions dated in the range.
///
/// `date_range` is the two-part `start,end`, which every server version
/// applies to `bank_transactions.date` (`QueryFilters::date_range`).
Map<String, Set<String>> transactionsFetchFilters(ReportQuery query) => {
  if (!query.isAllTime)
    'date_range': {'${query.start!.toIso()},${query.end!.toIso()}'},
};

/// The report's columns, the default ones first.
const List<String> kTransactionsColumnIds = [
  'bank_transaction.date',
  'bank_transaction.description',
  'bank_transaction.status',
  'bank_transaction.deposit',
  'bank_transaction.withdrawal',
  'bank_account.name',
  'bank_transaction.invoices',
  'bank_transaction.expense_number',
  'vendor.name',
  'bank_transaction.category_id',
  'payment.number',
  'bank_transaction.amount',
  'bank_account.type',
  'bank_transaction.category_type',
  'bank_transaction.participant',
  'bank_transaction.participant_name',
  'bank_transaction.created_at',
  'bank_transaction.updated_at',
  'bank_transaction.currency_id',
  'bank_transaction.record_state',
];

ReportColumnSpec _text(String labelKey) =>
    (labelKey: labelKey, type: ReportColumnType.string, aggregation: null);

final Map<String, ReportColumnSpec> _kColumns = {
  'bank_transaction.date': (
    labelKey: 'date',
    type: ReportColumnType.date,
    aggregation: null,
  ),
  'bank_transaction.description': _text('description'),
  'bank_transaction.status': _text('status'),
  'bank_transaction.deposit': (
    labelKey: 'deposit',
    type: ReportColumnType.money,
    aggregation: ReportAggregation.sum,
  ),
  'bank_transaction.withdrawal': (
    labelKey: 'withdrawal',
    type: ReportColumnType.money,
    aggregation: ReportAggregation.sum,
  ),
  'bank_account.name': _text('bank_account'),
  'bank_transaction.invoices': _text('invoices'),
  'bank_transaction.expense_number': _text('expense_number'),
  'vendor.name': _text('vendor'),
  'bank_transaction.category_id': _text('category'),
  'payment.number': _text('payment'),
  // Money in and money out alike, unsigned: a sum of both means nothing,
  // and the deposit and withdrawal columns are the totals.
  'bank_transaction.amount': (
    labelKey: 'amount',
    type: ReportColumnType.money,
    aggregation: ReportAggregation.none,
  ),
  'bank_account.type': _text('account_type'),
  // The bank's own category for the transaction.
  'bank_transaction.category_type': _text('default_category'),
  'bank_transaction.participant': _text('participant'),
  'bank_transaction.participant_name': _text('participant_name'),
  'bank_transaction.created_at': (
    labelKey: 'created_at',
    type: ReportColumnType.dateTime,
    aggregation: null,
  ),
  'bank_transaction.updated_at': (
    labelKey: 'updated_at',
    type: ReportColumnType.dateTime,
    aggregation: null,
  ),
  // The ISO code the view model reads each row's currency from.
  'bank_transaction.currency_id': _text('currency'),
  'bank_transaction.record_state': _text('record_state'),
};

/// The Status filter's values, which are the list's status keys.
String transactionStatusKey(BankTransaction t) {
  if (t.isMatched) return 'matched';
  if (t.isConverted) return 'converted';
  return 'unmatched';
}

bool _matches(BankTransaction t, ReportQuery query) {
  if (t.isDeleted && !query.includeDeleted) return false;
  if (query.tagIds.isNotEmpty && !t.tagIds.any(query.tagIds.contains)) {
    return false;
  }
  final statuses = reportCsv(query.status);
  if (statuses.isNotEmpty &&
      !statuses.contains('all') &&
      !statuses.contains(transactionStatusKey(t))) {
    return false;
  }
  return reportDateInRange(t.date, query);
}

/// The report's rows from [transactions] — every one that passes [query]'s
/// filters, oldest first.
ReportPreview buildTransactionsPreview({
  required Iterable<BankTransaction> transactions,
  required ReportQuery query,
  ReportLookups lookups = const ReportLookups(),
}) {
  final kept = [
    for (final t in transactions)
      if (_matches(t, query)) t,
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
    return a.id.compareTo(b.id);
  });
  return ReportPreview(
    columns: reportColumnsOf(kTransactionsColumnIds, _kColumns, query),
    rows: [for (final t in kept) _row(t, query, lookups)],
  );
}

ReportRow _row(BankTransaction t, ReportQuery query, ReportLookups lookups) {
  final currency = lookups.currencyOr(t.currencyId);
  String numbers(String kind, List<String> ids) => [
    for (final id in ids)
      if (lookups.nameOf(kind, id) case final n when n.isNotEmpty) n,
  ].join(', ');
  final vendorId = lookups.idOf(t.vendorId);
  final paymentId = lookups.idOf(t.paymentId);
  final cells = <String, ReportCell>{
    'bank_transaction.date': reportDate(t.date),
    'bank_transaction.description': reportText(
      plainTextFromHtml(t.description, singleLine: true),
    ),
    'bank_transaction.status': reportText(query.label(transactionStatusKey(t))),
    'bank_transaction.deposit': t.isDeposit
        ? reportMoney(t.amount)
        : const ReportNumberCell(isMoney: true),
    'bank_transaction.withdrawal': t.isWithdrawal
        ? reportMoney(t.amount)
        : const ReportNumberCell(isMoney: true),
    'bank_account.name': reportText(
      lookups.nameOf('bank_account', t.bankAccountId),
      wire: 'bank_account',
      id: lookups.idOf(t.bankAccountId),
    ),
    'bank_transaction.invoices': reportText(
      numbers('invoice', t.linkedInvoiceIds),
    ),
    'bank_transaction.expense_number': reportText(
      numbers('expense', t.linkedExpenseIds),
    ),
    'vendor.name': reportText(
      lookups.nameOf('vendor', t.vendorId),
      wire: 'vendor',
      id: vendorId,
    ),
    'bank_transaction.category_id': reportText(
      lookups.nameOf('category', t.categoryId),
    ),
    'payment.number': reportText(
      lookups.nameOf('payment', t.paymentId),
      wire: 'payment',
      id: paymentId,
    ),
    'bank_transaction.amount': reportMoney(t.amount),
    'bank_account.type': reportText(
      t.bankAccountId.isEmpty
          ? ''
          : (lookups.names['bank_account_type']?[lookups.idOf(
                  t.bankAccountId,
                )] ??
                ''),
    ),
    'bank_transaction.category_type': reportText(t.category),
    'bank_transaction.participant': reportText(t.participant),
    'bank_transaction.participant_name': reportText(t.participantName),
    'bank_transaction.created_at': reportDateTime(t.createdAt),
    'bank_transaction.updated_at': reportDateTime(t.updatedAt),
    'bank_transaction.currency_id': reportText(currency?.code ?? ''),
    'bank_transaction.record_state': reportRecordState(
      isDeleted: t.isDeleted,
      archivedAt: t.archivedAt,
      query: query,
    ),
  };
  final real = !t.id.startsWith('tmp_');
  return ReportRow(
    cells: [for (final id in kTransactionsColumnIds) cells[id]!],
    recordWire: real ? 'bank_transaction' : null,
    recordId: real ? t.id : null,
    currencyId: currency?.id,
  );
}
