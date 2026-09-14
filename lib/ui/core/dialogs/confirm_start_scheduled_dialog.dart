import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// The one prompt in front of claiming a booking the user is **not** standing
/// in front of (invoiceninja/flutter#149).
///
/// Deliberately not [showConfirmActionDialog] and deliberately not gated on
/// `services.confirmActions`, for opposite reasons to
/// `confirm_sign_out_dialog.dart`'s: starting a timer is local, private and
/// reversible, so it is *not* a verb CLAUDE.md § Action confirmations would
/// tag at all — a live booking claims in one tap with Undo and never reaches
/// here. What this guards is narrower and not a preference: the server forbids
/// a running entry that precedes a future block, so claiming is the **only**
/// legal way to start, and it overwrites a booking. Two cases earn the tap:
///
///   * the booking is on a different calendar day — the user is not looking at
///     it, and Undo's few seconds are no help a week later;
///   * the booking has already passed unworked, where "late" is *inferred*
///     from the task's own due date, so a false positive would offer to
///     discard real logged work. Cancel leaves the log untouched.
///
/// Returns `true` only on an explicit confirm; barrier dismiss, Escape,
/// Android back and Cancel all return `false`.
Future<bool> showConfirmStartScheduledDialog(
  BuildContext context, {
  required String message,
  String? subject,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final tokens = ctx.inTheme;
      return AlertDialog(
        title: Text(ctx.tr('start_booked_time')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (subject != null && subject.trim().isNotEmpty) ...[
              SizedBox(height: InSpacing.sm),
              Text(
                subject,
                // Clamped for the same reason the sign-out gate clamps its
                // own: `AlertDialog` gives `content` a `Flexible`, not a
                // scroller, so an unbounded line overflows in debug and clips
                // in release — and a task description is routinely long.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton(
            // Autofocus the SAFE action: a stray Enter or the tail of a rapid
            // double-tap must not overwrite a booking. Same reasoning as
            // `showConfirmActionDialog` and `showConfirmSignOutDialog`.
            autofocus: true,
            // Required: `theme.dart` defaults OutlinedButton to
            // `Size.fromHeight(40)` = infinite width, which makes
            // `AlertDialog.actions` silently stack via `OverflowBar`.
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('start'),
            autofocus: false,
            showEnterHint: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
