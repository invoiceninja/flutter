import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/widgets/document_type_icon.dart';
import 'package:admin/utils/formatting.dart';

/// The document record's identity: its name, and a subtitle of what kind of
/// file it is — type · size · "Private" — the facts that tell two files with
/// similar names apart. A document has no lifecycle, so no state pills.
class DocumentDetailHeader extends StatelessWidget {
  const DocumentDetailHeader({
    super.key,
    required this.document,
    this.formatter,
  });

  final DocumentRecord document;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final segments = <Widget>[
      if (document.type.isNotEmpty) Text(document.type.toUpperCase()),
      if (document.size > 0) Text(formatSize(document.size)),
      if (!document.isPublic) Text(context.tr('private')),
    ];
    return EntityDetailHeader(
      // The id, never the name: a rename must not reshuffle the tint.
      seedForAvatar: document.id,
      displayName: document.displayName,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      isDeleted: false,
      isArchived: false,
      isDirty: document.isDirty,
      formatter: formatter,
      fallbackIcon: documentTypeIcon(document.type),
      nameMaxLines: 2,
      showStatePills: false,
      subtitle: segments.isEmpty
          ? DetailHeaderTimestamps(
              createdAt: document.createdAt,
              updatedAt: document.updatedAt,
              formatter: formatter,
            )
          : DetailSubtitle(segments: segments),
    );
  }
}
