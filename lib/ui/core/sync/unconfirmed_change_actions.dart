import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_destination.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// The three things a user can do with an `unconfirmed` outbox row — a change
/// that may already have reached the server (`OutboxState.unconfirmed`) — as
/// the Outbox screen and the edit form's banner both offer them: **Check**
/// ([checkUnconfirmedRow]), **Resend** ([resendUnconfirmedRow]) and Discard
/// (`SyncRepository.discardOutboxRow`, owned by each surface).

/// Fetch what [row] may have changed and take the user where it would show:
/// for a create, its list (the server's newest records lead it); for anything
/// else, the record, whose Activity comes from the server and says whether
/// the email went, the payment was recorded, and so on.
Future<void> checkUnconfirmedRow(BuildContext context, OutboxRow row) async {
  final services = context.read<Services>();
  await services.sync.recheck(row);
  if (!context.mounted) return;
  context.go(unconfirmedRowDestination(services, row));
}

/// Where [row]'s change would show — what Check opens: for a create, its
/// list (the server's newest records lead it); for anything else, the record.
String unconfirmedRowDestination(Services services, OutboxRow row) {
  final handlers = services.entityRegistry.byWireName(row.entityType);
  if (handlers == null) return '/sync/outbox';
  final listRoute =
      row.mutationKind == MutationKind.create.wireName &&
      handlers.routePath.isNotEmpty &&
      !_kNoListRoute.contains(handlers.type);
  return listRoute
      ? handlers.routePath
      : entityDestination(handlers: handlers, entityId: row.entityId);
}

/// Registered with a `routePath` that is not a list screen — see
/// `entityDestination`.
const Set<EntityType> _kNoListRoute = {
  EntityType.user,
  EntityType.company,
  EntityType.design,
};

/// Ask, then put [row] back in line to be sent. Always asks — not only when
/// Confirm actions is on — because this is the one tap that can do a thing
/// twice, with Cancel focused like every confirmation. Returns whether the row
/// was still `unconfirmed` and went back in line.
Future<bool> resendUnconfirmedRow(BuildContext context, OutboxRow row) async {
  final ok = await showConfirmActionDialog(
    context,
    title: context.tr('resend'),
    message: context.tr('resend_change_body'),
  );
  if (!ok || !context.mounted) return false;
  return context.read<Services>().sync.resendUnconfirmed(row.id);
}

/// On opening a record's edit form, say up front if a change to it is
/// `unconfirmed`: the next save would queue behind it and wait silently.
Future<void> hydrateUnconfirmed(
  Services services, {
  required String companyId,
  required String entityType,
  required String entityId,
  required GenericEditViewModel<dynamic> vm,
}) async {
  final row = await services.db.outboxDao.findUnconfirmedForEntity(
    companyId: companyId,
    entityType: entityType,
    entityId: entityId,
  );
  if (row == null) return;
  vm.applyUnconfirmed(
    rowId: row.id,
    isSave: isSaveMutation(row.mutationKind),
    message: row.lastError,
  );
}

/// A record's own save — the only kinds the edit form's banner acts on.
bool isSaveMutation(String wireKind) =>
    wireKind == MutationKind.create.wireName ||
    wireKind == MutationKind.update.wireName;
