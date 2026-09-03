import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// The two "write a note onto this record" callbacks, as one value.
///
/// Built once per detail screen and handed to every surface that can start one
/// — the Activity tab's button pair, the comments-only tab's empty state, and
/// the Comments card's footer. Before this each surface closed over its own
/// copy of the same `promptAddCommentFor` / `promptLogCallFor` call, which is
/// how the tab and the `⋯` menu drifted apart the first time (see
/// `activity_note_actions.dart`).
///
/// **Build it inside the host's `bodyBuilder`, not `initState`**:
/// `promptLogCallFor` needs a `subject` and phone `candidates` derived from the
/// resolved record, which don't exist until the scaffold has one. It is
/// re-created on every one of those builds — harmless, since nothing compares
/// it; give it `==`/`hashCode` if that ever changes.
class EntityNoteActions {
  const EntityNoteActions({this.onAddComment, this.onLogCall});

  final Future<void> Function()? onAddComment;
  final Future<void> Function()? onLogCall;

  bool get hasAny => onAddComment != null || onLogCall != null;

  /// For an entity whose repository has no `addComment` — Task and Project.
  ///
  /// Use this constant rather than `EntityNoteActions(onAddComment: null, …)`:
  /// `test/lint/call_note_wiring_test.dart` asserts those two screens contain
  /// no `onAddComment:` at all, so spelling the null out reds the build.
  static const EntityNoteActions none = EntityNoteActions();
}

/// The `Log call` / `Add comment` pair that heads every Activity tab and every
/// comments-only tab.
///
/// Shared rather than copied so the surfaces cannot drift — they were an
/// identical pair down to the comment, and only one of them had a layout test.
///
/// A `Wrap`, not a `Row`: two labelled buttons overflow a narrow phone at
/// `kTextScaleMax`. The explicit `minimumSize` on each is load-bearing once
/// they share a line — the button theme defaults to `Size.fromHeight(44)`,
/// i.e. infinite width, which in a horizontal context collapses the layout.
///
/// Either callback may be null (Task and Project mount an Activity tab but
/// have no `addComment` on their repositories); both null renders nothing.
///
/// The **Comments card** deliberately does not use this — it shows a single
/// `Add comment` instead. Three homes for `Log call` within two screens is one
/// too many, and the pair costs a second `Wrap` run at large text scale on a
/// card whose whole design is about staying short.
class ActivityNoteButtons extends StatelessWidget {
  const ActivityNoteButtons({super.key, required this.actions});

  final EntityNoteActions actions;

  @override
  Widget build(BuildContext context) {
    if (!actions.hasAny) return const SizedBox.shrink();
    final onLogCall = actions.onLogCall;
    final onAddComment = actions.onAddComment;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      children: [
        if (onLogCall != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onLogCall,
            icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
            label: Text(context.tr('log_call')),
          ),
        if (onAddComment != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onAddComment,
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            label: Text(context.tr('add_comment')),
          ),
      ],
    );
  }
}
