import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/payment_status.dart';
import 'package:admin/domain/recurring_expense_status.dart';

/// The invariant the whole status-tab feature rests on (issue #98): **the
/// number on a tab and the rows under it are one predicate.**
///
/// The tab's count comes from `watchBadgeCount(modeId:)` and its rows from
/// `watchPage(badgeModeId:)`, and both delegate to the same
/// `badgeModePredicate`. If a DAO ever forgets to apply the list filter the two
/// diverge silently — the strip still switches, the list just doesn't narrow,
/// and a tab reading "Draft 6" sits above every row in the company.
///
/// **Scope, precisely.** The equality holds for the default `states:
/// {active}` — which is the only scope where the counts are rendered at all.
/// `watchBadgeCount` always ANDs the active-only `badgeBaseFilter` while
/// `watchPage` honours `states`, so the two genuinely diverge for an archived
/// or deleted view; the strip's `showCounts` gate is what keeps that off screen
/// (pinned below, and in `entity_list_status_tabs_test.dart`). Don't read this
/// file as a claim that the numbers can never be wrong — read it as the reason
/// the badges stand down when the scope changes.
///
/// So for every entity and every declared tab this asserts:
///
///  * `rows(mode).length == count(mode)`,
///  * every filtered row is also in the unfiltered list, and
///  * at least one mode per entity is a **proper** subset — without which the
///    first two assertions would pass just as happily against a DAO that
///    ignores `badgeModeId` entirely.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const co = 'co';
  final past = Date.today().addDays(-2).toIso();
  final future = Date.today().addDays(2).toIso();

  // Each entity: seed a spread of rows (including an archived and a deleted one,
  // which the shared base filter must drop on both sides), then expose the two
  // sides of the invariant.
  final entities =
      <
        EntityType,
        ({
          Future<void> Function() seed,
          Future<List<String>> Function(String? mode) rows,
          Future<int> Function(String mode) count,
        })
      >{};

  // -- Invoice --------------------------------------------------------------
  Future<void> invoice(
    String id, {
    String status = '2',
    String balance = '10',
    String dueDate = '',
    String clientId = '',
    String? number,
    int? archivedAt,
    bool deleted = false,
  }) => db.invoiceDao.upsert(
    InvoicesCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      number: Value(number ?? id),
      statusId: Value(status),
      balance: Value(balance),
      dueDate: Value(dueDate),
      clientId: Value(clientId),
      archivedAt: Value(archivedAt),
      isDeleted: Value(deleted),
    ),
  );
  entities[EntityType.invoice] = (
    seed: () async {
      await invoice('i-draft', status: '1');
      await invoice('i-sent');
      await invoice('i-partial', status: '3');
      await invoice('i-overdue', dueDate: past);
      await invoice('i-paid', status: '4', balance: '0');
      await invoice('i-archived', status: '1', archivedAt: 5);
      await invoice('i-deleted', status: '1', deleted: true);
    },
    rows: (m) => db.invoiceDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.invoiceDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Quote ----------------------------------------------------------------
  Future<void> quote(
    String id, {
    String status = '1',
    String dueDate = '',
    String invoiceId = '',
  }) => db.quoteDao.upsert(
    QuotesCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      statusId: Value(status),
      dueDate: Value(dueDate),
      invoiceId: Value(invoiceId),
    ),
  );
  entities[EntityType.quote] = (
    seed: () async {
      await quote('q-draft');
      await quote('q-sent', status: '2', dueDate: future);
      await quote('q-approved', status: '3');
      await quote('q-expired', status: '2', dueDate: past);
      await quote('q-converted', status: '4', invoiceId: 'inv1');
    },
    rows: (m) => db.quoteDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.quoteDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Credit ---------------------------------------------------------------
  Future<void> credit(String id, {String status = '1', String balance = '0'}) =>
      db.creditDao.upsert(
        CreditsCompanion.insert(
          id: id,
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          statusId: Value(status),
          balance: Value(balance),
        ),
      );
  entities[EntityType.credit] = (
    seed: () async {
      await credit('c-draft');
      await credit('c-sent', status: '2', balance: '25');
      await credit('c-applied', status: '4');
    },
    rows: (m) => db.creditDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.creditDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Payment --------------------------------------------------------------
  Future<void> payment(
    String id, {
    required String status,
    String amount = '10',
    String applied = '10',
  }) => db.paymentDao.upsert(
    PaymentsCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      statusId: Value(status),
      amount: Value(amount),
      applied: Value(applied),
    ),
  );
  entities[EntityType.payment] = (
    seed: () async {
      await payment('p-pending', status: kPaymentStatusPending);
      await payment('p-failed', status: kPaymentStatusFailed);
      await payment('p-done', status: kPaymentStatusCompleted);
      await payment(
        'p-unapplied',
        status: kPaymentStatusCompleted,
        applied: '2',
      );
    },
    rows: (m) => db.paymentDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.paymentDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Expense --------------------------------------------------------------
  Future<void> expense(
    String id, {
    bool paid = true,
    bool shouldBeInvoiced = false,
    String invoiceId = '',
    String vendorId = '',
  }) => db.expenseDao.upsert(
    ExpensesCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      isPaid: Value(paid),
      shouldBeInvoiced: Value(shouldBeInvoiced),
      invoiceId: Value(invoiceId),
      vendorId: Value(vendorId),
    ),
  );
  entities[EntityType.expense] = (
    seed: () async {
      await expense('e-logged');
      await expense('e-pending', shouldBeInvoiced: true);
      await expense('e-unpaid', paid: false);
      await expense('e-invoiced', invoiceId: 'inv1');
    },
    rows: (m) => db.expenseDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.expenseDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Recurring invoice ----------------------------------------------------
  Future<void> recurringInvoice(String id, {required String status}) =>
      db.recurringInvoiceDao.upsert(
        RecurringInvoicesCompanion.insert(
          id: id,
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          statusId: Value(status),
        ),
      );
  entities[EntityType.recurringInvoice] = (
    seed: () async {
      await recurringInvoice('r-draft', status: '1');
      await recurringInvoice('r-active', status: '2');
      await recurringInvoice('r-paused', status: '3');
      await recurringInvoice('r-done', status: '4');
    },
    rows: (m) => db.recurringInvoiceDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) =>
        db.recurringInvoiceDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Recurring expense ----------------------------------------------------
  Future<void> recurringExpense(
    String id, {
    required String status,
    int remainingCycles = 3,
    String lastSentDate = '',
  }) => db.recurringExpenseDao.upsert(
    RecurringExpensesCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      statusId: Value(status),
      remainingCycles: Value(remainingCycles),
      lastSentDate: Value(lastSentDate),
    ),
  );
  entities[EntityType.recurringExpense] = (
    seed: () async {
      await recurringExpense('re-draft', status: kRecurringExpenseStatusDraft);
      await recurringExpense(
        're-active',
        status: kRecurringExpenseStatusActive,
        lastSentDate: past,
      );
      await recurringExpense(
        're-pending',
        status: kRecurringExpenseStatusActive,
      );
      await recurringExpense(
        're-paused',
        status: kRecurringExpenseStatusPaused,
      );
      await recurringExpense(
        're-done',
        status: kRecurringExpenseStatusActive,
        remainingCycles: 0,
      );
    },
    rows: (m) => db.recurringExpenseDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) =>
        db.recurringExpenseDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Purchase order -------------------------------------------------------
  Future<void> purchaseOrder(String id, {required String status}) =>
      db.purchaseOrderDao.upsert(
        PurchaseOrdersCompanion.insert(
          id: id,
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          statusId: Value(status),
        ),
      );
  entities[EntityType.purchaseOrder] = (
    seed: () async {
      await purchaseOrder('po-draft', status: '1');
      await purchaseOrder('po-sent', status: '2');
      await purchaseOrder('po-accepted', status: '3');
      await purchaseOrder('po-cancelled', status: '5');
    },
    rows: (m) => db.purchaseOrderDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) =>
        db.purchaseOrderDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Transaction ----------------------------------------------------------
  entities[EntityType.transaction] = (
    seed: () async {
      for (final (id, status) in [
        ('t-unmatched', '1'),
        ('t-matched', '2'),
        ('t-converted', '3'),
      ]) {
        await db.bankTransactionDao.upsert(
          BankTransactionsCompanion.insert(
            id: id,
            companyId: co,
            updatedAt: 1,
            payload: '{}',
            statusId: Value(status),
          ),
        );
      }
    },
    rows: (m) => db.bankTransactionDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) =>
        db.bankTransactionDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Task -----------------------------------------------------------------
  entities[EntityType.task] = (
    seed: () async {
      for (final (id, running, invoiceId) in [
        ('t-running', true, ''),
        ('t-idle', false, ''),
        ('t-invoiced', false, 'inv1'),
      ]) {
        await db.taskDao.upsert(
          TasksCompanion.insert(
            id: id,
            companyId: co,
            updatedAt: 1,
            payload: '{}',
            isRunning: Value(running),
            invoiceId: Value(invoiceId),
          ),
        );
      }
    },
    rows: (m) => db.taskDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.taskDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Project --------------------------------------------------------------
  entities[EntityType.project] = (
    seed: () async {
      for (final (id, dueDate, budget, current) in [
        ('pr-overdue', past, 0.0, 0.0),
        ('pr-fine', future, 0.0, 0.0),
        ('pr-over-budget', '', 5.0, 9.0),
        ('pr-under-budget', '', 5.0, 1.0),
      ]) {
        await db.projectDao.upsert(
          ProjectsCompanion.insert(
            id: id,
            companyId: co,
            updatedAt: 1,
            payload: '{}',
            dueDate: Value(dueDate),
            budgetedHours: Value(budget),
            currentHours: Value(current),
          ),
        );
      }
    },
    rows: (m) => db.projectDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.projectDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Client (cross-entity subquery on invoices) ---------------------------
  Future<void> client(String id, {String balance = '0'}) => db.clientDao.upsert(
    ClientsCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      name: id,
      number: id,
      email: '',
      displayName: id,
      balance: balance,
    ),
  );
  entities[EntityType.client] = (
    seed: () async {
      await client('cl-late', balance: '50');
      await client('cl-outstanding', balance: '20');
      await client('cl-clear');
      await invoice('cl-inv', dueDate: past, clientId: 'cl-late');
    },
    rows: (m) => db.clientDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.clientDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Vendor (cross-entity subqueries on expenses + purchase orders) -------
  entities[EntityType.vendor] = (
    seed: () async {
      for (final id in ['v-owing', 'v-po', 'v-clear']) {
        await db.vendorDao.upsert(
          VendorsCompanion.insert(
            id: id,
            companyId: co,
            updatedAt: 1,
            payload: '{}',
            name: id,
            number: id,
            idNumber: '',
            vatNumber: '',
            city: '',
            countryId: '',
            currencyId: '',
            phone: '',
            displayName: id,
          ),
        );
      }
      await expense('v-exp', paid: false, vendorId: 'v-owing');
      await db.purchaseOrderDao.upsert(
        PurchaseOrdersCompanion.insert(
          id: 'v-po-1',
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          statusId: const Value('2'),
          vendorId: const Value('v-po'),
        ),
      );
    },
    rows: (m) => db.vendorDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.vendorDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  // -- Product (payload JSON + the company inventory gate) ------------------
  entities[EntityType.product] = (
    seed: () async {
      await db.companiesDao.upsertAll([
        CompaniesCompanion.insert(
          id: co,
          name: 'Co',
          settings: '{}',
          permissions: '{}',
          accountId: 'a',
          token: 't',
          updatedAt: 1,
          trackInventory: const Value(true),
          inventoryNotificationThreshold: const Value(4),
        ),
      ]);
      for (final (id, qty) in [('pd-out', 0), ('pd-low', 2), ('pd-ok', 40)]) {
        await db.productDao.upsert(
          ProductsCompanion.insert(
            id: id,
            companyId: co,
            updatedAt: 1,
            payload: '{"in_stock_quantity": $qty}',
            productKey: id,
            notes: '',
            price: '1',
            cost: '1',
            quantity: '1',
          ),
        );
      }
    },
    rows: (m) => db.productDao
        .watchPage(companyId: co, offset: 0, limit: 500, badgeModeId: m)
        .first
        .then((r) => r.map((e) => e.id).toList()),
    count: (m) => db.productDao.watchBadgeCount(companyId: co, modeId: m).first,
  );

  for (final type in kListStatusTabs.keys) {
    final entity = entities[type];

    test('${type.name}: every tab counts exactly the rows it lists', () async {
      expect(
        entity,
        isNotNull,
        reason:
            'kListStatusTabs declares tabs for ${type.name} but this test has '
            'no fixture for it — add one rather than dropping the entity, or '
            'the count-equals-rows invariant ships unguarded.',
      );
      await entity!.seed();

      final all = await entity.rows(null);
      expect(
        all,
        isNotEmpty,
        reason:
            'the fixture must seed rows or every assertion below is vacuous',
      );

      var sawProperSubset = false;
      for (final spec in kListStatusTabs[type]!) {
        final rows = await entity.rows(spec.modeId);
        final count = await entity.count(spec.modeId);
        expect(
          rows.length,
          count,
          reason:
              '${type.name}/${spec.modeId}: the tab would show ${rows.length} '
              'rows under a badge reading $count',
        );
        expect(
          rows,
          everyElement(isIn(all)),
          reason:
              '${type.name}/${spec.modeId} surfaced a row the unfiltered list '
              'does not contain',
        );
        if (rows.length < all.length) sawProperSubset = true;
      }

      expect(
        sawProperSubset,
        isTrue,
        reason:
            'no ${type.name} tab narrowed anything, so this fixture would pass '
            'against a DAO that ignores badgeModeId entirely — seed rows that '
            'at least one mode excludes',
      );
    });
  }

  group('composition with the other filter axes', () {
    // The per-entity loop above exercises exactly one axis. These pin the
    // intersections the UI actually produces — a list is routinely scoped to a
    // client, searched, and paged all at once.
    test('a tab intersects a parent scope rather than replacing it', () async {
      await entities[EntityType.invoice]!.seed();
      await invoice('c-draft', status: '1', clientId: 'acme');
      await invoice('c-sent', clientId: 'acme');

      final rows = await db.invoiceDao
          .watchPage(
            companyId: co,
            offset: 0,
            limit: 500,
            badgeModeId: 'draft',
            clientId: 'acme',
          )
          .first;
      expect(rows.map((r) => r.id), ['c-draft']);
    });

    test('a tab intersects the search term', () async {
      await invoice('needle', status: '1');
      await invoice('other', status: '1');

      final rows = await db.invoiceDao
          .watchPage(
            companyId: co,
            offset: 0,
            limit: 500,
            badgeModeId: 'draft',
            search: 'needle',
          )
          .first;
      expect(rows.map((r) => r.id), ['needle']);
    });

    test('a tab narrows PRE-LIMIT, so a small window is filled with matches '
        'rather than with rows the predicate then throws away', () async {
      // The claim every DAO carries in its inserted comment. Seed 5 drafts
      // among 5 non-drafts and take a window of 2: a post-LIMIT filter would
      // return 0-2 arbitrary rows, a pre-LIMIT one returns exactly 2 drafts.
      for (var i = 0; i < 5; i++) {
        await invoice('d$i', status: '1');
        await invoice('s$i');
      }
      final rows = await db.invoiceDao
          .watchPage(companyId: co, offset: 0, limit: 2, badgeModeId: 'draft')
          .first;
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.statusId == '1'), isTrue);
    });

    test('a tab still filters under a non-default lifecycle scope — the counts '
        'are what stand down there, not the rows', () async {
      await invoice('live-draft', status: '1');
      await invoice('arch-draft', status: '1', archivedAt: 5);
      await invoice('arch-sent', archivedAt: 5);

      final rows = await db.invoiceDao
          .watchPage(
            companyId: co,
            offset: 0,
            limit: 500,
            badgeModeId: 'draft',
            states: const {EntityState.archived},
          )
          .first;
      expect(rows.map((r) => r.id), ['arch-draft']);

      // …and this is the divergence the strip hides rather than renders: the
      // count is active-only, so it does NOT describe the list above.
      final count = await db.invoiceDao
          .watchBadgeCount(companyId: co, modeId: 'draft')
          .first;
      expect(count, 1); // 'live-draft' only
    });
  });

  test('a null or `total` mode narrows nothing', () async {
    await entities[EntityType.invoice]!.seed();
    final unfiltered = await entities[EntityType.invoice]!.rows(null);
    final total = await entities[EntityType.invoice]!.rows(kBadgeModeTotal);
    expect(total, unfiltered);
    expect(unfiltered, hasLength(5)); // archived + deleted excluded
  });
}
