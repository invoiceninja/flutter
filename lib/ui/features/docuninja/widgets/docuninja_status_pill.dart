import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// A DocuNinja document's status, as React's table badges it
/// (`useTableColumns.tsx`): deleted and archived win over the status, and
/// each status keeps React's colour family in this app's tokens.
class DocuNinjaStatusPill extends StatelessWidget {
  const DocuNinjaStatusPill({
    super.key,
    required this.document,
    this.statusOnly = false,
  });

  final DnDocument document;

  /// The status alone, never Deleted or Archived: the detail page shows
  /// those beside it in their own pill ([DocuNinjaLifecyclePill]), as
  /// React's `show/Document.tsx` does.
  final bool statusOnly;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (String key, Color fg, Color bg) = document.isDeleted && !statusOnly
        ? ('deleted', tokens.overdue, tokens.overdueSoft)
        : document.isArchived && !statusOnly
        ? ('archived', tokens.ink3, tokens.draftSoft)
        : switch (document.status) {
            DnDocumentStatus.pendingApproval => (
              'pending_approval',
              tokens.partial,
              tokens.partialSoft,
            ),
            DnDocumentStatus.approved => (
              'approved',
              tokens.paid,
              tokens.paidSoft,
            ),
            DnDocumentStatus.rejected => (
              'rejected',
              tokens.overdue,
              tokens.overdueSoft,
            ),
            DnDocumentStatus.sent => ('sent', tokens.sent, tokens.sentSoft),
            DnDocumentStatus.completed => (
              'completed',
              tokens.accent,
              tokens.accentSoft,
            ),
            DnDocumentStatus.expired => (
              'expired',
              tokens.warning,
              tokens.warningSoft,
            ),
            DnDocumentStatus.voided => (
              'voided',
              tokens.ink2,
              tokens.draftSoft,
            ),
            DnDocumentStatus.draft ||
            null => ('draft', tokens.draft, tokens.draftSoft),
          };
    return StatusPill(
      label: context.tr(key),
      fgColor: fg,
      bgColor: bg,
      textStyle: TextStyle(fontSize: 13, color: tokens.ink),
    );
  }
}

/// Deleted or Archived, or nothing: the detail page's lifecycle pill, shown
/// beside the status.
class DocuNinjaLifecyclePill extends StatelessWidget {
  const DocuNinjaLifecyclePill({super.key, required this.document});

  final DnDocument document;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (String, Color, Color)? style = document.isDeleted
        ? ('deleted', tokens.overdue, tokens.overdueSoft)
        : document.isArchived
        ? ('archived', tokens.ink3, tokens.draftSoft)
        : null;
    if (style == null) return const SizedBox.shrink();
    final (key, fg, bg) = style;
    return StatusPill(
      label: context.tr(key),
      fgColor: fg,
      bgColor: bg,
      textStyle: TextStyle(fontSize: 13, color: tokens.ink),
    );
  }
}
