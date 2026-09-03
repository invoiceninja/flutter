import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/static/activity_types_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/multi_entity_picker.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/activity/view_models/activity_view_model.dart';

/// One activity-type option for the multi-select.
typedef ActivityTypeOption = ({String id, String name});

/// Localized, name-sorted activity-type options. Built the same way the
/// Activity report's filter builds them (`reports_body.dart`), but rendered
/// through the public [MultiEntityPicker] rather than that file's private
/// `_MultiEntityField`.
List<ActivityTypeOption> activityTypeOptions(BuildContext context) => [
  for (final e in kActivityTypeLabelKeys.entries)
    (id: '${e.key}', name: context.tr(e.value)),
]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// Opens the activity filter surface: a centered dialog on wide viewports, a
/// scroll-controlled bottom sheet on narrow ones — the same split
/// `openManageDashboardCards` uses, so the two read as one family.
///
/// Mutations apply live against [vm]; there is no Save gate.
Future<void> openActivityFilters(
  BuildContext context, {
  required ActivityViewModel vm,
  required String companyId,
}) {
  final body = _FilterBody(vm: vm, companyId: companyId);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The user picker is a real text field, and `showModalBottomSheet` lifts
    // nothing by itself. Padding first also makes the 0.92 fraction measure
    // against the keyboard-reduced box rather than the whole screen — otherwise
    // the sheet keeps its full height and simply hides behind the keyboard.
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: FractionallySizedBox(heightFactor: 0.92, child: body),
    ),
  );
}

class _FilterBody extends StatelessWidget {
  const _FilterBody({required this.vm, required this.companyId});

  final ActivityViewModel vm;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = context.read<Services>();
    final typeOptions = activityTypeOptions(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            final f = vm.filters;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('filters'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      tooltip: context.tr('close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: InSpacing.md(context)),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<List<User>>(
                          stream: services.user.watchAllForPicker(
                            companyId: companyId,
                          ),
                          builder: (context, snap) {
                            final users = (snap.data ?? const <User>[]).toList()
                              ..sort(
                                (a, b) => a.displayName.toLowerCase().compareTo(
                                  b.displayName.toLowerCase(),
                                ),
                              );
                            User? selected;
                            for (final u in users) {
                              if (u.id == f.userId) {
                                selected = u;
                                break;
                              }
                            }
                            return SearchableDropdownField<User>(
                              label: context.tr('user'),
                              items: users,
                              initialValue: selected,
                              displayString: (u) => u.displayName,
                              idOf: (u) => u.id,
                              emptyHintKey: 'no_records_found',
                              onChanged: (u) => vm.setUser(u?.id),
                            );
                          },
                        ),
                        SizedBox(height: InSpacing.lg(context)),
                        // The human-written lens subsumes the type filter, so
                        // it sits above it and visibly disables it — see
                        // `ActivityFilters.lens`. A `SegmentedButton`, never a
                        // `RadioGroup`: this body is a `showModalBottomSheet`
                        // below 600 px, and `RadioGroup` mutates its subtree
                        // mid-frame and crashes that layout (the reason
                        // `entity_sort_filter_sheet.dart` hand-rolls a list).
                        // Horizontal scroll, not `width: double.infinity`.
                        // `SegmentedButton` clamps each child to
                        // `maxWidth / childCount`, so a full-width box does not
                        // overflow — it silently *clips* the labels, and
                        // "Comments" is one unbreakable word that already
                        // exceeds its ~78 px share on a 320 px sheet at
                        // `kTextScaleMax` (worse in de/fr). Scrolling keeps the
                        // labels whole, which is what `debug_panel_section.dart`
                        // and `segmented_setting_row.dart` both do for their own
                        // three-segment controls.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<ActivityLens>(
                              segments: [
                                ButtonSegment(
                                  value: ActivityLens.all,
                                  label: Text(context.tr('all')),
                                ),
                                ButtonSegment(
                                  value: ActivityLens.comments,
                                  label: Text(context.tr('comments')),
                                ),
                                ButtonSegment(
                                  value: ActivityLens.calls,
                                  label: Text(context.tr('calls')),
                                ),
                              ],
                              selected: {f.lens},
                              showSelectedIcon: false,
                              onSelectionChanged: (v) => vm.setLens(v.first),
                            ),
                          ),
                        ),
                        SizedBox(height: InSpacing.sm),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: f.lens != ActivityLens.all ? 0.4 : 1,
                          // All three, not just `IgnorePointer`: that blocks
                          // pointer events only, leaving the greyed-out picker
                          // reachable by Tab and announced to a screen reader as
                          // an enabled control that silently does nothing.
                          child: IgnorePointer(
                            ignoring: f.lens != ActivityLens.all,
                            child: ExcludeFocus(
                              excluding: f.lens != ActivityLens.all,
                              child: ExcludeSemantics(
                                excluding: f.lens != ActivityLens.all,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MultiEntityPicker<ActivityTypeOption>(
                                      labelKey: 'type',
                                      selectedIds: f.typeIds
                                          .map((e) => '$e')
                                          .toList(growable: false),
                                      items: typeOptions,
                                      idOf: (o) => o.id,
                                      displayString: (o) => o.name,
                                      onChanged: (ids) => vm.setTypeIds(
                                        ids
                                            .map(int.tryParse)
                                            .whereType<int>()
                                            .toSet(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: InSpacing.md(context)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: f.isActive ? vm.clearFilters : null,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(context.tr('clear_filters')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
