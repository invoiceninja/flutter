import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';

/// The company's task statuses as a picker — the sibling of
/// `AssignedUserPickerField`, and under `features/tasks/` rather than
/// `core/widgets/` because a task status is not a cross-feature concept.
///
/// Three things it owns so its two call sites (the task edit form and the
/// create-task-from-line-item sheet) cannot drift:
///
///  * `taskStatuses.watchAll` is already active-only and already ordered
///    (`statusOrder`, then `name.lower()`), so unlike the roster this needs no
///    client-side narrowing or sorting. That order is also the kanban board's
///    column order — `KanbanViewModel` reads the same accessor — which is what
///    makes "the first row" a meaningful default for a caller that wants one.
///  * The selection resolves through `watch(id)`. `watchAll` excludes archived
///    statuses, so a task sitting on a since-archived one would otherwise blank
///    its own Status field with no way to see what it had been.
///  * The 10 px dot is the same `taskStatusColors` swatch the list pill, the
///    kanban header and the settings rows use. `SearchableDropdownField` uses
///    `optionLeadingBuilder` for the field's **prefix** as well as for the
///    option rows, so the dot follows the committed value too.
///
/// No `emptyHintKey`, for the roster's reason: statuses arrive bundled on
/// `/refresh` and the server seeds four for every new company, so an empty list
/// is a loading state rather than a configuration.
class TaskStatusPickerField extends StatelessWidget {
  const TaskStatusPickerField({
    super.key,
    required this.companyId,
    required this.selectedId,
    required this.onChanged,
  });

  final String companyId;
  final String selectedId;

  /// Receives the picked status id, or `''` when the field is cleared.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<TaskStatus>(
      label: context.tr('status'),
      cacheKey: companyId,
      selectedId: selectedId,
      itemsStream: () => services.taskStatuses.watchAll(companyId: companyId),
      watchById: (id) =>
          services.taskStatuses.watch(companyId: companyId, id: id),
      displayString: (s) => s.name.trim().isEmpty ? s.id : s.name,
      idOf: (s) => s.id,
      optionLeadingBuilder: (context, status) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: taskStatusColors(
            context,
            name: status.name,
            color: status.color,
          ).fg,
          shape: BoxShape.circle,
        ),
      ),
      onChanged: (s) => onChanged(s?.id ?? ''),
    );
  }
}
