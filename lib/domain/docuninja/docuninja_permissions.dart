/// DocuNinja's own permission model, as React applies it
/// (`src/common/guards/guards/docuninja/permission.ts`).
///
/// A grant is `{model, permission_id, permissionable_id}`. Only global grants
/// count (`permissionable_id` null); an admin or owner may do everything; and
/// edit or create implies view.
library;

import 'package:admin/data/models/docuninja/dn_models.dart';

/// The models DocuNinja permissions are granted on.
abstract final class DnModels {
  static const documents = 'documents';
  static const templates = 'templates';
  static const blueprints = 'blueprints';
  static const clients = 'clients';
  static const users = 'users';
  static const settings = 'settings';
}

/// What a grant allows (`permission_id`).
enum DnAction {
  view(1),
  edit(2),
  delete(3),
  create(4),
  requiresApproval(5),
  export(6),
  import(7);

  const DnAction(this.id);
  final int id;
}

/// Whether [companyUser] holding [permissions] may [action] on [model].
bool dnCan(
  DnCompanyUser companyUser,
  List<DnPermission> permissions,
  String model,
  DnAction action,
) {
  if (companyUser.isAdmin || companyUser.isOwner) return true;
  bool holds(DnAction a) => permissions.any(
    (p) =>
        p.model == model &&
        p.permissionId == a.id &&
        p.permissionableId == null,
  );
  if (holds(action)) return true;
  return action == DnAction.view &&
      (holds(DnAction.edit) || holds(DnAction.create));
}

/// React's `useDocuNinjaAdmin`: the DocuNinja role, not the Invoice Ninja one.
bool dnIsAdmin(DnCompanyUser companyUser) =>
    companyUser.isAdmin || companyUser.isOwner;
