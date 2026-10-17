import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/document_parent_label.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// "Details" on the document record: what it is attached to, what kind of
/// file it is, who uploaded it and when. A row with nothing to say is left
/// out entirely (a detail screen never dashes a blank row).
class DocumentDetailProfile extends StatelessWidget {
  const DocumentDetailProfile({
    super.key,
    required this.document,
    this.formatter,
  });

  final DocumentRecord document;

  /// For the created / updated dates. Null (still loading) leaves them out.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final d = document;
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) =>
        formatter == null || dt.millisecondsSinceEpoch == 0
        ? null
        : formatter!.date(dt.toLocal().toIso8601String().split('T').first);
    final created = day(d.createdAt);
    final updated = day(d.updatedAt);
    final dims = d.dimensions;
    final rows = <Widget>[
      if (d.parentType != null && (d.parentId ?? '').isNotEmpty)
        DetailInfoRow(
          label: context.tr('linked_to'),
          value: '',
          copyable: false,
          child: DocumentParentLabel(
            parentType: d.parentType,
            parentId: d.parentId,
            link: true,
          ),
        ),
      if (d.type.isNotEmpty)
        DetailInfoRow(
          label: context.tr('file_type'),
          value: d.type.toUpperCase(),
          copyable: false,
        ),
      if (d.size > 0)
        DetailInfoRow(
          label: context.tr('size'),
          value: formatSize(d.size),
          copyable: false,
        ),
      if (dims != null)
        DetailInfoRow(
          label: context.tr('dimensions'),
          value: '${dims.width} × ${dims.height}',
          copyable: false,
        ),
      // The list's "Private" column, as a row: a private file is the one
      // the client portal doesn't show.
      DetailInfoRow(
        label: context.tr('private'),
        value: context.tr(d.isPublic ? 'no' : 'yes'),
        copyable: false,
      ),
      if (d.userId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('user'),
          value: '',
          copyable: false,
          child: UserNameLabel(userId: d.userId),
        ),
      if (created != null)
        DetailInfoRow(
          label: context.tr('created_at'),
          value: created,
          copyable: false,
        ),
      if (updated != null)
        DetailInfoRow(
          label: context.tr('updated_at'),
          value: updated,
          copyable: false,
        ),
      if (d.hash.isNotEmpty)
        DetailInfoRow(
          label: context.tr('hash'),
          value: d.hash,
          monospace: true,
        ),
    ];
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowStack(children: rows),
    );
  }
}
