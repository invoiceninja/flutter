import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_description.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/utils/formatting.dart';

/// One synced activity / comment row, shared by every detail-screen Activity
/// tab. Renders a tone-colored icon badge, the templated + linked sentence
/// (`buildActivitySpans`), and a relative timestamp with the absolute
/// company-formatted date+time as a tooltip.
///
/// A **logged call** (invoiceninja/flutter#120) gets its own two-tier body
/// instead of the shared sentence. `activity_description.dart` renders the
/// whole `:notes` token in the `strong` weight, which is fine for the one-line
/// comment it was written for but turns a call's metadata header *and* its
/// summary into a wall of bold — burying the thing the user actually wrote.
/// Here the header is dimmed to `bodySmall`/`ink3` and the summary keeps the
/// body style, so the eye lands on what was said.
///
/// That split is at the first newline with the marker stripped — a **split, not
/// a parse**. Nothing is extracted from the header (a contact name may contain
/// the separator, and the labels are frozen in the author's locale), and a note
/// with no newline simply renders whole. Bypassing `buildActivitySpans` also
/// drops its "User :user entered note:" prefix, so the actor is re-added to the
/// meta line — otherwise a call would be the one activity row that names nobody.
class ActivityRecordRow extends StatefulWidget {
  const ActivityRecordRow({
    required this.activity,
    required this.formatter,
    this.isLast = false,
    super.key,
  });

  final Activity activity;
  final Formatter? formatter;

  /// Suppresses the bottom divider on the final row so the card-less,
  /// flush Activity tab doesn't end with a stray rule (mirrors the entity
  /// list tiles' `isLast`).
  final bool isLast;

  @override
  State<ActivityRecordRow> createState() => _ActivityRecordRowState();
}

class _ActivityRecordRowState extends State<ActivityRecordRow> {
  ActivitySpans? _spans;
  bool _hovered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(ActivityRecordRow old) {
    super.didUpdateWidget(old);
    if (old.activity != widget.activity) _rebuildSpans();
  }

  void _rebuildSpans() {
    _spans?.dispose();
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final body = theme.textTheme.bodyMedium ?? const TextStyle();
    _spans = buildActivitySpans(
      context,
      widget.activity,
      base: body.copyWith(color: tokens.ink),
      strong: body.copyWith(fontWeight: FontWeight.w600, color: tokens.ink),
      link: body.copyWith(fontWeight: FontWeight.w600, color: tokens.accent),
    );
  }

  @override
  void dispose() {
    _spans?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final a = widget.activity;
    final tone = activityToneFor(a.activityTypeId);
    final (bg, fg) = activityToneColors(tokens, tone);
    final icon = a.isCallNote
        ? Icons.phone_in_talk_outlined
        : (a.isComment ? Icons.comment_outlined : activityIconFor(tone));

    final relative = formatRelativeTime(
      context,
      DateTime.now().difference(a.createdAt),
    );
    final absolute =
        widget.formatter?.date(
          a.createdAt.toIso8601String(),
          showTime: true,
          showSeconds: false,
        ) ??
        a.createdAt.toIso8601String();
    final actor = a.isCallNote ? (a.userLabel ?? '').trim() : '';
    final meta = [
      if (actor.isNotEmpty) actor,
      relative,
      if (a.ip.isNotEmpty) a.ip,
    ].join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: _hovered ? tokens.surfaceAlt : null,
            border: Border(
              bottom: widget.isLast
                  ? BorderSide.none
                  : BorderSide(color: tokens.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(InRadii.r2),
                ),
                child: Icon(icon, size: 16, color: fg),
              ),
              SizedBox(width: InSpacing.md(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.isCallNote)
                      ...callNoteBody(context, a.notes)
                    else
                      Text.rich(
                        TextSpan(children: _spans?.spans ?? const []),
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: absolute,
                      child: Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header line (dimmed) over summary (body) for a logged call.
///
/// Public so the optimistic "Syncing…" rows can render a queued call the same
/// way the synced one will: they read the outbox payload, which is the raw
/// composed note, and printing that flat meant a logged call visibly changed
/// shape the moment it landed.
///
/// See [ActivityRecordRow] for why this bypasses `buildActivitySpans`.
List<Widget> callNoteBody(BuildContext context, String notes) {
  final theme = Theme.of(context);
  final tokens = context.inTheme;
  final text = stripCallNoteMarker(notes).trim();
  final split = text.indexOf('\n');
  // No newline: the author's own text is all there is, so render it as the
  // summary rather than demoting it to a header nobody wrote.
  final header = split < 0 ? '' : text.substring(0, split).trim();
  final summary = split < 0 ? text : text.substring(split + 1).trim();
  final label = context.tr('log_call');
  return [
    if (header.isNotEmpty) ...[
      Text(
        header,
        style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
      ),
      const SizedBox(height: 2),
    ],
    Text(
      summary.isEmpty ? label : summary,
      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
    ),
  ];
}
