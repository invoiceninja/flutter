import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// The app-wide "this row has a local edit still sitting in the outbox" cue.
///
/// One widget so the label, tooltip and `sent`/`sentSoft` token pair can't
/// drift between the entity detail header and the ~11 list rows that show it.
/// Without it a rejected save is invisible: the optimistic Drift row renders
/// exactly like a saved one, which is how a schedule the server had refused
/// still appeared under Settings → Schedules (invoiceninja/flutter#43).
///
/// Sizing note for callers: this is wider than the bare chevron / drag handle
/// it sits beside (~76 px at 1.0 text scale). `ListTile` divides its width
/// between title and trailing via `BoxConstraints.tighten`, which **clamps a
/// negative title width to zero instead of throwing** — so an over-full
/// trailing row silently erases the title rather than surfacing an overflow.
/// Add this to a trailing slot only where the row has budget for it; where it
/// doesn't, let this pill *replace* the row's other state cue.
class UnsyncedPill extends StatelessWidget {
  const UnsyncedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return StatusPill(
      label: context.tr('unsynced'),
      fgColor: tokens.sent,
      bgColor: tokens.sentSoft,
      tooltip: context.tr('unsynced_pending_outbox_tooltip'),
    );
  }
}
