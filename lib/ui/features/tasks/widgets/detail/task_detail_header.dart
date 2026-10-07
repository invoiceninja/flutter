import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity wrapper over [EntityDetailHeaderHost]. Identity falls back:
/// description → `#<number>` → `no_name_fallback`.
///
/// **The subtitle is client · project · number** — what the task is attached
/// to. Client and project are links to their own screens (never to an edit
/// screen), each for a user who may view that kind of record and plain text
/// for one who may not. They replace two one-row cards further down. The
/// number is in the line only when the description carries the identity;
/// when the number *is* the name, printing it twice says nothing.
///
/// A task attached to nothing and with no number to show falls back to the
/// created / updated dates, so the line is never blank.
///
/// **Tags sit under the subtitle**, where the user's own labels can be seen
/// without opening anything.
class TaskDetailHeader extends StatelessWidget {
  const TaskDetailHeader({
    super.key,
    required this.task,
    this.formatter,
    this.showStatePills = true,
  });

  final Task task;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  /// The task's name: its description, else its number, else "(no name)".
  static String displayNameOf(BuildContext context, Task t) {
    final description = t.description.trim();
    if (description.isNotEmpty) return description;
    return t.number.isNotEmpty
        ? '#${t.number}'
        : context.tr('no_name_fallback');
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Task>(
      entity: task,
      entityType: EntityType.task,
      recordId: task.id,
      formatter: formatter,
      project: (context, t) {
        final segments = _segments(context, t);
        return EntityHeaderFields(
          seedForAvatar: t.id,
          displayName: displayNameOf(context, t),
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
          isDeleted: t.isDeleted,
          isArchived: t.archivedAt != null,
          isDirty: t.isDirty,
          // A description is a sentence, not a name; two lines before the
          // ellipsis, and the Description card below has the rest.
          nameMaxLines: 2,
          showStatePills: showStatePills,
          subtitle: segments.isEmpty
              ? DetailHeaderTimestamps(
                  createdAt: t.createdAt,
                  updatedAt: t.updatedAt,
                  formatter: formatter,
                )
              : DetailSubtitle(segments: segments),
          tags: t.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(entityType: 'task', tagIds: t.tagIds),
                ),
        );
      },
    );
  }

  List<Widget> _segments(BuildContext context, Task t) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final showProject =
        t.projectId.isNotEmpty &&
        (me?.moduleEnabled(EntityType.project) ?? false);
    return [
      if (t.clientId.isNotEmpty)
        ClientNameLabel(
          clientId: t.clientId,
          // A link only to a screen this user can open.
          link: me?.can('view_client') ?? false,
        ),
      if (showProject)
        ProjectNameLabel(
          projectId: t.projectId,
          link: me?.can('view_project') ?? false,
        ),
      // LAST, and its own segment so it stays copyable: with a pointer
      // `CopyableValue` reserves the width of its hover icon whether or not it
      // is showing, which mid-line reads as a stray gap before the separator.
      if (t.description.trim().isNotEmpty && t.number.isNotEmpty)
        CopyableValue(
          value: t.number,
          fillWidth: false,
          child: Text('#${t.number}'),
        ),
    ];
  }
}
