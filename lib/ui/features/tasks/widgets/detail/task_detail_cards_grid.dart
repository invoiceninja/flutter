import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/detail/entity_link_card.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/utils/formatting.dart';

/// Responsive grid for the task detail body cards.
///
/// - **≥1100 px**: two columns. Left (`Expanded`) carries the Time Log —
///   the dominant content for a task. Right (`SizedBox(width: 360)`)
///   stacks Details + Client link + Project link + Custom Fields. No
///   `IntrinsicHeight`: Time Log can be 50+ entries and we don't want to
///   force the sidebar to match its height.
/// - **<1100 px**: single centered column (≤820 px) — Details, Time Log,
///   Client, Project, Custom.
///
/// Status / rate / duration / entries-count surface in
/// [TaskDetailKpiStrip] above this grid, so the Details card no longer
/// repeats them.
class TaskDetailCardsGrid extends StatelessWidget {
  const TaskDetailCardsGrid({
    super.key,
    required this.task,
    required this.companyId,
    this.formatter,
  });

  final Task task;
  final String companyId;
  final Formatter? formatter;

  static const double _wideBreakpoint = 1100;
  static const double _sidebarWidth = 360;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (wide) return _wide(context);
        return CenteredFormColumn(child: _stacked(context));
      },
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TimeLogCard(task: task, formatter: formatter),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: _sidebarWidth,
          child: _stack(context, _sidebarCards(context)),
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    return _stack(context, <Widget>[
      _DetailsCard(task: task),
      _TimeLogCard(task: task, formatter: formatter),
      ..._linkCards(context),
      if (_hasAnyCustomValue(task))
        _CustomFieldsCard(
          task: task,
          companyId: companyId,
          formatter: formatter,
        ),
    ]);
  }

  List<Widget> _sidebarCards(BuildContext context) {
    return <Widget>[
      _DetailsCard(task: task),
      ..._linkCards(context),
      if (_hasAnyCustomValue(task))
        _CustomFieldsCard(
          task: task,
          companyId: companyId,
          formatter: formatter,
        ),
    ];
  }

  List<Widget> _linkCards(BuildContext context) {
    final cards = <Widget>[];
    if (task.clientId.isNotEmpty) {
      cards.add(
        EntityLinkCard<Client>(
          titleKey: 'client',
          icon: Icons.person_outline,
          entityId: task.clientId,
          routePath: '/clients/${task.clientId}',
          permissionKey: 'view_client',
          watchBuilder: () => context.read<Services>().clients.watch(
            companyId: companyId,
            id: task.clientId,
          ),
          displayNameOf: (c) =>
              c.displayName.isNotEmpty ? c.displayName : c.name,
        ),
      );
    }
    final me = context.read<Services>().auth.session.value?.currentCompany;
    if (task.projectId.isNotEmpty &&
        (me?.moduleEnabled(EntityType.project) ?? false)) {
      cards.add(
        EntityLinkCard<Project>(
          titleKey: 'project',
          icon: Icons.work_outline,
          entityId: task.projectId,
          routePath: '/projects/${task.projectId}',
          permissionKey: 'view_project',
          watchBuilder: () => context.read<Services>().projects.watch(
            companyId: companyId,
            id: task.projectId,
          ),
          displayNameOf: (p) => p.name,
        ),
      );
    }
    return cards;
  }

  Widget _stack(BuildContext context, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) SizedBox(height: InSpacing.lg(context)),
          cards[i],
        ],
      ],
    );
  }
}

bool _hasAnyCustomValue(Task t) =>
    t.customValue1.isNotEmpty ||
    t.customValue2.isNotEmpty ||
    t.customValue3.isNotEmpty ||
    t.customValue4.isNotEmpty;

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.ink3,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: InSpacing.md(context)),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.copyValue});
  final String label;
  final Widget value;

  /// When non-empty, the value gets a copy affordance (hover icon on
  /// desktop/web, tap-to-copy on mobile) that copies this string.
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    Widget styled = DefaultTextStyle.merge(
      child: value,
      style: TextStyle(fontSize: 13, color: tokens.ink),
    );
    final copy = copyValue;
    if (copy != null && copy.isNotEmpty) {
      styled = CopyableValue(value: copy, child: styled);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.ink3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: styled),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: context.tr('details').toUpperCase(),
      child: Column(
        children: [
          if (task.number.isNotEmpty)
            _Row(
              label: context.tr('number'),
              value: Text(task.number),
              copyValue: task.number,
            ),
          if (task.description.isNotEmpty)
            _Row(
              label: context.tr('description'),
              value: Text(task.description),
              copyValue: task.description,
            ),
          if (task.assignedUserId.isNotEmpty)
            _Row(
              label: context.tr('assigned_user'),
              value: UserNameLabel(userId: task.assignedUserId),
            ),
          if (task.isInvoiced)
            _Row(
              label: context.tr('invoice'),
              value: Text(context.tr('invoiced')),
            ),
          if (task.tagIds.isNotEmpty)
            _Row(
              label: context.tr('tags'),
              value: EntityTagsView(entityType: 'task', tagIds: task.tagIds),
            ),
        ],
      ),
    );
  }
}

