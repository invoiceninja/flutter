import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';

/// One queued `addComment` outbox row, rendered optimistically above the
/// synced feed.
///
/// Extracted from the two Activity tabs, where it was duplicated verbatim, so
/// the Comments card is not a third copy.
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.ink3,
                ),
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
          ],
        ),
      ),
    );
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
