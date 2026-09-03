import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// The `Log call` / `Add comment` pair that heads every Activity tab.
///
/// Shared rather than copied so the two tabs cannot drift — they were an
/// identical pair down to the comment, and only one of them had a layout test.
///
/// A `Wrap`, not a `Row`: two labelled buttons overflow a narrow phone at
/// `kTextScaleMax`. The explicit `minimumSize` on each is load-bearing once
/// they share a line — the button theme defaults to `Size.fromHeight(44)`,
/// i.e. infinite width, which in a horizontal context collapses the layout.
///
/// Either callback may be null (Task and Project mount an Activity tab but
/// have no `addComment` on their repositories); both null renders nothing.
class ActivityNoteButtons extends StatelessWidget {
  const ActivityNoteButtons({super.key, this.onLogCall, this.onAddComment});

  final Future<void> Function()? onLogCall;
  final Future<void> Function()? onAddComment;

  bool get hasAny => onLogCall != null || onAddComment != null;

  @override
  Widget build(BuildContext context) {
    if (!hasAny) return const SizedBox.shrink();
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
