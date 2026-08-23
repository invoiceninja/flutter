import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys exported for the settings sidebar search. Colocated with the
/// screen so adding / renaming a field updates both ends in one place.
const kSchedulesSearchKeys = <String>[
  'schedules',
  'template',
  'next_run',
  'frequency',
  'remaining_cycles',
  'pause_schedule',
  'email_statement',
  'email_record',
  'email_report',
  'invoice_outstanding_tasks',
  'payment_schedule',
];

/// `/settings/schedules` — list of every configured task scheduler.
///
/// Rich rows: each line reads as a "what-will-this-do" sentence with a
/// relative-time next-run and a Paused pill when the schedule is paused.
/// The empty state offers three starter cards so the user's first
/// interaction isn't a blank form.
class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen>
    with FormatterHostMixin {
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value?.currentCompanyId ?? '';
    if (_companyId.isNotEmpty) {
      loadFormatter(_services, _companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    final companyId = _companyId;
    final repo = services.schedules;
    final fmt = formatter;
    final hasAccess = services.auth.session.value?.hasProAccess ?? false;

    return SettingsEntityListScaffold<Schedule>(
      titleKey: 'schedules',
      sectionTitleKey: 'schedules',
      newRoute: '/settings/schedules/new',
      newLabelKey: 'new_schedule',
      emptyIcon: Icons.schedule_outlined,
      emptyTitleKey: 'no_schedules',
      emptyHintKey: 'no_schedules_hint',
      supportsArchive: true,
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => includeArchived
          ? repo.watchAllIncludingArchived(companyId: companyId)
          : repo.watchAll(companyId: companyId),
      isArchivedOf: (s) => s.archivedAt != null,
      isDeletedOf: (s) => s.isDeleted,
      rowBuilder: (s) => _ScheduleRow(
        key: ValueKey(s.id),
        schedule: s,
        formatter: fmt,
        onPause: () => repo.setPaused(
          companyId: companyId,
          schedule: s,
          paused: !s.isPaused,
        ),
      ),
      archivedRowBuilder: (s) => _ScheduleRow.archived(
        key: ValueKey(s.id),
        schedule: s,
        formatter: fmt,
      ),
      starters: const [
        SettingsListStarter(
          icon: Icons.mail_outline,
          titleKey: 'starter_email_monthly_statements',
          subtitleKey: 'starter_email_monthly_statements_hint',
          route: '/settings/schedules/new?starter=monthly_statement',
        ),
        SettingsListStarter(
          icon: Icons.assessment_outlined,
          titleKey: 'starter_run_pnl_quarterly',
          subtitleKey: 'starter_run_pnl_quarterly_hint',
          route: '/settings/schedules/new?starter=quarterly_pnl',
        ),
        SettingsListStarter(
          icon: Icons.notifications_active_outlined,
          titleKey: 'starter_invoice_reminders_weekly',
          subtitleKey: 'starter_invoice_reminders_weekly_hint',
          route: '/settings/schedules/new?starter=weekly_reminders',
        ),
      ],
      banner: const PlanGateBanner(style: PlanGateStyle.stripe),
      canCreate: hasAccess,
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.formatter,
    required this.onPause,
    super.key,
  }) : _isArchived = false;

  /// Variant rendered inside the "Archived" section. Drops the trailing
  /// chevron / pause action and renders a muted "Archived" pill instead.
  const _ScheduleRow.archived({
    required this.schedule,
    required this.formatter,
    super.key,
  }) : _isArchived = true,
       onPause = null;

  final Schedule schedule;

  /// May be null while the `formatterFor` future is still resolving — the
  /// row falls back to `—` for the date in that case.
  final Formatter? formatter;
  final VoidCallback? onPause;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final title = _summaryFor(context, schedule);
    final subtitle = _subtitleFor(context, schedule, formatter);
    final relative = _relativeNextRun(context, schedule);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(_iconFor(schedule.template), color: tokens.accent),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: _buildTrailing(context, tokens, theme, relative),
          onTap: () => context.go('/settings/schedules/${schedule.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    InTheme tokens,
    ThemeData theme,
    String? relative,
  ) {
    if (_isArchived) {
      return _Pill(
        text: context.tr('archived'),
        background: tokens.draftSoft,
        foreground: tokens.draft,
      );
    }

    final pieces = <Widget>[];
    // One state cue only. The trailing Row already carries the overflow menu,
    // and on a 360 dp phone a third child leaves the summary sentence zero
    // width — `ListTile` clamps that to 0 silently instead of raising an
    // overflow, so the title would just vanish. Unsynced outranks paused and
    // the relative next-run: a schedule the server never accepted isn't going
    // to run at all, which makes "in 3 days" actively misleading. The absolute
    // date stays in the subtitle either way.
    if (schedule.isDirty) {
      pieces.add(const UnsyncedPill());
    } else if (schedule.isPaused) {
      pieces.add(
        _Pill(
          text: context.tr('paused'),
          background: tokens.draftSoft,
          foreground: tokens.draft,
        ),
      );
    } else if (relative != null) {
      pieces.add(
        Text(
          relative,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    pieces.add(
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (v) {
          if (v == 'pause' || v == 'resume') onPause?.call();
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: schedule.isPaused ? 'resume' : 'pause',
            child: Text(context.tr(schedule.isPaused ? 'resume' : 'pause')),
          ),
        ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < pieces.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          pieces[i],
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

// ----- summary helpers -----

IconData _iconFor(String template) {
  switch (template) {
    case kScheduleTemplateEmailStatement:
      return Icons.receipt_long_outlined;
    case kScheduleTemplateEmailRecord:
      return Icons.mail_outline;
    case kScheduleTemplateEmailReport:
      return Icons.assessment_outlined;
    case kScheduleTemplateInvoiceOutstandingTasks:
      return Icons.timer_outlined;
    case kScheduleTemplatePaymentSchedule:
      return Icons.payments_outlined;
    default:
      return Icons.schedule_outlined;
  }
}

String _summaryFor(BuildContext context, Schedule s) {
  switch (s.template) {
    case kScheduleTemplateEmailStatement:
      final clients = s.statementClients;
      final clientPart = clients.isEmpty
          ? context.tr('all_clients')
          : (clients.length == 1
                ? '1 ${context.tr('client').toLowerCase()}'
                : '${clients.length} ${context.tr('clients').toLowerCase()}');
      return '${context.tr('email_statement')}: $clientPart';
    case kScheduleTemplateEmailRecord:
      final entityLabel = context.tr(s.recordEntityType);
      return '${context.tr('email')} $entityLabel';
    case kScheduleTemplateEmailReport:
      return '${context.tr('email_report')}: ${context.tr(s.reportName)}';
    case kScheduleTemplateInvoiceOutstandingTasks:
      final clients = s.outstandingTasksClients;
      final clientPart = clients.isEmpty
          ? context.tr('all_clients')
          : '${clients.length} ${context.tr('clients').toLowerCase()}';
      return '${context.tr('invoice_outstanding_tasks')} · $clientPart';
    case kScheduleTemplatePaymentSchedule:
      return context.tr('payment_schedule');
    default:
      return s.name.isNotEmpty ? s.name : context.tr('untitled');
  }
}

String? _subtitleFor(BuildContext context, Schedule s, Formatter? formatter) {
  final parts = <String>[];
  final nextRun = s.nextRun;
  if (nextRun != null && s.supportsNextRun) {
    // While the formatter resolves, fall back to ISO so the row isn't
    // blank — the date refreshes once the future completes.
    parts.add(formatter?.date(nextRun.toIso()) ?? nextRun.toIso());
  }
  if (s.supportsFrequency && s.frequencyId.isNotEmpty) {
    final key = kScheduleFrequencies[s.frequencyId];
    if (key != null) parts.add(context.tr(key));
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Relative-time renderer for `next_run`. Returns `"today"` for same-day,
/// `"in N days"` for future, `"N days ago"` for past, and so on. Returns
/// null when the schedule has no `next_run` (payment_schedule).
String? _relativeNextRun(BuildContext context, Schedule s) {
  final next = s.nextRun;
  if (next == null) return null;
  // Date-space (UTC) day diff — local-midnight + `.inDays` is off by one
  // across a spring-forward DST transition (L1).
  final days = next.differenceInDays(Date.today());
  if (days == 0) return context.tr('today');
  if (days == 1) return context.tr('tomorrow');
  if (days == -1) return context.tr('yesterday');
  if (days > 1 && days < 30) {
    return '${context.tr('in')} $days ${context.tr('days').toLowerCase()}';
  }
  if (days <= -2 && days > -30) {
    return '${-days} ${context.tr('days').toLowerCase()} ${context.tr('ago')}';
  }
  // Far future / far past — let the absolute date in the subtitle carry it.
  return null;
}
