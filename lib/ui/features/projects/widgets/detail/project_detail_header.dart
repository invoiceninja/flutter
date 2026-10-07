import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity wrapper over [EntityDetailHeaderHost]. The project's name
/// (falling back to `no_name_fallback`), and under it the line that says what
/// the project is attached to.
///
/// **The subtitle is client · number.** The client is a link to the client's
/// own screen — never to an edit screen — for a user who may view clients, and
/// plain text for one who may not. It replaces a whole "Client" card further
/// down that held one row. A project with neither a client nor a number falls
/// back to the created / updated dates, so the line is never blank.
///
/// **Tags sit under the subtitle**: they are the user's own classification of
/// this project, and a label worth applying is a label worth seeing without
/// opening anything.
class ProjectDetailHeader extends StatelessWidget {
  const ProjectDetailHeader({
    super.key,
    required this.project,
    this.formatter,
    this.showStatePills = true,
  });

  final Project project;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Project>(
      entity: project,
      entityType: EntityType.project,
      recordId: project.id,
      formatter: formatter,
      project: (context, p) {
        final segments = _segments(context, p);
        return EntityHeaderFields(
          seedForAvatar: p.id,
          displayName: p.name.isEmpty ? context.tr('no_name_fallback') : p.name,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          isDeleted: p.isDeleted,
          isArchived: p.archivedAt != null,
          isDirty: p.isDirty,
          // With the number in the subtitle there is nothing sharing the
          // name's baseline to protect.
          nameMaxLines: 2,
          showStatePills: showStatePills,
          subtitle: segments.isEmpty
              ? DetailHeaderTimestamps(
                  createdAt: p.createdAt,
                  updatedAt: p.updatedAt,
                  formatter: formatter,
                )
              : DetailSubtitle(segments: segments),
          tags: p.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(
                    entityType: 'project',
                    tagIds: p.tagIds,
                  ),
                ),
        );
      },
    );
  }

  List<Widget> _segments(BuildContext context, Project p) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    return [
      if (p.clientId.isNotEmpty)
        ClientNameLabel(
          clientId: p.clientId,
          // A link only to a screen this user can open.
          link: me?.can('view_client') ?? false,
        ),
      // LAST, and its own segment so it stays copyable: with a pointer
      // `CopyableValue` reserves the width of its hover icon whether or not it
      // is showing, which mid-line reads as a stray gap before the separator.
      if (p.number.isNotEmpty)
        CopyableValue(
          value: p.number,
          fillWidth: false,
          child: Text('#${p.number}'),
        ),
    ];
  }
}
