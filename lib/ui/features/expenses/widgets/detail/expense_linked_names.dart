import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// The records an expense — or a recurring one — points at, **by name**.
///
/// An empty string means "no such link, or not resolved": the record is not
/// in the local cache yet, has been deleted, or is one this user may not
/// fetch. A caller cannot tell those apart and does not need to — an
/// unlabelled slot (the line under the number) leaves the entry out, and a
/// labelled one (a Details row) shows a dash that still links.
@immutable
class ExpenseLinkedNames {
  const ExpenseLinkedNames({
    this.vendor = '',
    this.client = '',
    this.category = '',
    this.project = '',
    this.invoice = '',
    this.recurringExpense = '',
    this.transaction = '',
  });

  static const ExpenseLinkedNames none = ExpenseLinkedNames();

  final String vendor;
  final String client;
  final String category;
  final String project;

  /// The invoice's number, bare.
  final String invoice;

  /// The recurring expense's number, bare.
  final String recurringExpense;

  /// The bank transaction's description.
  final String transaction;
}

/// Resolves [ExpenseLinkedNames] once, above everything that prints them.
///
/// The header's subtitle and the Details card both name the same records. A
/// `*NameLabel` per slot would resolve each on its own, and the subtitle
/// would have to print something for a link that never resolves — an icon
/// beside a dash, in the most prominent line on the screen. Hoisted here, an
/// unresolved name is simply an entry the subtitle does not have.
///
/// Each id is watched in the local cache, seeded from the repository's
/// first-frame `peek` so a record opened from a list paints its names in the
/// frame it mounts, and asked for once if it is not held (deduped and
/// negative-cached by the repositories, like every name label).
class ExpenseLinkedNamesBuilder extends StatefulWidget {
  const ExpenseLinkedNamesBuilder({
    super.key,
    required this.companyId,
    required this.builder,
    this.vendorId = '',
    this.clientId = '',
    this.categoryId = '',
    this.projectId = '',
    this.invoiceId = '',
    this.recurringExpenseId = '',
    this.transactionId = '',
  });

  final String companyId;
  final String vendorId;
  final String clientId;
  final String categoryId;
  final String projectId;
  final String invoiceId;
  final String recurringExpenseId;
  final String transactionId;

  final Widget Function(BuildContext context, ExpenseLinkedNames names) builder;

  @override
  State<ExpenseLinkedNamesBuilder> createState() =>
      _ExpenseLinkedNamesBuilderState();
}

class _ExpenseLinkedNamesBuilderState extends State<ExpenseLinkedNamesBuilder> {
  @override
  void initState() {
    super.initState();
    _ensure(null);
  }

  @override
  void didUpdateWidget(ExpenseLinkedNamesBuilder old) {
    super.didUpdateWidget(old);
    _ensure(old);
  }

  /// Asks for each linked record that is new since [old]. A paginated list
  /// holds only the pages that were browsed, so the vendor of an expense
  /// reached by a link is usually not here yet.
  void _ensure(ExpenseLinkedNamesBuilder? old) {
    final s = context.read<Services>();
    final w = widget;
    final cid = w.companyId;
    void ask(String id, String? was, void Function() fetch) {
      if (id.isNotEmpty && (old == null || id != was)) fetch();
    }

    ask(
      w.vendorId,
      old?.vendorId,
      () => s.vendors.ensureLoaded(companyId: cid, id: w.vendorId),
    );
    ask(
      w.clientId,
      old?.clientId,
      () => s.clients.ensureLoaded(companyId: cid, id: w.clientId),
    );
    ask(
      w.categoryId,
      old?.categoryId,
      () => s.expenseCategories.ensureLoaded(companyId: cid, id: w.categoryId),
    );
    ask(
      w.projectId,
      old?.projectId,
      () => s.projects.ensureLoaded(companyId: cid, id: w.projectId),
    );
    ask(
      w.invoiceId,
      old?.invoiceId,
      () => s.invoices.ensureLoaded(companyId: cid, id: w.invoiceId),
    );
    ask(
      w.recurringExpenseId,
      old?.recurringExpenseId,
      () => s.recurringExpenses.ensureLoaded(
        companyId: cid,
        id: w.recurringExpenseId,
      ),
    );
    ask(
      w.transactionId,
      old?.transactionId,
      () =>
          s.bankTransactions.ensureLoaded(companyId: cid, id: w.transactionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<Services>();
    final w = widget;
    final links = <_Link<Object>>[
      _Link<Vendor>(w.vendorId, s.vendors, (v) => v.name),
      _Link<Client>(
        w.clientId,
        s.clients,
        (c) => c.displayName.isNotEmpty ? c.displayName : c.name,
      ),
      _Link<ExpenseCategory>(w.categoryId, s.expenseCategories, (c) => c.name),
      _Link<Project>(w.projectId, s.projects, (p) => p.name),
      _Link<Invoice>(w.invoiceId, s.invoices, (i) => i.number),
      _Link<RecurringExpense>(
        w.recurringExpenseId,
        s.recurringExpenses,
        (r) => r.number,
      ),
      _Link<BankTransaction>(
        w.transactionId,
        s.bankTransactions,
        (t) => t.description,
      ),
    ];
    // One watch inside the next, so the shape of the tree never depends on
    // which links an expense has: gaining a vendor in an edit must not
    // remount the header and cards under this.
    Widget resolve(BuildContext context, int at, List<String> names) {
      if (at == links.length) {
        return w.builder(
          context,
          ExpenseLinkedNames(
            vendor: names[0],
            client: names[1],
            category: names[2],
            project: names[3],
            invoice: names[4],
            recurringExpense: names[5],
            transaction: names[6],
          ),
        );
      }
      return links[at].watch(
        w.companyId,
        (context, name) => resolve(context, at + 1, [...names, name]),
      );
    }

    return resolve(context, 0, const []);
  }
}

/// One linked record: its id, where it lives, and what to call it.
class _Link<T extends Object> {
  const _Link(this.id, this.repo, this.nameOf);

  final String id;
  final BaseEntityRepository<T, dynamic> repo;
  final String Function(T record) nameOf;

  Widget watch(
    String companyId,
    Widget Function(BuildContext context, String name) next,
  ) {
    return WatchBuilder<T?>(
      cacheKey: (companyId, id),
      initialData: id.isEmpty ? null : repo.peek(companyId: companyId, id: id),
      create: () => id.isEmpty
          ? Stream<T?>.empty()
          : repo.watch(companyId: companyId, id: id),
      builder: (context, snapshot) {
        final record = snapshot.data;
        // The id check first: a `StreamBuilder` keeps its last value across a
        // change of stream, and the stream for "no link" never emits — so a
        // vendor taken off an expense would otherwise keep its name here.
        return next(
          context,
          id.isEmpty || record == null ? '' : nameOf(record),
        );
      },
    );
  }
}
