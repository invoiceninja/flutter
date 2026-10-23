import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';

/// Whether the signed-in user holds [permission] (`create_vendor`, say) in the
/// current company. Admin / owner and the `*_all` expansion are handled inside
/// `AuthSession.can`; no session means no.
///
/// Read it in `build`, not `initState`: permissions are per company-user, so a
/// value captured once goes stale on a company switch.
bool sessionCan(BuildContext context, String permission) =>
    context.read<Services>().auth.session.value?.currentCompany?.can(
      permission,
    ) ??
    false;

/// Whether the signed-in user may create a [type] — [mayCreateEntity], fed
/// the inputs the router's `/new` bounce reads (`createForbiddenRoots` in
/// `main.dart`). A button that goes to a `/new` route asks this, or the router
/// bounces the tap back to the list with nothing said. No session means no.
///
/// Read it in `build`, as [sessionCan].
bool sessionMayCreate(BuildContext context, EntityType type) {
  final me = context.read<Services>().auth.session.value?.currentCompany;
  if (me == null) return false;
  return mayCreateEntity(type, can: me.can, isAdmin: me.isAdmin || me.isOwner);
}
