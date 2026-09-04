import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_description.dart';
import 'package:admin/ui/features/billing_shared/activity/comment_row_menu.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/utils/formatting.dart';

/// Priority order for naming the **document** a note was filed against.
///
/// Two deliberate departures from the server's own `harvestNoteEntities` list:
///
/// `client` is **absent**. `ActivityController::note()` stamps `client_id`
/// alongside the document id for almost every entity, so leaving it in made a
/// comment filed on an invoice — read on that same invoice — print the client's
/// name, which is already in the header and is not the record the note was
/// filed against. On the client and vendor screens a document token always
/// matches first, so dropping it changes nothing there.
///
/// `purchase_order` and `recurring_expense` sort **before** `expense`, because
/// `note()` writes `$activity->expense_id = $entity->id` for both of them — the
/// document's own id in the expense column. The two tables have independent
/// auto-increment ids, so that frequently resolves to a real but unrelated
/// expense, and a PO comment would be labelled with its number.
const List<String> _kNoteSourceTokens = [
  'invoice',
  'quote',
  'credit',
  'payment',
  'task',
  'purchase_order',
  'recurring_invoice',
  'recurring_expense',
  'expense',
];

/// One synced activity / comment row, shared by every detail-screen Activity
/// tab, the comments-only tab, and the Comments card. Renders a tone-colored
/// icon badge, the templated + linked sentence (`buildActivitySpans`), and a
/// relative timestamp with the absolute company-formatted date+time as a
/// tooltip.
///
/// **A human-written note bypasses the sentence entirely.** `activity_141` is
/// *"User :user entered note: :notes"* and `activity_description.dart` renders
/// the whole `:notes` token in the `strong` weight — which turns a typed
/// comment into a wall of bold behind a prefix repeated on every row, and did
/// the same to a logged call's metadata header before #120 split it out. The
/// split is keyed on [Activity.isComment], not `isCallNote`: the real division
/// is "something a person wrote" versus "a templated system sentence", and
/// `isComment` already subsumes `isCallNote`. Bypassing also drops the
/// `:user` token, so the actor is re-added to the meta line — otherwise a note
/// would be the one activity row that names nobody.
///
/// A logged call keeps its two-tier body ([callNoteBody]); a typed comment
/// renders its text at body weight. That split is at the first newline with the
/// marker stripped — a **split, not a parse**. Nothing is extracted from the
/// header (a contact name may contain the separator, and the labels are frozen
/// in the author's locale), and a note with no newline renders whole.
class ActivityRecordRow extends StatefulWidget {
  const ActivityRecordRow({
    required this.activity,
    required this.formatter,
    this.isLast = false,
    this.showIp = true,
    this.horizontalPadding = 16,
    this.bodyMaxLines,
    this.hostWireName,
    super.key,
  });

  final Activity activity;
  final Formatter? formatter;

  /// Suppresses the bottom divider on the final row so the card-less, flush
  /// Activity tab doesn't end with a stray rule (mirrors the entity list
  /// tiles' `isLast`).
  ///
  /// Explicit rather than derived, because the Comments card puts a footer
  /// *below* its last row — which must therefore keep its border.
  final bool isLast;

  /// Whether the meta line carries the originating IP.
  ///
  /// `activity_feed_row.dart` already settled this split for the app: a card
  /// shows relative time, an audit lens shows the timestamp joined with the IP.
  /// The Comments card passes false; the Activity tab keeps it. On a 390 px
  /// phone at 1.4× text scale the IP is also the token that wraps the meta
  /// line to two.
  final bool showIp;

  /// Row inset. 16 suits `ActivityListCard`, which supplies no padding of its
  /// own; the Comments card zeroes its `DashboardCardShell` body padding and
  /// passes `InSpacing.lg(context)` instead so the badge column lines up with
  /// the card's title — which is **12** below 600 px, i.e. wrong-looking only
  /// on a phone.
  final double horizontalPadding;

  /// Clamps the note body. The card shows an index and hands the full text to
  /// the tab; without this one 300-word comment is taller than a phone.
  final int? bodyMaxLines;

  /// The record this row is being shown on, e.g. `'client'`.
  ///
  /// A note filed against an invoice also lands in that invoice's *client's*
  /// feed — `ActivityController::note()` copies `client_id` off the parent —
  /// so on a busy client the comments are a mixed pile with nothing saying
  /// which document each one is about. The server ships the source refs for
  /// exactly this (`Activity::harvestNoteEntities` is a type-141 special case
  /// populating `:invoice` / `:task` / … even though the template has no
  /// tokens for them); naming the first one that isn't the host is what makes
  /// them legible. Null disables the suffix.
  final String? hostWireName;

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
    _spans = null;
    // A note never paints a sentence, and this runs from
    // `didChangeDependencies` — i.e. on every theme / MediaQuery / locale
    // change. Building spans for a comments-only list would be a regex pass
    // and four span allocations per row that nothing reads.
    if (widget.activity.isComment) return;
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

  /// The record a note was filed against, when that isn't the one on screen.
  ///
  /// Returns the whole [ActivityRef] rather than its label, because two
  /// surfaces need different halves of it: the meta line prints the label, and
  /// [CommentRowMenu] turns the same ref into a `View record` item. That menu
  /// item is the *only* way this ref is reachable — the note bypass below
  /// strips the templated sentence, and with it the per-token
  /// `TapGestureRecognizer` a linked ref would need.
  ActivityRef? _sourceRef(Activity a) {
    final host = widget.hostWireName;
    if (host == null || !a.isComment) return null;
    for (final token in _kNoteSourceTokens) {
      if (token == host) continue;
      final ref = a.refs[token];
      if ((ref?.label.trim() ?? '').isNotEmpty) return ref;
    }
    return null;
  }

