/// The dashboard's create menu (invoiceninja/flutter#164) — what its `+`
/// offers, in what order, and who is offered each entry.
///
/// A leaf, like `enabled_panel_kinds.dart`: the gate takes predicates rather
/// than a session, so the whole module × permission matrix is unit-testable
/// without a widget tree, and both dashboard layouts ask the same question —
/// the narrow body's `+` sheet and the wide top bar's New Invoice button.
library;

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/permissions.dart';

/// Every entity the create menu can offer, most often started first.
///
/// The head is the reporter's own list ("quote, invoice, task, payment") plus
/// the two creates the dashboard's quick-action tiles used to carry — Expense
/// and Client — so the six most-used entries fill the sheet's first two rows on
/// a phone. The rest follow in rough order of how often a user starts one.
///
/// Membership is not free to edit: it must equal `kCreateShortcutEntities`, the
/// app's other list of entities that can be created from anywhere
/// (`quick_create_test.dart` pins that), so an entity that gains a create screen
/// cannot ship in one and not the other.
const List<EntityType> kQuickCreateEntities = <EntityType>[
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
];

/// camelCase [EntityType.name] → snake_case (`recurringInvoice` →
/// `recurring_invoice`), the shape of both the `new_*` label keys and the
/// permission grid's entity names.
String _snakeName(EntityType type) => type.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

/// Localization key for the entry that starts a new [type]: `new_invoice`,
/// `new_payment` ("Enter Payment"), `new_transaction`. The same keys the list
/// screens' `+` tooltips and the shortcut catalog's create actions use, so an
/// entity reads the same wherever it is created from.
String quickCreateLabelKey(EntityType type) => 'new_${_snakeName(type)}';

/// The permission a user needs to create a [type].
///
/// `create_<entity>`, except that the permission grid names transactions
/// `bank_transaction` (`kPermissionEntities`). There is no
/// `create_transaction` token, so asking for one would hide Transactions from
/// every user who is not an admin, even one granted it explicitly.
String createPermissionFor(EntityType type) => permissionToken(
  verb: 'create',
  entity: type == EntityType.transaction
      ? 'bank_transaction'
      : _snakeName(type),
);

/// The entities the create menu offers, in [kQuickCreateEntities] order.
///
/// An entity is offered only when all three hold:
///
/// * [hasCreateRoute] — the registry wires a `/new` screen for it;
/// * [moduleOn] — its module is enabled for the company. The router bounces a
///   disabled module's routes anyway, so an entry here would be a dead end.
///   Note that payments share the invoices module;
/// * [can] grants [createPermissionFor] — the server refuses the save
///   otherwise, and edit rights never imply create.
List<EntityType> quickCreateEntities({
  required bool Function(EntityType type) hasCreateRoute,
  required bool Function(EntityType type) moduleOn,
  required bool Function(String permission) can,
}) => [
  for (final type in kQuickCreateEntities)
    if (hasCreateRoute(type) &&
        moduleOn(type) &&
        can(createPermissionFor(type)))
      type,
];
