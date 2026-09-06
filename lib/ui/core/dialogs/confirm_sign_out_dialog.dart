import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// The app's gate in front of every deliberate sign-out.
///
/// Deliberately **not** gated on `services.confirmActions`, and deliberately
/// not [showConfirmActionDialog]. That helper is the *entity-action* gate, and
/// every one of its non-item callers reads the preference first (CLAUDE.md
/// § Action confirmations) — routing sign-out through it would either make it
/// the app's only ungated caller, or let a user who turned the preference off
/// wipe every company's local DB on one tap. A separate leaf makes
/// "unconditional" true by construction; it also keeps
/// `entity_detail_actions_row.dart` out of the compile graph of the screens
/// that show this.
///
/// [title] / [message] default to the sign-out copy; the two callers that
/// override them are `/too-old` (which *preserves* the local DB, so the
/// default body would be false there) and `End all sessions` (a different
/// verb with a much wider blast radius). [subject] names the account being
/// signed out — see the note in [showConfirmActionDialog] on why a prompt
/// fired from a list has to say which row it came from; pass the user's
/// email, never a company name, since sign-out is account-wide.
///
/// Returns `true` only on an explicit confirm; barrier dismiss, Escape,
/// Android back and Cancel all return `false`.
Future<bool> showConfirmSignOutDialog(
  BuildContext context, {
  String? title,
  String? message,
  String? subject,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final tokens = ctx.inTheme;
      return AlertDialog(
        title: Text(title ?? ctx.tr('sign_out_question')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message ?? ctx.tr('sign_out_warning')),
            if (subject != null && subject.trim().isNotEmpty) ...[
              SizedBox(height: InSpacing.sm),
              Text(
                subject,
                // Clamped for the same reason as the entity gate's subject:
                // `AlertDialog` gives `content` a `Flexible`, not a scroller,
                // so an unbounded line overflows in debug and clips in
                // release. An email address is routinely long.
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
            // Autofocus the SAFE action. A stray Enter, an Android "Done", or
            // the tail of a rapid double-tap must land on Cancel, never on a
            // logout that wipes every company's local DB. Same reasoning as
            // `showConfirmActionDialog` and `showDiscardChangesDialog`.
            autofocus: true,
            // Required: `theme.dart` defaults OutlinedButton to
            // `Size.fromHeight(40)` = infinite width, which makes
            // `AlertDialog.actions` silently stack via `OverflowBar`.
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            // `primary`, not `tonal`: `theme.dart`'s `filledButtonTheme` sets
            // an explicit accent background, and `FilledButton.tonal` is the
            // same widget class sharing `themeStyleOf` — which outranks M3's
            // tonal defaults. The two variants render identically here, so
            // `tonal` would name an emphasis nobody can see.
            variant: destructive
                ? DialogActionVariant.destructive
                : DialogActionVariant.primary,
            label: title ?? ctx.tr('sign_out'),
            // Never focused, never advertised — see the Cancel comment.
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
