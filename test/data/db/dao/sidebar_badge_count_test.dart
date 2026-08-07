import 'package:drift/drift.dart' show Expression, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// The counts behind the sidebar badges (issue #9). Two things are being
/// guarded here: that each declared mode actually narrows to the right rows,
/// and that a mode declared in the catalog has a query behind it at all — a
/// missing predicate degrades silently to "count everything", which reads as a
/// working feature.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const co = 'co';
  final yesterday = Date.today().addDays(-1).toIso();
  final tomorrow = Date.today().addDays(1).toIso();

  Future<void> invoice(
    String id, {
    String status = '2',
    String balance = '10',
    String? dueDate,
    String? partialDueDate,
    String clientId = '',
    String assignedUserId = '',
    int? archivedAt,
    bool deleted = false,
  }) => db.invoiceDao.upsert(
    InvoicesCompanion.insert(
      id: id,
      companyId: co,
      updatedAt: 1,
      payload: '{}',
      statusId: Value(status),
      balance: Value(balance),
      dueDate: Value(dueDate ?? ''),
      partialDueDate: Value(partialDueDate ?? ''),
      clientId: Value(clientId),
      assignedUserId: Value(assignedUserId),
      archivedAt: Value(archivedAt),
      isDeleted: Value(deleted),
    ),
  );

  group('base filter', () {
    test(
      'total counts active rows only — archived rows inflated the badge past '
      'what the list underneath it shows',
      () async {
        await invoice('live');
        await invoice('archived', archivedAt: 123);
        await invoice('deleted', deleted: true);
        expect(
          await db.invoiceDao.watchBadgeCount(companyId: co).first,
          1,
          reason: 'only the active row counts',
        );
        expect(
          await db.invoiceDao.watchCount(companyId: co).first,
          2,
          reason: 'watchCount keeps its long-standing archived-inclusive shape',
        );
      },
    );

    test('the hidden mode short-circuits to zero', () async {
      await invoice('live');
      expect(
        await db.invoiceDao
            .watchBadgeCount(companyId: co, modeId: kBadgeModeNone)
            .first,
        0,
      );
    });
  });

  group('invoice modes', () {
    test('overdue mirrors Invoice.isPastDue', () async {
      await invoice('past-due', dueDate: yesterday);
      await invoice('due-later', dueDate: tomorrow);
      await invoice('paid-but-late', status: '4', dueDate: yesterday);
      await invoice('draft-but-late', status: '1', dueDate: yesterday);
      await invoice('settled', balance: '0', dueDate: yesterday);
      // partial_due_date wins over due_date, same as the getter.
      await invoice(
        'partial-late',
        status: '3',
        dueDate: tomorrow,
        partialDueDate: yesterday,
      );
      expect(
        await db.invoiceDao
            .watchBadgeCount(companyId: co, modeId: 'overdue')
            .first,
        2,
      );
    });

    test(
      'an invoice with no due date is never overdue — SQLite ranks the empty '
      'string below every date, so a missing NULLIF counts every one of them',
      () async {
        await invoice('no-dates');
        await invoice('past-due', dueDate: yesterday);
        expect(
          await db.invoiceDao
              .watchBadgeCount(companyId: co, modeId: 'overdue')
              .first,
          1,
        );
      },
    );

    test('unpaid is sent + partial, matching the server', () async {
      await invoice('sent', status: '2');
      await invoice('partial', status: '3');
      await invoice('draft', status: '1');
      await invoice('paid', status: '4');
      expect(
        await db.invoiceDao
            .watchBadgeCount(companyId: co, modeId: 'unpaid')
            .first,
        2,
      );
      expect(
        await db.invoiceDao
            .watchBadgeCount(companyId: co, modeId: 'draft')
            .first,
        1,
      );
    });
  });

  group('assigned_to_me', () {
    test('counts the signed-in user\'s rows', () async {
      await invoice('mine', assignedUserId: 'u1');
      await invoice('theirs', assignedUserId: 'u2');
      await invoice('unassigned');
      expect(
        await db.invoiceDao
            .watchBadgeCount(
              companyId: co,
              modeId: kBadgeModeAssignedToMe,
              currentUserId: 'u1',
            )
            .first,
        1,
      );
    });

    test(
      'an empty user id counts NOTHING, not everything — a logged-out or '
      'mid-switch session must not report the whole company as yours',
      () async {
        await invoice('mine', assignedUserId: 'u1');
        await invoice('unassigned');
        expect(
          await db.invoiceDao
              .watchBadgeCount(
                companyId: co,
                modeId: kBadgeModeAssignedToMe,
                currentUserId: '',
              )
              .first,
          0,
        );
      },
    );

    test('tasks read the assignee out of the payload (no column)', () async {
      await db.taskDao.upsert(
        TasksCompanion.insert(
          id: 'mine',
          companyId: co,
          updatedAt: 1,
          payload: '{"assigned_user_id":"u1"}',
        ),
      );
      await db.taskDao.upsert(
        TasksCompanion.insert(
          id: 'theirs',
          companyId: co,
          updatedAt: 2,
          payload: '{"assigned_user_id":"u2"}',
        ),
      );
      expect(
        await db.taskDao
            .watchBadgeCount(
              companyId: co,
              modeId: kBadgeModeAssignedToMe,
              currentUserId: 'u1',
            )
            .first,
        1,
      );
    });
  });

  group('cross-entity counters', () {
    test(
      'clients/overdue counts clients, and stays live when the invoice '
      'changes — that reactivity is the whole reason it is a subquery',
      () async {
        await db.clientDao.upsert(
          ClientsCompanion.insert(
            id: 'c1',
            companyId: co,
            name: 'Late Co',
            number: '1',
            email: '',
            displayName: 'Late Co',
            balance: '0',
            updatedAt: 1,
            payload: '{}',
          ),
        );
        await db.clientDao.upsert(
          ClientsCompanion.insert(
            id: 'c2',
            companyId: co,
            name: 'Fine Co',
            number: '2',
            email: '',
            displayName: 'Fine Co',
            balance: '0',
            updatedAt: 1,
            payload: '{}',
          ),
        );
        // Two overdue invoices for one client still count that client once.
        await invoice('i1', clientId: 'c1', dueDate: yesterday);
        await invoice('i2', clientId: 'c1', dueDate: yesterday);
        await invoice('i3', clientId: 'c2', dueDate: tomorrow);

        final counts = db.clientDao.watchBadgeCount(
          companyId: co,
          modeId: 'overdue',
        );
        expect(await counts.first, 1);

        // Settling the invoices drops the client out of the count.
        await invoice('i1', clientId: 'c1', balance: '0', dueDate: yesterday);
        await invoice('i2', clientId: 'c1', balance: '0', dueDate: yesterday);
        expect(await counts.first, 0);
      },
    );

    test('vendors/unpaid_expenses counts vendors, not expenses', () async {
      for (final id in ['v1', 'v2']) {
        await db.vendorDao.upsert(
          VendorsCompanion.insert(
            id: id,
            companyId: co,
            name: id,
            number: id,
            idNumber: '',
            vatNumber: '',
            city: '',
            countryId: '',
            currencyId: '',
            phone: '',
            displayName: id,
            updatedAt: 1,
            payload: '{}',
          ),
        );
      }
      Future<void> expense(String id, String vendorId, {required bool paid}) =>
          db.expenseDao.upsert(
            ExpensesCompanion.insert(
              id: id,
              companyId: co,
              updatedAt: 1,
              payload: '{}',
              vendorId: Value(vendorId),
              isPaid: Value(paid),
            ),
          );
      await expense('e1', 'v1', paid: false);
      await expense('e2', 'v1', paid: false);
      await expense('e3', 'v2', paid: true);

      final counts = db.vendorDao.watchBadgeCount(
        companyId: co,
        modeId: 'unpaid_expenses',
      );
      expect(await counts.first, 1, reason: 'two expenses, one vendor');

      await expense('e1', 'v1', paid: true);
      await expense('e2', 'v1', paid: true);
      expect(await counts.first, 0);
    });
  });

  group('product stock counters', () {
    Future<void> product(String id, {num qty = 0, num threshold = 0}) =>
        db.productDao.upsert(
          ProductsCompanion.insert(
            id: id,
            companyId: co,
            productKey: id,
            notes: '',
            price: '0',
            cost: '0',
            quantity: '1',
            updatedAt: 1,
            payload:
                '{"in_stock_quantity":$qty,'
                '"stock_notification_threshold":$threshold}',
          ),
        );

    Future<void> company({required bool trackInventory, int threshold = 0}) =>
        db.companiesDao.upsertAll([
          CompaniesCompanion.insert(
            id: co,
            name: 'Co',
            settings: '{}',
            permissions: '{}',
            accountId: 'a',
            token: 't',
            updatedAt: 1,
            trackInventory: Value(trackInventory),
            inventoryNotificationThreshold: Value(threshold),
          ),
        ]);

    test(
      'both counters read zero when inventory tracking is off — otherwise '
      'every product looks out of stock, since the payload key is absent',
      () async {
        await company(trackInventory: false);
        await product('p1', qty: 0);
        await product('p2', qty: 5);
        expect(
          await db.productDao
              .watchBadgeCount(companyId: co, modeId: 'out_of_stock')
              .first,
          0,
        );
        expect(
          await db.productDao
              .watchBadgeCount(companyId: co, modeId: 'low_stock')
              .first,
          0,
        );
      },
    );

    test(
      'low_stock follows the product-then-company threshold cascade',
      () async {
        await company(trackInventory: true, threshold: 3);
        await product('own-threshold', qty: 8, threshold: 10); // own wins → low
        await product('company-threshold', qty: 2); // falls back to 3 → low
        await product('healthy', qty: 50);
        await product('out', qty: 0); // out wins over low
        expect(
          await db.productDao
              .watchBadgeCount(companyId: co, modeId: 'low_stock')
              .first,
          2,
        );
        expect(
          await db.productDao
              .watchBadgeCount(companyId: co, modeId: 'out_of_stock')
              .first,
          1,
        );
      },
    );

    test(
      'the counters recompute when Product Settings changes — the company '
      'values are subqueries, so drift keeps the stream reading that table',
      () async {
        await company(trackInventory: true, threshold: 0);
        await product('p1', qty: 2);
        final counts = db.productDao.watchBadgeCount(
          companyId: co,
          modeId: 'low_stock',
        );
        expect(await counts.first, 0, reason: 'no threshold set anywhere yet');

        await company(trackInventory: true, threshold: 5);
        expect(await counts.first, 1);
      },
    );
  });

  group('catalog coherence', () {
    // The backstop for the whole feature: `badgeModePredicate` returning null
    // makes a mode count every row, which looks like a working badge showing a
    // suspiciously round number. Every declared mode must resolve to a query.
    test(
      'every declared mode resolves to a predicate, and that predicate runs',
      () async {
        // `(modes, predicate, count)` per entity. The predicate check is the
        // real guard — a null means the mode counts every row, which looks
        // exactly like a working badge. The count call then proves the SQL is
        // valid (a predicate naming a column the table lacks throws here).
        final byType =
            <
              EntityType,
              (
                List<SidebarBadgeMode>,
                Expression<bool>? Function(String),
                Stream<int> Function({
                  required String companyId,
                  String modeId,
                  String currentUserId,
                }),
              )
            >{
              EntityType.client: (
                kClientBadgeModes,
                (m) => db.clientDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.clientDao.watchBadgeCount,
              ),
              EntityType.product: (
                kProductBadgeModes,
                (m) => db.productDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.productDao.watchBadgeCount,
              ),
              EntityType.invoice: (
                kInvoiceBadgeModes,
                (m) => db.invoiceDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.invoiceDao.watchBadgeCount,
              ),
              EntityType.recurringInvoice: (
                kRecurringInvoiceBadgeModes,
                (m) => db.recurringInvoiceDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.recurringInvoiceDao.watchBadgeCount,
              ),
              EntityType.payment: (
                kPaymentBadgeModes,
                (m) => db.paymentDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.paymentDao.watchBadgeCount,
              ),
              EntityType.quote: (
                kQuoteBadgeModes,
                (m) => db.quoteDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.quoteDao.watchBadgeCount,
              ),
              EntityType.credit: (
                kCreditBadgeModes,
                (m) => db.creditDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.creditDao.watchBadgeCount,
              ),
              EntityType.project: (
                kProjectBadgeModes,
                (m) => db.projectDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.projectDao.watchBadgeCount,
              ),
              EntityType.task: (
                kTaskBadgeModes,
                (m) => db.taskDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.taskDao.watchBadgeCount,
              ),
              EntityType.vendor: (
                kVendorBadgeModes,
                (m) => db.vendorDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.vendorDao.watchBadgeCount,
              ),
              EntityType.purchaseOrder: (
                kPurchaseOrderBadgeModes,
                (m) => db.purchaseOrderDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.purchaseOrderDao.watchBadgeCount,
              ),
              EntityType.expense: (
                kExpenseBadgeModes,
                (m) => db.expenseDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.expenseDao.watchBadgeCount,
              ),
              EntityType.recurringExpense: (
                kRecurringExpenseBadgeModes,
                (m) => db.recurringExpenseDao.badgeModePredicate(
                  m,
                  companyId: co,
                  currentUserId: 'u1',
                ),
                db.recurringExpenseDao.watchBadgeCount,
              ),
              EntityType.transaction: (
                kTransactionBadgeModes,
                db.bankTransactionDao.badgeModePredicate,
                db.bankTransactionDao.watchBadgeCount,
              ),
            };

        expect(
          byType.length,
          kAllSidebarBadgeModeLists.length,
          reason: 'a new per-entity mode list needs an entry here too',
        );

        for (final entry in byType.entries) {
          final (modes, predicateFor, watch) = entry.value;
          for (final mode in modes) {
            if (mode.id == kBadgeModeTotal || mode.id == kBadgeModeNone) {
              continue;
            }
            expect(
              predicateFor(mode.id),
              isNotNull,
              reason:
                  '${entry.key.name} declares "${mode.id}" but its DAO has no '
                  'case for it — the badge would silently count every row.',
            );
            await expectLater(
              watch(companyId: co, modeId: mode.id, currentUserId: 'u1').first,
              completion(0),
              reason: '${entry.key.name} / ${mode.id}',
            );
          }
        }
      },
    );

    test('every catalog mode id appears in kSidebarBadgeModeIds', () {
      for (final list in kAllSidebarBadgeModeLists) {
        for (final mode in list) {
          expect(kSidebarBadgeModeIds, contains(mode.id));
        }
      }
    });

    test('every settings-search key is a real mode label — a subset, not the '
        'union: the generic status words are excluded on purpose so the empty '
        'query in settings search is not padded with one-word rows', () {
      final union = <String>{
        for (final list in kAllSidebarBadgeModeLists)
          for (final mode in list) mode.labelKey,
      };
      expect(kSidebarBadgeModeSearchKeys.toSet(), isNotEmpty);
      for (final key in kSidebarBadgeModeSearchKeys) {
        expect(
          union,
          contains(key),
          reason:
              '"$key" is exported to settings search but is no longer any '
              'mode\'s labelKey — search would surface a dead entry.',
        );
      }
      expect(
        kSidebarBadgeModeSearchKeys.length,
        kSidebarBadgeModeSearchKeys.toSet().length,
        reason: 'no duplicates',
      );
    });
  });
}
