import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/db/dao/expense_dao.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/db/dao/payment_dao.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/db/dao/purchase_order_dao.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/domain/columns/bank_transaction_columns.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/credit_columns.dart';
import 'package:admin/domain/columns/expense_columns.dart';
import 'package:admin/domain/columns/invoice_columns.dart';
import 'package:admin/domain/columns/payment_columns.dart';
import 'package:admin/domain/columns/product_columns.dart';
import 'package:admin/domain/columns/project_columns.dart';
import 'package:admin/domain/columns/purchase_order_columns.dart';
import 'package:admin/domain/columns/quote_columns.dart';
import 'package:admin/domain/columns/recurring_expense_columns.dart';
import 'package:admin/domain/columns/recurring_invoice_columns.dart';
import 'package:admin/domain/columns/task_columns.dart';
import 'package:admin/domain/columns/user_columns.dart';
import 'package:admin/domain/columns/vendor_columns.dart';

/// Every column header is a sort control (`EntityListColumnHeaders._HeaderCell`
/// wires `onTap: vm.setSort(field: column.id)`), and most DAOs `throw
/// ArgumentError` from `_sortExpression`'s `default:` branch. So a column that
/// is registered in `kAll*Columns` but has no `_sortExpression` case takes the
/// whole list down the moment its header is clicked: the throw is synchronous
/// inside the repo's `watchPage`, so the watch subscription is left cancelled
/// and every later search / filter silently no-ops.
///
/// This test locks the invariant: a column is either **sortable and mapped** in
/// its DAO, or explicitly marked `sortable: false`.
///
/// Every list DAO now THROWS on an unmapped sort field, so this probe detects a
/// gap for all of them — that is the whole mechanism. Any DAO that silently
/// falls back instead makes its own dead headers invisible here, which is
/// exactly how six bank-transaction columns and `user.phone` shipped ordering
/// by something else.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Building the query is enough — Drift evaluates `orderBy` generators
  /// eagerly, so an unmapped field throws before the stream is ever listened to.
  void probe(void Function(String sortField) build, String field) =>
      build(field);

  final cases =
      <
        String,
        ({List<ColumnDefinition<Object?>> columns, void Function(String) build})
      >{};

  void register<T>(
    String name,
    List<ColumnDefinition<T>> columns,
    void Function(String sortField) build,
  ) {
    cases[name] = (
      columns: columns.cast<ColumnDefinition<Object?>>(),
      build: build,
    );
  }

  test('every sortable column resolves to a DAO sort expression', () {
    register<dynamic>(
      'payment',
      kAllPaymentColumns,
      (f) => db.paymentDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'credit',
      kAllCreditColumns,
      (f) => db.creditDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'purchase_order',
      kAllPurchaseOrderColumns,
      (f) => db.purchaseOrderDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'recurring_invoice',
      kAllRecurringInvoiceColumns,
      (f) => db.recurringInvoiceDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'invoice',
      kAllInvoiceColumns,
      (f) => db.invoiceDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'quote',
      kAllQuoteColumns,
      (f) => db.quoteDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'expense',
      kAllExpenseColumns,
      (f) => db.expenseDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'recurring_expense',
      kAllRecurringExpenseColumns,
      (f) => db.recurringExpenseDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'product',
      kAllProductColumns,
      (f) => db.productDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'task',
      kAllTaskColumns,
      (f) => db.taskDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'project',
      kAllProjectColumns,
      (f) => db.projectDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'bank_transaction',
      kAllBankTransactionColumns,
      (f) => db.bankTransactionDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'client',
      kAllClientColumns,
      (f) => db.clientDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'user',
      kAllUserColumns,
      (f) => db.userDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );
    register<dynamic>(
      'vendor',
      kAllVendorColumns,
      (f) => db.vendorDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 10,
        sortField: f,
      ),
    );

    final unmapped = <String>[];
    cases.forEach((entity, c) {
      for (final column in c.columns) {
        if (!column.sortable) continue;
        try {
          probe(c.build, column.id);
        } on ArgumentError {
          unmapped.add('$entity.${column.id}');
        }
      }
    });

    expect(
      unmapped,
      isEmpty,
      reason:
          'These columns are offered in the Columns picker and their headers '
          'are sort controls, but their DAO throws on the sort field. Either '
          'add a `_sortExpression` case or mark the column `sortable: false`:\n'
          '${unmapped.join('\n')}',
    );
  });

  test('display-only columns stay marked non-sortable', () {
    // Pins the intent so the flag can't be flipped back to silence a real
    // unmapped-sort bug. Every id here is payload-derived — tags, free-text
    // notes, a computed status, or a foreign-key "View" link — with no Drift
    // column behind it. Task/project tags are deliberately absent: they have a
    // denormalized `tag_names` column and DO sort.
    final displayOnly = <String, List<String>>{
      'client': [ClientFieldIds.tagIds],
      'vendor': [VendorFieldIds.tagIds],
      'product': [ProductFieldIds.tagIds],
      'payment': [PaymentFieldIds.tagIds],
      'credit': [CreditFieldIds.tagIds],
      'quote': [QuoteFieldIds.publicNotes, QuoteFieldIds.tagIds],
      'purchase_order': [PurchaseOrderFieldIds.tagIds],
      'recurring_invoice': [RecurringInvoiceFieldIds.tagIds],
      'bank_transaction': [BankTransactionColumnIds.tagIds],
      'invoice': [
        InvoiceFieldIds.recurringId,
        InvoiceFieldIds.publicNotes,
        InvoiceFieldIds.privateNotes,
        InvoiceFieldIds.tagIds,
      ],
      'expense': [
        ExpenseFieldIds.status,
        ExpenseFieldIds.transactionId,
        ExpenseFieldIds.publicNotes,
        ExpenseFieldIds.privateNotes,
        ExpenseFieldIds.tagIds,
      ],
      'recurring_expense': [
        RecurringExpenseFieldIds.status,
        RecurringExpenseFieldIds.publicNotes,
        RecurringExpenseFieldIds.privateNotes,
        RecurringExpenseFieldIds.tagIds,
      ],
    };

    final byEntity = <String, Map<String, ColumnDefinition<Object?>>>{
      'client': clientColumnsById.cast(),
      'vendor': vendorColumnsById.cast(),
      'product': productColumnsById.cast(),
      'payment': paymentColumnsById.cast(),
      'credit': creditColumnsById.cast(),
      'quote': quoteColumnsById.cast(),
      'purchase_order': purchaseOrderColumnsById.cast(),
      'recurring_invoice': recurringInvoiceColumnsById.cast(),
      'bank_transaction': bankTransactionColumnsById.cast(),
      'invoice': invoiceColumnsById.cast(),
      'expense': expenseColumnsById.cast(),
      'recurring_expense': recurringExpenseColumnsById.cast(),
    };

    displayOnly.forEach((entity, ids) {
      for (final id in ids) {
        final column = byEntity[entity]![id];
        expect(column, isNotNull, reason: '$entity.$id is not registered');
        expect(
          column!.sortable,
          isFalse,
          reason: '$entity.$id has no sort expression — keep sortable: false',
        );
      }
    });

    // …and the two that DO sort by a real denormalized column stay sortable.
    expect(taskColumnsById[TaskFieldIds.tagIds]!.sortable, isTrue);
    expect(projectColumnsById[ProjectFieldIds.tagIds]!.sortable, isTrue);
  });
}
