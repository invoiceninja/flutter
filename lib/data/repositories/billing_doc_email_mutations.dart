import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/domain/sync/mutation.dart';

/// The two outbox-enqueue wrappers every billing document shares: send an
/// email now, or schedule one for later.
///
/// Mixed into Invoice / Quote / Credit / RecurringInvoice / PurchaseOrder
/// repositories, which each carried a byte-identical private copy of both
/// methods. Deliberately a mixin rather than methods on
/// [BaseEntityRepository]: only these five wire the `emailEntity` /
/// `scheduleEmail` dispatch handlers, so putting them on the base would
/// offer every repository a mutation whose drain has no handler.
///
/// `sendAt` is passed through verbatim — NOT `.toUtc()`. The server reads it
/// in the company's timezone; see the note on the list-VM bulk email action.
mixin BillingDocEmailMutations<TDomain, TApi>
    on BaseEntityRepository<TDomain, TApi> {
  Future<void> email({
    required String companyId,
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.emailEntity,
    payload: {
      'id': id,
      'template': template,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (ccEmail != null) 'cc_email': ccEmail,
    },
  );

  Future<void> scheduleEmail({
    required String companyId,
    required String id,
    required String template,
    required String sendAt,
    String? subject,
    String? body,
    String? ccEmail,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.scheduleEmail,
    payload: {
      'id': id,
      'template': template,
      'send_at': sendAt,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (ccEmail != null) 'cc_email': ccEmail,
    },
  );
}
