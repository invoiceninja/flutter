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
/// `promptLogCallFor` needs a `subject` and the record's party id, neither of
/// which exists until the scaffold has resolved the record. It is re-created on
/// every one of those builds — harmless, since nothing compares it; give it
/// `==`/`hashCode` if that ever changes.
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
/// Each button is **latched while its own callback is in flight**, and that is
/// not cosmetic. `promptLogCallFor` resolves the record's party from Drift
/// before it opens anything (invoiceninja/flutter#129), so unlike
/// `promptAddCommentFor` — whose `showAddCommentDialog` pushes with no
/// preceding await — the modal barrier no longer goes up inside the tapping
/// frame. Left live, a second tap during that window stacks a second sheet,
/// each with its own `runMutationWithNotify(submit)`: the user posts the same
/// call note twice, or fills the top sheet and finds a blank one underneath.
/// `_PhoneCallButtonState._busy` is the same guard for the same reason ("a
/// double-tap fires two launches"), and the `⋯` arms need none because the menu
/// closes on selection.
///
/// Both buttons take it, not just Log call: Add comment's window is one
/// microtask today, but the shape is identical and one rule is easier to keep
/// than two. Disabling is also the only feedback either button gives — before
/// this, a slow party lookup left Log call looking simply dead.
class ActivityNoteButtons extends StatefulWidget {
  const ActivityNoteButtons({super.key, required this.actions});

  final EntityNoteActions actions;

  @override
  State<ActivityNoteButtons> createState() => _ActivityNoteButtonsState();
}

class _ActivityNoteButtonsState extends State<ActivityNoteButtons> {
  bool _loggingCall = false;
  bool _addingComment = false;

  /// Runs [action] with [busy] latched.
  ///
  /// The release is in a `finally`, not after the `await`: a lookup that throws
  /// would otherwise strand the button disabled for the life of the screen —
  /// worse than the double-open this exists to stop. It is guarded on `mounted`
  /// because the callback awaits a route and the host tab can be disposed while
  /// that route is up. The error itself is left to propagate, exactly as it did
  /// before this latch existed (`_PhoneCallButtonState._onTap` has the same
  /// shape); nothing here is a substitute for the callbacks' own error
  /// handling, which `runMutationWithNotify` and `_resolveParty` already own.
  Future<void> _run(
    Future<void> Function() action, {
    required bool Function() busy,
    required void Function(bool) setBusy,
  }) async {
    if (busy()) return;
    setState(() => setBusy(true));
    try {
      await action();
    } finally {
      if (mounted) setState(() => setBusy(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
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
            onPressed: _loggingCall
                ? null
                : () => _run(
                    onLogCall,
                    busy: () => _loggingCall,
                    setBusy: (v) => _loggingCall = v,
                  ),
            icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
            label: Text(context.tr('log_call')),
          ),
        if (onAddComment != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: _addingComment
                ? null
                : () => _run(
                    onAddComment,
                    busy: () => _addingComment,
                    setBusy: (v) => _addingComment = v,
                  ),
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            label: Text(context.tr('add_comment')),
          ),
      ],
    );
  }
}
