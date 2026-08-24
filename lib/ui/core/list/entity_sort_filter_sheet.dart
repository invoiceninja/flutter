import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// One short-list option in [EntitySortFilterSheet].
@immutable
class SortOption {
  const SortOption({required this.id, required this.label});
  final String id;
  final String label;
}

/// One grouping dimension offered in [EntitySortFilterSheet]'s "Group by"
/// section. [id] is the entity's own grouping key (Products uses
/// `custom1`..`custom4` / `tags`) — the sheet never interprets it.
@immutable
class GroupOption {
  const GroupOption({required this.id, required this.label});
  final String id;
  final String label;
}

/// Bottom-sheet body for the sort filter on mobile. Generic across entity
/// types — each entity declares its own curated short list of sort fields
/// via [options].
///
/// Single-select radio list for the field, plus an ascending/descending
/// switch. Applies on Done — closing without tapping Done discards.
///
/// When [groupOptions] is non-empty the sheet grows a second single-select
/// "Group by" section, applied by the same Done button. Grouping lives here
/// rather than behind its own AppBar icon because it is sort-adjacent and the
/// narrow AppBar already carries select + sort. Every list that passes no
/// group options renders exactly as before.
///
/// Mobile keeps a curated short list of fields here (matches the old
/// dropdown). Desktop bypasses this sheet entirely — its column headers
/// drive sort directly and can sort by any visible column.
class EntitySortFilterSheet extends StatefulWidget {
  const EntitySortFilterSheet({
    required this.initialField,
    required this.initialAscending,
    required this.options,
    required this.onApply,
    this.groupOptions = const [],
    this.initialGroup,
    this.onApplyGroup,
    super.key,
  });

  final String initialField;
  final bool initialAscending;
  final List<SortOption> options;
  final void Function({required String field, required bool ascending}) onApply;

  /// Grouping dimensions to offer. Empty (the default) hides the section.
  final List<GroupOption> groupOptions;

  /// Currently-selected grouping id; null means "No grouping".
  final String? initialGroup;

  /// Called on Done with the chosen grouping id (null = no grouping). Only
  /// invoked when [groupOptions] is non-empty.
  final void Function(String? groupId)? onApplyGroup;

  @override
  State<EntitySortFilterSheet> createState() => _EntitySortFilterSheetState();
}

class _EntitySortFilterSheetState extends State<EntitySortFilterSheet> {
  late String _field;
  late bool _ascending;
  String? _group;

  /// [_group] as `initState` normalized it. Done writes back only on a real
  /// change: an `initialGroup` that isn't on offer normalizes to null for
  /// display, and firing that back would silently erase a grouping the user
  /// never touched (the dimension can be temporarily absent — e.g. its rows
  /// filtered out of the loaded window).
  String? _initialGroup;

  @override
  void initState() {
    super.initState();
    // Drop a stale grouping id that's no longer on offer (e.g. the company
    // un-configured that custom field) so the radio can't show a dead value.
    final groupIds = widget.groupOptions.map((o) => o.id).toSet();
    _group = groupIds.contains(widget.initialGroup)
        ? widget.initialGroup
        : null;
    _initialGroup = _group;
    // If the persisted sort field isn't in the mobile shortlist (user picked
    // a desktop-only column then opened the sheet on mobile), preselect the
    // first option so the radio has a valid value — Done re-applies it.
    final ids = widget.options.map((o) => o.id).toSet();
    _field = ids.contains(widget.initialField)
        ? widget.initialField
        : widget.options.first.id;
    _ascending = widget.initialAscending;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.tr('sort'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            // Plain selectable list rather than RadioGroup: RadioGroup's
            // Shortcuts.manager + FocusTraversalGroup + post-frame
            // single-selection check mutate the subtree mid-frame, which
            // re-enters showModalBottomSheet's size-listening layout and
            // crashes (MouseTracker / `!_debugDoingThisLayout` asserts).
            for (final opt in widget.options)
              ListTile(
                title: Text(opt.label),
                selected: _field == opt.id,
                trailing: _field == opt.id ? const Icon(Icons.check) : null,
                onTap: () => setState(() => _field = opt.id),
              ),
            const Divider(height: 1),
            SwitchListTile(
              value: _ascending,
              title: Text(context.tr('ascending')),
              onChanged: (v) => setState(() => _ascending = v),
            ),
            const Divider(height: 1),
            if (widget.groupOptions.isNotEmpty) ...[
              ListTile(
                title: Text(
                  context.tr('group_by'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              // Same plain-ListTile idiom as the sort list above — see the
              // RadioGroup note there for why this isn't a real radio group.
              ListTile(
                title: Text(context.tr('no_grouping')),
                selected: _group == null,
                trailing: _group == null ? const Icon(Icons.check) : null,
                onTap: () => setState(() => _group = null),
              ),
              for (final opt in widget.groupOptions)
                ListTile(
                  title: Text(opt.label),
                  selected: _group == opt.id,
                  trailing: _group == opt.id ? const Icon(Icons.check) : null,
                  onTap: () => setState(() => _group = opt.id),
                ),
              const Divider(height: 1),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PrimaryDialogAction(
                    label: context.tr('done'),
                    onPressed: () {
                      widget.onApply(field: _field, ascending: _ascending);
                      if (widget.groupOptions.isNotEmpty &&
                          _group != _initialGroup) {
                        widget.onApplyGroup?.call(_group);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
