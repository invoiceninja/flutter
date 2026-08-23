import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// The app's generic "Are you sure?" gate, shown in front of an action the
/// user could plausibly have hit by accident.
///
/// [title] is the already-localized action label ("Approve", "Archive") and
/// doubles as the confirm button's label, so the button restates the verb
/// rather than saying a bare "OK". [subject] names *what* is about to be
/// acted on ("Acme Corp", "#0012", "12 records selected") — without it a
/// prompt fired from a long list on a phone can't tell the user which row
/// they hit, which is the whole point (invoiceninja/flutter#49).
///
/// Returns `true` only on an explicit confirm; a barrier dismiss, Escape, and
/// Cancel all return `false`.
Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? subject,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final tokens = ctx.inTheme;
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message ?? ctx.tr('are_you_sure')),
            if (subject != null && subject.trim().isNotEmpty) ...[
              SizedBox(height: InSpacing.sm),
              Text(
                subject,
                // Clamped because two callers feed this free text, not a short
                // identity: a task's subject is `task.description` (a note,
                // often several lines) and a bank transaction's is the full
                // bank memo. `AlertDialog` puts `content` in a `Flexible`, so
                // an unbounded one overflows in debug and clips in release —
                // and a ten-line record name in a confirm prompt is wrong even
                // when it fits.
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
            // Autofocus the SAFE action. This dialog exists to catch an
            // accidental activation, so a stray Enter / Android "Done" / the
            // tail of a rapid double-tap must land on Cancel, never on the
            // action being guarded. Same reasoning as
            // `showDiscardChangesDialog`.
            autofocus: true,
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            variant: destructive
                ? DialogActionVariant.destructive
                : DialogActionVariant.primary,
            label: title,
            // Never focused, never advertised — see the Cancel comment above.
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

/// The tap handler every action surface must wire into its button or menu
/// item — **never** `item.onTap` directly. Returns [EntityActionItem.onTap]
/// unchanged for an untagged action, and otherwise a wrapper that runs
/// [showConfirmActionDialog] first.
///
/// The preference is read *inside* the returned callback rather than here, so
/// (a) flipping the switch takes effect on menus that are already built, and
/// (b) building an untagged action never touches [Services] at all — which
/// keeps widget tests that pump an action row under a stub `Services` working.
VoidCallback? guardedOnTap<A>(BuildContext context, EntityActionItem<A> item) {
  final onTap = item.onTap;
  if (onTap == null || !item.confirm) return onTap;
  return () async {
    if (context.read<Services>().confirmActions.value) {
      final ok = await showConfirmActionDialog(
        context,
        title: item.label,
        message: item.confirmMessageKey == null
            ? null
            : context.tr(item.confirmMessageKey!),
        subject: item.confirmSubject,
        destructive: item.isDestructive,
      );
      if (!ok || !context.mounted) return;
    }
    onTap();
  };
}
