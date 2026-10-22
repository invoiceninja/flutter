import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';

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
