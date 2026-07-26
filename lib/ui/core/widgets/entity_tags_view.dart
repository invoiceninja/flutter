import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';

/// Read-only row of resolved tag chips for [tagIds], for detail screens and
/// list cells. Names/colors come from the tag cache (archived included, so an
/// attached-then-archived tag still renders properly). Renders nothing when
/// there are no tags — callers on detail screens should rely on that to hide
/// the row entirely (no dash).
///
/// The per-cell `StreamBuilder` is deliberate, and matches `ClientNameLabel` /
/// `UserNameLabel` / every other id→name resolver: every cell in a column
/// builds the *same* query, and drift keys its active query streams by
/// SQL+variables+tables, so N rows share one underlying query. Don't "optimize"
/// this into a hoisted stream threaded through the column definitions — it
/// would diverge from the shared pattern for no measured gain.
class EntityTagsView extends StatelessWidget {
  const EntityTagsView({
    super.key,
    required this.entityType,
    required this.tagIds,
    this.spacing = InSpacing.sm,
  });

  final String entityType;
  final List<String> tagIds;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tagIds.isEmpty) return const SizedBox.shrink();
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return StreamBuilder<List<Tag>>(
      stream: services.tags.watchAll(
        companyId: companyId,
        entityType: entityType,
        includeArchived: true,
      ),
      builder: (context, snap) {
        final byId = {for (final t in (snap.data ?? const <Tag>[])) t.id: t};
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final id in tagIds)
              TagPill(
                name: byId[id]?.name ?? id,
                colorHex: byId[id]?.color ?? '',
              ),
          ],
        );
      },
    );
  }
}