  /// Relative under a day, an absolute date beyond it.
  ///
  /// `formatRelativeTime` bottoms out at `2w` / `3w`, which is not an answer to
  /// "when did they promise Friday?" — and the exact stamp is a `Tooltip`,
  /// which on touch is long-press only.
  String _timestamp(Activity a, Duration elapsed) {
    if (elapsed.inHours < 24 || !a.isComment) {
      return formatRelativeTime(context, elapsed);
    }
    // `.toLocal()` first, and date-only. `Formatter.date` applies `.toLocal()`
    // only on its `showTime: true` branch — the date-only branch is a bare
    // `DateTime.tryParse`, so handing it the UTC instant renders the wrong
    // calendar day for anyone whose evening crosses the UTC boundary, and the
    // absolute tooltip two lines below (which *does* localize) would then
    // disagree with this label on the same row. `EntityDetailHeader._format`
    // documents the same trap.
    return widget.formatter?.date(
          a.createdAt.toLocal().toIso8601String().split('T').first,
        ) ??
        formatRelativeTime(context, elapsed);
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

    final elapsed = DateTime.now().difference(a.createdAt);
    final absolute =
        widget.formatter?.date(
          a.createdAt.toIso8601String(),
          showTime: true,
          showSeconds: false,
        ) ??
        a.createdAt.toIso8601String();
    // `refs['user']` and nothing else: `harvestNoteEntities` carries no
    // `contact`, `activity_141` has no `:contact` token, and `note()` always
    // stamps `user_id` from the admin guard — so no portal contact can author
    // one. The server's own `matchVar(':user')` falls back to a localized
    // "System", so this is effectively always populated.
    final actor = a.isComment ? (a.userLabel ?? '').trim() : '';
    final sourceRef = _sourceRef(a);
    final source = sourceRef?.label.trim() ?? '';
    final meta = [
      if (actor.isNotEmpty) actor,
      _timestamp(a, elapsed),
      if (source.isNotEmpty) source,
      if (widget.showIp && a.ip.isNotEmpty) a.ip,
    ].join(' · ');

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.isCallNote)
          ...callNoteBody(context, a.notes, maxLines: widget.bodyMaxLines)
        else if (a.isComment)
          _CommentBody(notes: a.notes, maxLines: widget.bodyMaxLines)
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
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
          ),
        ),
      ],
    );

    // Merged only for a note, and merged around the **text column only**. A
    // templated sentence carries a `TapGestureRecognizer` per linked token, and
    // `SemanticsConfiguration` absorbs descendant actions into a single one —
    // so merging there would leave a screen reader one tap for a row that has
    // two or three destinations. A note has no links by construction (the
    // bypass above never builds spans), so the merge is pure gain: one stop
    // instead of two. It must not reach as far as the row, though — the `⋯`
    // menu is a descendant, and a merge over it would announce the button but
    // swallow its tap action, exactly the failure this comment describes for
    // the recognizers. The badge stays outside too, harmlessly: it is a bare
    // `Icon` with no semantics label.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
        child: Container(
          padding: EdgeInsetsDirectional.fromSTEB(
            widget.horizontalPadding,
            14,
            widget.horizontalPadding,
            14,
          ),
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
              Expanded(child: a.isComment ? MergeSemantics(child: body) : body),
              // Comment rows only. A templated system sentence has nothing to
              // copy and nothing to delete, and a menu on every row would put a
              // `⋯` beside a hundred audit lines to reach two notes. The
              // ragged right edge that leaves in the Activity tab is the same
              // trade the narrow list rows make for the call button
              // (invoiceninja/flutter#111): mount nothing rather than reserve
              // width for an affordance that would be dead.
              if (a.isComment)
                CommentRowMenu(
                  // What the row displays, not the wire form — a logged
                  // call's marker is stripped above and must be stripped here
                  // too, or Copy yields a leading marker glyph nobody typed.
                  text: a.isCallNote ? stripCallNoteMarker(a.notes) : a.notes,
                  source: sourceRef,
                  // No `onDelete`: a synced note is immutable server-side. See
                  // [CommentRowMenu] and BACKEND.md § F3d.
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A typed comment's text — body weight, no template, no prefix.
class _CommentBody extends StatelessWidget {
  const _CommentBody({required this.notes, this.maxLines});

  final String notes;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final text = notes.trim();
    // A note written from React or the API need not be non-empty — only this
    // client trims and gates on it — and an empty row would read as broken.
    if (text.isEmpty) {
      return Text(
        context.tr('comment'),
        style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink3),
      );
    }
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
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
List<Widget> callNoteBody(BuildContext context, String notes, {int? maxLines}) {
  final theme = Theme.of(context);
  final tokens = context.inTheme;
  final text = stripCallNoteMarker(notes).trim();
  final split = text.indexOf('\n');
  // No newline: the author's own text is all there is, so render it as the
  // summary rather than demoting it to a header nobody wrote.
  final header = split < 0 ? '' : text.substring(0, split).trim();
  final summary = split < 0 ? text : text.substring(split + 1).trim();
  final label = context.tr('log_call');
  // The header costs one of the clamped lines, so the summary gets the rest.
  final summaryMaxLines = maxLines == null
      ? null
      : (header.isEmpty
            ? maxLines
            : (maxLines - 1).clamp(1, maxLines < 1 ? 1 : maxLines));
  return [
    if (header.isNotEmpty) ...[
      Text(
        header,
        style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 2),
    ],
    Text(
      summary.isEmpty ? label : summary,
      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
      maxLines: summaryMaxLines,
      overflow: summaryMaxLines == null ? null : TextOverflow.ellipsis,
    ),
  ];
}