class _TimeLogCard extends StatelessWidget {
  const _TimeLogCard({required this.task, this.formatter});
  final Task task;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (task.timeLog.isEmpty) {
      return _Card(
        title: context.tr('time_log').toUpperCase(),
        child: Text(
          context.tr('no_entries'),
          style: TextStyle(color: tokens.ink3),
        ),
      );
    }
    final entries = task.timeLog.reversed.toList(growable: false);
    return _Card(
      title: context.tr('time_log').toUpperCase(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _TimeEntrySummary(entry: entries[i], formatter: formatter),
            ),
        ],
      ),
    );
  }
}

class _TimeEntrySummary extends StatelessWidget {
  const _TimeEntrySummary({required this.entry, this.formatter});
  final TimeEntry entry;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final start = entry.start;
    final stop = entry.stop;
    final dateLabel = start == null
        ? '—'
        : '${_formatDate(start.toLocal())} '
              '${_hhmm(start.toLocal())}';

    final dateText = Text(
      dateLabel,
      style: TextStyle(color: tokens.ink2, fontSize: 13),
    );
    final descriptionText = Text(
      entry.description.isEmpty ? '—' : entry.description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tokens.ink, fontSize: 13),
    );
    final durationWidget = entry.isRunning && entry.start != null
        ? RunningDurationLabel(
            start: entry.start!,
            precision: const Duration(seconds: 1),
          )
        : Text(
            formatDuration(
              stop == null || start == null
                  ? Duration.zero
                  : stop.difference(start),
              compactDays: true,
            ),
            style: TextStyle(
              color: tokens.ink,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    final billableIcon = entry.billable
        ? null
        : Tooltip(
            message: context.tr('non_billable'),
            child: Icon(Icons.money_off_outlined, size: 14, color: tokens.ink3),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400) {
          // Phone: date on its own line above the description + duration so
          // the fixed 200px date column doesn't squeeze the description.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              dateText,
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: descriptionText),
                  const SizedBox(width: 12),
                  durationWidget,
                  if (billableIcon != null) ...[
                    const SizedBox(width: 8),
                    billableIcon,
                  ],
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 200, child: dateText),
            const SizedBox(width: 12),
            Expanded(child: descriptionText),
            const SizedBox(width: 12),
            durationWidget,
            if (billableIcon != null) ...[
              const SizedBox(width: 8),
              billableIcon,
            ],
          ],
        );
      },
    );
  }

  // [d] is already local (callers pass `.toLocal()`); honor military time
  // without a further tz conversion.
  String _hhmm(DateTime d) => formatTimeOfDay(
    d.hour,
    d.minute,
    military: formatter?.settings.enableMilitaryTime ?? true,
  );

  String _formatDate(DateTime d) {
    final iso =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final f = formatter;
    return f == null ? iso : f.date(iso);
  }
}

class _CustomFieldsCard extends StatelessWidget {
  const _CustomFieldsCard({
    required this.task,
    required this.companyId,
    this.formatter,
  });
  final Task task;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final yes = context.tr('yes');
    final no = context.tr('no');
    return StreamBuilder<Company?>(
      stream: context.read<Services>().company.watchCompany(companyId),
      builder: (context, snapshot) {
        final rows = customFieldDetailRows(
          company: snapshot.data,
          prefix: 'task',
          values: [
            task.customValue1,
            task.customValue2,
            task.customValue3,
            task.customValue4,
          ],
          formatter: formatter,
          yes: yes,
          no: no,
        );
        if (rows.isEmpty) return const SizedBox.shrink();
        return _Card(
          title: context.tr('custom_fields').toUpperCase(),
          child: Column(
            children: [
              for (final r in rows) _Row(label: r.label, value: Text(r.value)),
            ],
          ),
        );
      },
    );
  }
}
