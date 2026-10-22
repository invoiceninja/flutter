import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/static/activity_types_catalog.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/multi_entity_picker.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/activity/view_models/activity_view_model.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/utils/formatting.dart';

/// One activity-type option for the multi-select.
typedef ActivityTypeOption = ({String id, String name});

/// Localized, name-sorted activity-type options. Built the same way the
/// Activity report's filter builds them (`report_filters.dart`), but rendered
/// through the public [MultiEntityPicker] rather than that file's private
/// `_MultiEntityField`.
List<ActivityTypeOption> activityTypeOptions(BuildContext context) => [
  for (final e in kActivityTypeLabelKeys.entries)
    (id: '${e.key}', name: context.tr(e.value)),
]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// The label a category chip and its header chip read.
String activityCategoryLabel(BuildContext context, ActivityCategory c) =>
    switch (c) {
      ActivityCategory.sent => context.tr('sent'),
      ActivityCategory.viewed => context.tr('viewed'),
      ActivityCategory.paid => context.tr('activity_category_paid'),
      ActivityCategory.edited => context.tr('activity_category_edited'),
      ActivityCategory.expense => context.tr('expenses'),
      ActivityCategory.comment => context.tr('comments'),
      ActivityCategory.other => context.tr('other'),
    };

/// The glyph a category chip wears — the row icon of the rows it keeps, so
/// the chip and its rows read as one thing. Comments get the speech bubble
/// rather than the neutral circle they share with "other" in the feed.
IconData activityCategoryIcon(ActivityCategory c) =>
    c == ActivityCategory.comment
    ? Icons.chat_bubble_outline
    : activityIconFor(toneForCategory(c));

/// Opens the activity filter surface: a centered dialog on wide viewports, a
/// scroll-controlled bottom sheet on narrow ones — the same split
/// `openManageDashboardCards` uses, so the two read as one family. A pane wide
/// enough for the side rail never opens this: the rail *is* the same panel.
///
/// Mutations apply live against [vm]; there is no Save gate.
Future<void> openActivityFilters(
  BuildContext context, {
  required ActivityViewModel vm,
  required String companyId,
  Formatter? formatter,
}) {
  final body = ActivityFilterPanel(
    vm: vm,
    companyId: companyId,
    formatter: formatter,
  );
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

/// The activity filters: date range, category, user, lens and type.
///
/// One widget, two hosts — the sheet / dialog from [openActivityFilters], and
/// (with [inline]) the side rail a wide `/activity` pane shows instead of a
/// filter button. Inline drops the close button and the safe-area inset (the
/// rail sits inside the screen's own `Scaffold`).
class ActivityFilterPanel extends StatefulWidget {
  const ActivityFilterPanel({
    super.key,
    required this.vm,
    required this.companyId,
    this.formatter,
    this.inline = false,
  });

  final ActivityViewModel vm;
  final String companyId;
  final Formatter? formatter;
  final bool inline;

  @override
  State<ActivityFilterPanel> createState() => _ActivityFilterPanelState();
}

class _ActivityFilterPanelState extends State<ActivityFilterPanel> {
  // Hoisted out of `build`: the inline rail rebuilds on every keystroke in
  // the search box, and a watch stream opened per build re-queries the roster
  // each time.
  late final Stream<List<User>> _users = context
      .read<Services>()
      .user
      .watchAllForPicker(companyId: widget.companyId);

  ActivityViewModel get vm => widget.vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeOptions = activityTypeOptions(context);

    final panel = Padding(
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
                    child: Semantics(
                      header: true,
                      headingLevel: widget.inline ? 2 : 1,
                      child: Text(
                        context.tr('filters'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.inline)
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
                      _DateRangeRow(vm: vm, formatter: widget.formatter),
                      SizedBox(height: InSpacing.lg(context)),
                      _CategoryChips(vm: vm),
                      SizedBox(height: InSpacing.lg(context)),
                      StreamBuilder<List<User>>(
                        stream: _users,
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
                        alignment: AlignmentDirectional.centerStart,
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
                alignment: AlignmentDirectional.centerStart,
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
    );
    return widget.inline ? panel : SafeArea(top: false, child: panel);
  }
}

/// The range control: the dashboard's period picker (presets plus a custom
/// calendar), so "Last 30 days" means the same thing on both screens.
///
/// A preset is resolved to dates **when it is picked** and stored as a fixed
/// range, the same shape a timeline bar writes — the filter has one
/// representation, and its chip prints the dates it is actually applying.
/// "All Time" is how the picker says "no range".
class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({required this.vm, required this.formatter});

  final ActivityViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final f = vm.filters;
    final current = _currentRange(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(context.tr('date_range')),
        const SizedBox(height: InSpacing.xs),
        Row(
          children: [
            Flexible(
              child: DateRangePickerButton(
                current: current,
                formatter: formatter,
                onChange: (r) {
                  if (r is DashboardPresetRange &&
                      r.preset == DashboardDatePreset.allTime) {
                    vm.setRange(null, null);
                    return;
                  }
                  final (start, end) = r.resolve(
                    firstMonthOfYear: formatter?.settings.firstMonthOfYear ?? 1,
                  );
                  vm.setRange(start.toDateTime(), end.addDays(1).toDateTime());
                },
              ),
            ),
            if (f.hasRange)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: context.tr('clear'),
                onPressed: () => vm.setRange(null, null),
              ),
          ],
        ),
      ],
    );
  }

  /// The picker's view of the active range: whole days, inclusive. An hour
  /// bar's range shows as its day — the chip above the feed carries the
  /// hours.
  static DashboardDateRange _currentRange(ActivityFilters f) {
    if (!f.hasRange) {
      return const DashboardPresetRange(DashboardDatePreset.allTime);
    }
    final from = f.from;
    final until = f.until;
    final start = from == null ? null : Date(from.year, from.month, from.day);
    // `until` is exclusive: a midnight bound ends the day before.
    final endInstant = until?.subtract(const Duration(milliseconds: 1));
    final end = endInstant == null
        ? null
        : Date(endInstant.year, endInstant.month, endInstant.day);
    final today = Date.today();
    return DashboardCustomRange(
      start: start ?? end ?? today,
      end: end ?? today,
    );
  }
}

/// One chip per category, each with what it would keep under the other
/// filters (`ActivityViewModel.categoryCounts`). A zero chip that isn't
/// already on is disabled — ticking it could only empty the feed.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.vm});

  final ActivityViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final selected = vm.filters.categories;
    final counts = vm.categoryCounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(context.tr('category')),
        const SizedBox(height: InSpacing.xs),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.xs,
          children: [
            for (final c in ActivityCategory.values)
              Builder(
                builder: (context) {
                  final n = counts[c] ?? 0;
                  final on = selected.contains(c);
                  final (_, fg) = activityToneColors(
                    tokens,
                    toneForCategory(c),
                  );
                  return FilterChip(
                    selected: on,
                    showCheckmark: false,
                    // Denser on a pointer only — on touch the chip keeps its
                    // padded target (CLAUDE.md § Design system, touch targets).
                    visualDensity: Env.isTouchPrimary
                        ? null
                        : VisualDensity.compact,
                    avatar: Icon(activityCategoryIcon(c), size: 16, color: fg),
                    label: Text.rich(
                      TextSpan(
                        text: activityCategoryLabel(context, c),
                        children: [
                          TextSpan(
                            text: '  $n',
                            style: TextStyle(color: tokens.ink3),
                          ),
                        ],
                      ),
                    ),
                    onSelected: n == 0 && !on
                        ? null
                        : (_) => vm.toggleCategory(c),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: context.inTheme.ink3),
  );
}
