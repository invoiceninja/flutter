import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart' show kBranchOrder;
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/entity_registry.dart' show EntityBranch;
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/permissions.dart';
import 'package:admin/domain/quick_create.dart';

/// invoiceninja/flutter#164: the dashboard's `+` opens a choice of what to
/// create. This file pins what that choice contains, in what order, and who
/// gets offered each entry. The gate runs against the real `AuthCompany.can`
/// and module mask rather than hand-written predicates, because the traps are
/// in those two: payments share the invoices module, `edit_*` never grants
/// create, and the grid's name for transactions is `bank_transaction`.
void main() {
  const everyModule = 0x7fffffff;

  AuthCompany company({
    String permissions = '',
    bool isAdmin = false,
    int enabledModules = everyModule,
  }) => AuthCompany(
    id: 'co',
    name: 'Acme',
    displayName: 'Acme',
    permissions: permissions,
    isAdmin: isAdmin,
    isOwner: false,
    enabledModules: enabledModules,
  );

  List<EntityType> offered(AuthCompany me, {Set<EntityType>? routable}) =>
      quickCreateEntities(
        hasCreateRoute: (t) => routable?.contains(t) ?? true,
        moduleOn: me.moduleEnabled,
        can: me.can,
      );

  group('kQuickCreateEntities', () {
    // The reporter asked for "quote, invoice, task, payment etc". Expense and
    // Client follow because the dashboard's own tiles offered them before this
    // menu replaced those tiles. With three columns on a phone, these six fill
    // the first two rows.
    test('leads with the most-started creates', () {
      expect(kQuickCreateEntities.take(6), const [
        EntityType.invoice,
        EntityType.quote,
        EntityType.payment,
        EntityType.task,
        EntityType.expense,
        EntityType.client,
      ]);
    });

    // Order is user-visible, so any reorder should be a deliberate edit here.
    test('is exactly this list, in this order', () {
      expect(kQuickCreateEntities, const [
        EntityType.invoice,
        EntityType.quote,
        EntityType.payment,
        EntityType.task,
        EntityType.expense,
        EntityType.client,
        EntityType.credit,
        EntityType.recurringInvoice,
        EntityType.project,
        EntityType.product,
        EntityType.vendor,
        EntityType.purchaseOrder,
        EntityType.recurringExpense,
        EntityType.transaction,
      ]);
    });

    // The shortcut catalog is the app's other list of entities that can be
    // created from anywhere. If the two disagree, an entity that gains a create
    // screen ships in one and silently not the other.
    test('offers exactly the entities the create shortcuts do', () {
      expect(kQuickCreateEntities.toSet(), kCreateShortcutEntities.toSet());
      expect(
        kQuickCreateEntities.toSet(),
        hasLength(kQuickCreateEntities.length),
        reason: 'no entity may appear twice',
      );
    });

    // The menu's own gate asks `registry[type]?.newRoute != null`, which is
    // derived from `routePath` rather than from a registered route. A
    // settings-hosted entity (bankAccount, paymentLink, …) answers that the
    // same way while its `/new` route is hand-registered in
    // `settings_routes.dart`, so an entry added here later could navigate to
    // the router's error page. Every entry being a router branch is what makes
    // that impossible: `entity_registry_completeness_test` pins that each
    // branch entity has a `createBuilder`, and `buildEntityRouteBlock` emits
    // `<routePath>/new` for each one.
    test('every entry is a router branch, so its /new route exists', () {
      final branches = {
        for (final spec in kBranchOrder)
          if (spec is EntityBranch) spec.type,
      };
      for (final type in kQuickCreateEntities) {
        expect(
          branches,
          contains(type),
          reason:
              '$type is offered in the create menu but has no branch in '
              'kBranchOrder — its /new route would not be registered',
        );
      }
    });
  });

  group('createPermissionFor', () {
    test('every entry names a token the permission grid can grant', () {
      for (final type in kQuickCreateEntities) {
        final token = createPermissionFor(type);
        expect(
          kPermissionEntities.map(
            (e) => permissionToken(verb: 'create', entity: e),
          ),
          contains(token),
          reason: '$type asks for $token, which no user can ever hold',
        );
      }
    });

    test('a transaction is a bank_transaction on the grid', () {
      expect(
        createPermissionFor(EntityType.transaction),
        'create_bank_transaction',
      );
    });

    test('camelCase entities are snake-cased', () {
      expect(
        createPermissionFor(EntityType.recurringInvoice),
        'create_recurring_invoice',
      );
      expect(
        createPermissionFor(EntityType.purchaseOrder),
        'create_purchase_order',
      );
    });
  });

  group('quickCreateLabelKey', () {
    test('every entry has an English label', () {
      final en =
          jsonDecode(File('assets/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final type in kQuickCreateEntities) {
        final value = en[quickCreateLabelKey(type)];
        expect(value, isA<String>(), reason: '$type');
        expect((value as String).trim(), isNotEmpty, reason: '$type');
      }
    });

    // An entity should read the same whether it is started from this menu, a
    // list screen's `+`, or a create shortcut.
    test('matches the create shortcut labels', () {
      for (final type in kQuickCreateEntities) {
        expect(
          quickCreateLabelKey(type),
          kShortcutCatalogById[ShortcutActionIds.create(type)]!.labelKey,
          reason: '$type',
        );
      }
    });
  });

  group('quickCreateEntities', () {
    test('an admin with every module on is offered everything', () {
      expect(offered(company(isAdmin: true)), kQuickCreateEntities);
    });

    test('create_all offers everything too', () {
      expect(offered(company(permissions: 'create_all')), kQuickCreateEntities);
    });

    test('a disabled module hides its entry', () {
      final me = company(
        isAdmin: true,
        enabledModules: everyModule & ~EnabledModule.quotes.bitmask,
      );
      expect(offered(me), isNot(contains(EntityType.quote)));
      expect(offered(me), hasLength(kQuickCreateEntities.length - 1));
    });

    // Payments have no module bit of their own. The server gates them on the
    // invoices bit (`moduleForEntityType`), so switching invoices off hides
    // both entries.
    test('payments go with the invoices module', () {
      final me = company(
        isAdmin: true,
        enabledModules: everyModule & ~EnabledModule.invoices.bitmask,
      );
      expect(
        offered(me),
        isNot(
          anyOf(contains(EntityType.invoice), contains(EntityType.payment)),
        ),
      );
    });

    test('with every module off, only the always-on entities remain', () {
      expect(offered(company(isAdmin: true, enabledModules: 0)), const [
        EntityType.client,
        EntityType.product,
      ]);
    });

    test('an entity with no create route is never offered', () {
      expect(
        offered(
          company(isAdmin: true),
          routable: {EntityType.task, EntityType.client},
        ),
        const [EntityType.task, EntityType.client],
      );
    });

    test('edit and view rights never grant create', () {
      expect(
        offered(company(permissions: 'edit_all,view_all,edit_invoice')),
        isEmpty,
      );
    });

    test('each create token offers exactly its own entity', () {
      expect(offered(company(permissions: 'create_invoice')), const [
        EntityType.invoice,
      ]);
      // Not `create_transaction`: that token does not exist.
      expect(offered(company(permissions: 'create_bank_transaction')), const [
        EntityType.transaction,
      ]);
      // `recurring_invoice` must not leak into `recurring_expense`.
      expect(offered(company(permissions: 'create_recurring_invoice')), const [
        EntityType.recurringInvoice,
      ]);
    });

    test('a user who may create nothing is offered nothing', () {
      expect(offered(company()), isEmpty);
    });
  });
}
