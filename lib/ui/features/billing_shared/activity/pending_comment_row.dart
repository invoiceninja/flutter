import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/comment_row_menu.dart';

final _log = Logger('PendingCommentRow');

/// Outbox state of a row that is already on the wire.
///
/// A comment in this state is the one case the `⋯` menu must **not** offer
/// Delete. `SyncRepository.discardOutboxRow` documents it: an `in_flight` row
/// only has its outbox entry dropped, because its request may be landing
/// concurrently and ghost-deleting it would race that. Dropping the row would
/// therefore make the comment vanish from the UI while the server keeps it —
/// a lie the user cannot see, on the one surface built to fix "no way to
/// delete". Online the window is under a second; offline, where this matters,
/// the row stays `pending` the whole time.
const String _kInFlight = 'in_flight';

/// One queued `addComment` outbox row, rendered optimistically above the
/// synced feed.
///
/// Extracted from the two Activity tabs, where it was duplicated verbatim, so
/// the Comments card is not a third copy.
///
/// **This is the only row in the app that can really delete a comment**
/// (invoiceninja/flutter#123). The API has no update or delete route for an
/// activity note, so the sole undo the client owns is the outbox: while the
/// mutation is still queued, dropping its row means the note never reaches the
/// server at all. See [_kInFlight] for the one state that is excluded, and
/// BACKEND.md § F3d for the standing server ask.
class PendingCommentRow extends StatelessWidget {
  const PendingCommentRow({
    required this.row,
    this.isLast = false,
    this.horizontalPadding = 16,
    this.bodyMaxLines,
    super.key,
  });

  final OutboxRow row;
  final bool isLast;

  /// Matches [ActivityRecordRow.horizontalPadding] — see its doc for why the
  /// card overrides the default.
  final double horizontalPadding;

  /// Matches [ActivityRecordRow.bodyMaxLines].
  final int? bodyMaxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final notes = _extractNotes(row.payload);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          horizontalPadding,
          14,
          horizontalPadding,
          14,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: tokens.border),
          ),
        ),
        child: Row(
          // Centred to match [ActivityRecordRow], which centres its 28 px
          // badge. The two rows sit adjacent in the Comments card and the tab,
          // and the pending one is *replaced* by the synced one the moment the
          // note lands — so a different cross-axis here made the shared `⋯`
          // button visibly jump at exactly that moment, and further still at
          // large text scale. (This is why the spinner no longer carries the
          // `top: 2` nudge that aligned it with the first line of text.)
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.ink3,
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The same two-tier body the synced row will use — the
                  // outbox payload is the raw composed note, so printing it
                  // flat made a logged call change shape as it landed.
                  if (notes.isNotEmpty)
                    if (isCallNoteText(notes))
                      ...callNoteBody(context, notes, maxLines: bodyMaxLines)
                    else
                      Text(
                        notes,
                        style: theme.textTheme.bodyMedium,
                        maxLines: bodyMaxLines,
                        overflow: bodyMaxLines == null
                            ? null
                            : TextOverflow.ellipsis,
                      ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('in_flight'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink3,
                    ),
                  ),
                ],
              ),
            ),
            CommentRowMenu(
              // The displayed form, as on the synced row: a queued logged call
              // carries its marker in the payload.
              text: isCallNoteText(notes) ? stripCallNoteMarker(notes) : notes,
              onDelete: row.state == _kInFlight
                  ? null
                  : () => unawaited(_discard(context)),
            ),
          ],
        ),
      ),
    );
  }

  /// Drop the queued mutation so the note is never sent.
  ///
  /// Nothing is hidden optimistically: the outbox watch stream drops this row on
  /// its own, which unmounts this widget. So a success needs no toast (the row
  /// is simply gone) and cannot reach one anyway, while a failure leaves the row
  /// — and therefore this context — mounted to carry the error.
  ///
  /// Shaped exactly like `OutboxViewModel.discard`, and for the same two
  /// reasons: re-read before acting, and let the database — never the call —
  /// decide whether it worked.
  Future<void> _discard(BuildContext context) async {
    // Resolved before the first await: a `BuildContext` must not be read across
    // one, and this widget is unmounted by a successful discard.
    final services = context.read<Services>();
    final dao = services.db.outboxDao;
    try {
      // Re-read before acting. [row] is a build-time snapshot, and
      // `guardedOnTap` holds this closure across the Confirm-actions dialog —
      // long enough for a drain to claim the row. An open *menu* is safe (the
      // rebuild drops the item from `menuChildren`); the dialog is the gap, and
      // it matters because `SyncRepository.discardOutboxRow` re-reads too and
      // then deletes an `in_flight` row **anyway** — right for the Outbox
      // screen's explicit Discard, and the exact lie [_kInFlight] says this
      // surface must never tell. Bail silently: the note is on the wire and the
      // synced comment replaces this row within a second, so a toast for a
      // sub-second race is noise.
      final current = await dao.byId(row.id);
      if (current == null || current.state == _kInFlight) return;
      await services.sync.discardOutboxRow(row.id);
    } catch (e, st) {
      _log.warning('Discard failed for outbox row ${row.id}', e, st);
    }
    // The verdict comes from the database, and this **must** sit outside the
    // try above. `discardOutboxRow` deletes the row *first* and only then
    // reconciles the parent's dirty flag, so that cascade can throw after the
    // note is already unsendable — folded into one block, the throw would skip
    // this check and tell the user their comment survived when it did not.
    try {
      if (await dao.byId(row.id) == null) return;
      _log.warning('Outbox row ${row.id} is still queued after discard');
    } catch (e, st) {
      _log.warning(
        'Could not verify the discard of outbox row ${row.id}',
        e,
        st,
      );
    }
    if (!context.mounted) return;
    Notify.error(context, context.tr('an_error_occurred'));
  }

  static String _extractNotes(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['notes'] is String) {
        return decoded['notes'] as String;
      }
    } catch (_) {}
    return '';
  }
}
