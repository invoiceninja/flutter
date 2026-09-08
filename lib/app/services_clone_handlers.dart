import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';
import 'package:admin/domain/sync/mutation.dart';

/// The five `MutationKind.cloneTo*` dispatchers, identical across the four
/// billing documents that offer cross-cloning. Spread into `wireEntity`'s
/// `customActions`.
///
/// The clone endpoint returns the **new** entity's envelope. We deliberately
/// do not apply it onto the source row — returning `null` makes the dispatcher
/// skip `applyUpdateResponse` — but we force-refetch the new record by id so
/// it appears in its own list without a manual resync.
///
/// [cloneAndReturnId] performs `POST .../clone_to_<target>` and unwraps the
/// new id. It is a closure rather than the API's `cloneTo` tear-off because
/// each API returns its own envelope type (`QuoteItemApi`, `CreditItemApi`, …)
/// and the id lives one level in, at `.data.id`; the twenty hand-copied arms
/// all spelled that unwrap out.
Map<MutationKind, CustomMutationHandler<TInner>> cloneToHandlers<TInner>({
  required Future<String?> Function({
    required String id,
    required String targetType,
    required String idempotencyKey,
  })
  cloneAndReturnId,
  required Future<void> Function(
    String companyId,
    String? newId,
    EntityType target,
  )
  refreshCloneTarget,
}) {
  CustomMutationHandler<TInner> arm(String targetType, EntityType target) =>
      ({required row, required payload}) async {
        final newId = await cloneAndReturnId(
          id: payload['id'] as String,
          targetType: targetType,
          idempotencyKey: row.idempotencyKey,
        );
        await refreshCloneTarget(row.companyId, newId, target);
        return null;
      };

  return {
    MutationKind.cloneToInvoice: arm('invoice', EntityType.invoice),
    MutationKind.cloneToQuote: arm('quote', EntityType.quote),
    MutationKind.cloneToCredit: arm('credit', EntityType.credit),
    MutationKind.cloneToRecurring: arm(
      'recurring_invoice',
      EntityType.recurringInvoice,
    ),
    MutationKind.cloneToPurchaseOrder: arm(
      'purchase_order',
      EntityType.purchaseOrder,
    ),
  };
}
