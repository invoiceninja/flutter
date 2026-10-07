import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/tasks/task_rate.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// Everything the task-rate cascade reads besides the task itself:
///
///   `task.rate → project.taskRate → client → group → company`
///
/// A task left at rate 0 bills at whatever it inherits, so a figure that
/// multiplied the task's *own* rate would say `$0.00` about work the invoice
/// prices at the company default. The record screens resolve the rate the
/// same way the invoice line does (`resolveTaskRate`), through this.
@immutable
class TaskRateContext {
  const TaskRateContext({this.project, this.client, this.group, this.company});

  final Project? project;
  final Client? client;
  final GroupSetting? group;
  final Company? company;

  /// The hourly rate [task] bills at.
  Decimal rateFor(Task task) => resolveTaskRate(
    task: task,
    project: project,
    client: client,
    group: group,
    company: company,
  );

  /// What [task]'s billable time worked by [now] comes to.
  ///
  /// The same two factors as the invoice line `taskToLineItem` builds — the
  /// resolved rate, and hours to three decimals — so the figure on screen is
  /// the line the Invoice action produces. A booking contributes nothing
  /// (`Task.billableDuration`), and neither does a non-billable entry.
  Decimal amountFor(Task task, DateTime now) =>
      rateFor(task) * billableHours(task, now);
}

/// Billable hours worked by [now], to three decimals.
Decimal billableHours(Task task, DateTime now) => Decimal.parse(
  (task.billableDuration(now).inSeconds / 3600).toStringAsFixed(3),
);

/// Watches what [TaskRateContext] needs and rebuilds [builder] with it.
///
/// Every level is a row already in the local database — the company, the
/// client the header's link resolves, that client's group, the project — so
/// this adds no request. A level that has not loaded is simply skipped by the
/// cascade, which then answers with the next one down; the figure corrects
/// itself when the row lands.
class TaskRateContextBuilder extends StatelessWidget {
  const TaskRateContextBuilder({
    super.key,
    required this.companyId,
    required this.clientId,
    this.projectId = '',
    this.project,
    required this.builder,
  });

  final String companyId;
  final String clientId;

  /// Watched when [project] is not handed in — a task names its project by id.
  final String projectId;

  /// The project itself, when the host already holds it (the project screen).
  final Project? project;

  final Widget Function(BuildContext context, TaskRateContext rates) builder;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, company) => _Optional<Client>(
        id: clientId,
        cacheKey: (companyId, 'client', clientId),
        create: () =>
            services.clients.watch(companyId: companyId, id: clientId),
        builder: (context, client) => _Optional<GroupSetting>(
          id: client?.groupSettingsId ?? '',
          cacheKey: (companyId, 'group', client?.groupSettingsId ?? ''),
          create: () => services.groupSettings.watchByRealId(
            companyId: companyId,
            id: client!.groupSettingsId,
          ),
          builder: (context, group) => _Optional<Project>(
            id: project == null ? projectId : '',
            cacheKey: (companyId, 'project', projectId),
            create: () =>
                services.projects.watch(companyId: companyId, id: projectId),
            builder: (context, watched) => builder(
              context,
              TaskRateContext(
                project: project ?? watched,
                client: client,
                group: group,
                company: company.data,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A [WatchBuilder] that watches nothing when there is no [id] to watch.
///
/// Always the same widget, with or without an id: a level usually gains its
/// id *after* the first frame (the client row lands and names its group), and
/// returning [builder] bare until then would change the widget under it at
/// that moment — remounting the card it builds, mid-tick.
class _Optional<T> extends StatelessWidget {
  const _Optional({
    required this.id,
    required this.cacheKey,
    required this.create,
    required this.builder,
  });

  final String id;
  final Object cacheKey;
  final Stream<T?> Function() create;
  final Widget Function(BuildContext context, T? value) builder;

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<T?>(
      cacheKey: (cacheKey, id),
      create: () => id.isEmpty ? Stream<T?>.value(null) : create(),
      builder: (context, snapshot) =>
          builder(context, id.isEmpty ? null : snapshot.data),
    );
  }
}
