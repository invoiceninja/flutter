import 'package:flutter/widgets.dart';

import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';

/// Whether this account may attach documents at all
/// (`AuthSession.canAttachDocuments` — Enterprise on hosted, trial-aware;
/// always on for self-hosted). The one UI read of that rule, for every
/// Documents surface: a record screen's tab, a create form's card, the
/// unsynced record's save-first notice.
///
/// Read defensively: many widget tests pump these surfaces with no
/// `Services`, or with a fake whose unimplemented members throw, and no
/// session means no gate.
bool attachmentsAllowed(BuildContext context) {
  try {
    final session = context.read<Services?>()?.auth.session.value;
    return session?.canAttachDocuments ?? true;
  } catch (_) {
    return true;
  }
}
