import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_figures.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/views/reports_gallery_screen.dart';
import 'package:admin/utils/formatting.dart';

/// What went wrong, in the reader's words.
///
/// A server message is passed through only where it is the useful part (a
/// validation message, a server's own reason), and never blank: `join` of no
/// field errors is `''`, and a message field can arrive as `""`.
String reportErrorMessage(BuildContext context, ReportError error) =>
    reportErrorText(context.tr, error);

/// [reportErrorMessage] for a caller that only holds the translate function
/// — one that captured it before an `await` and may have no context left.
String reportErrorText(
  String Function(String, [Map<String, String>?]) tr,
  ReportError error,
) {
  String? nonBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  switch (error.kind) {
    case ReportErrorKind.timeout:
      return tr('report_still_working');
    case ReportErrorKind.planRequired:
      return tr('upgrade_to_view_reports');
    case ReportErrorKind.unauthorized:
      return tr('access_denied');
    case ReportErrorKind.validation:
      final lines = [
        for (final messages
            in error.fieldErrors?.values ?? const <List<String>>[])
          for (final m in messages)
            if (m.trim().isNotEmpty) m.trim(),
      ];
      return lines.isEmpty ? tr('an_error_occurred') : lines.join(' · ');
    case ReportErrorKind.network:
      return tr('no_internet_connection');
    case ReportErrorKind.rateLimited:
      return tr('too_many_requests');
    case ReportErrorKind.emailedInstead:
      return tr('report_emailed_instead');
    case ReportErrorKind.passwordRequired:
      return tr('password_required');
    case ReportErrorKind.serverError:
    case ReportErrorKind.cancelled:
    case ReportErrorKind.unknown:
      return nonBlank(error.message) ?? tr('an_error_occurred');
  }
}

/// A line above the results saying they are not current, and why — with the
/// way forward on it.
///
/// A result on screen is never thrown away because a refresh of it failed:
/// yesterday's figures with "showing results from 2 h ago" on them are more
/// use than an error page. The notice is what keeps that honest — and, for
/// a report built on the device, that its rows are what the device held,
/// which a refresh had not yet checked.
///
/// With nothing wrong, the Tasks report uses the same line to offer Task
/// Items, when a task in the range has time outside it
/// ([ReportsViewModel.showsTaskItemsHint]).
class ReportNotice extends StatelessWidget {
  const ReportNotice({super.key, required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final error = vm.run.error;
    final hasResult = vm.hasResult;
    String? older() {
      final at = vm.resultFetchedAt;
      if (!hasResult || at == null) return null;
      return tr('report_showing_older', {
        'time': formatRelativeTime(context, DateTime.now().difference(at)),
      });
    }

    // Rows the device built with no refresh behind them yet. Said only once
    // the refresh has failed, or cannot be made: while it is on its way the
    // hairline above says so, and the line would flash on every open.
    final device = hasResult && vm.resultFromDevice
        ? tr(
            vm.definition.rowsAreTimeEntries
                ? 'report_device_rows'
                : 'report_device_records',
          )
        : null;

    if (error != null) {
      final timedOut = error.kind == ReportErrorKind.timeout;
      return _Banner(
        icon: timedOut
            ? Icons.hourglass_bottom
            : (error.kind == ReportErrorKind.emailedInstead
                  ? Icons.email_outlined
                  : Icons.error_outline),
        tone: timedOut || error.kind == ReportErrorKind.emailedInstead
            ? _Tone.neutral
            : _Tone.problem,
        message: [
          [reportErrorMessage(context, error), ?older()].join(' '),
          ?device,
        ].join(' · '),
        actions: [
          if (timedOut)
            (tr('keep_waiting'), vm.keepWaiting)
          // No Retry where a retry cannot help: a plan it needs, or a server
          // that answers by email — where each retry is another email.
          else if (error.kind != ReportErrorKind.planRequired &&
              error.kind != ReportErrorKind.emailedInstead)
            (tr('retry'), vm.runReport),
        ],
      );
    }
    if (!vm.isOnline) {
      return _Banner(
        icon: Icons.cloud_off_outlined,
        tone: _Tone.neutral,
        message: [tr('offline'), ?older(), ?device].join(' · '),
        actions: const [],
      );
    }
    if (device != null && !vm.run.isLoading) {
      return _Banner(
        icon: Icons.devices_outlined,
        tone: _Tone.neutral,
        message: device,
        actions: [(tr('refresh'), vm.runReport)],
      );
    }
    if (vm.showsTaskItemsHint) {
      return _Banner(
        icon: Icons.timer_outlined,
        tone: _Tone.neutral,
        message: tr('report_tasks_first_entry_hint'),
        // Not announced: it is advice, and it is shown again on every run
        // that leaves it true.
        liveRegion: false,
        actions: [
          (
            tr('report_show_task_items'),
            () {
              // The same range and filters: the reader was asking about
              // this week, not Task Items' own last one.
              vm.seedNextOpen('task_item', vm.payload);
              context.go(reportRoutePath('task_item'));
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

enum _Tone { neutral, problem }

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.tone,
    required this.message,
    required this.actions,
    this.liveRegion = true,
  });

  final IconData icon;
  final _Tone tone;
  final String message;
  final List<(String, VoidCallback)> actions;

  /// Whether a screen reader announces the line when it appears — yes for
  /// news about the result, no for standing advice.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final problem = tone == _Tone.problem;
    return Semantics(
      liveRegion: liveRegion,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: problem ? tokens.overdueSoft : tokens.surfaceAlt,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: 6,
          ),
          // The pane, not the window: the line sits above a report's
          // results, in whatever width the sidebar leaves.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final text = Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink),
              );
              final buttons = [
                for (final (label, onTap) in actions)
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      // A finger's target on touch (docs/touch-targets.md).
                      minimumSize: Size(48, Env.isTouchPrimary ? 44 : 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(label),
                  ),
              ];
              final icon = Icon(
                this.icon,
                size: 16,
                color: problem ? tokens.overdue : tokens.ink2,
              );
              // Narrow, the actions go under the message: beside it, a long
              // one ("Show task items in this range") takes the width the
              // message needs, and at a large text size leaves it none — one
              // character a line, the banner taller than the screen.
              if (constraints.maxWidth < _kBannerInlineWidth &&
                  buttons.isNotEmpty) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: icon,
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          text,
                          Wrap(alignment: WrapAlignment.end, children: buttons),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: InSpacing.sm),
                  Expanded(child: text),
                  ...buttons,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The pane width from which a notice's actions sit beside its message.
const double _kBannerInlineWidth = 600;

/// The shape of a report while its first result is on the way: figures, a
/// chart, rows. A skeleton rather than a spinner, so the page does not jump
/// when the result lands — and so a slow job reads as "this is coming"
/// rather than "nothing is here".
class ReportSkeleton extends StatelessWidget {
  const ReportSkeleton({super.key, required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final pad = wide ? InSpacing.xl : InSpacing.lg(context);
    Widget card(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: child,
      ),
    );
    return Semantics(
      label: context.tr('loading_ellipsis'),
      child: ExcludeSemantics(
        child: ListView(
          padding: EdgeInsets.all(pad),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < (wide ? 4 : 2); i++)
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FigureSkeletonBar(width: 56, height: 9),
                              SizedBox(height: 10),
                              FigureSkeletonBar(width: 96, height: 16),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: InSpacing.xl),
                  // The border tone, not the alternate surface: against a
                  // card that one is all but invisible.
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: tokens.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(InRadii.r1),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: InSpacing.lg(context)),
            card(
              Column(
                children: [
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          // Flexible: at 360 px the three bars are wider than
                          // the card, and the row overflowed while loading.
                          Flexible(
                            child: FigureSkeletonBar(width: 120 + (i % 3) * 30),
                          ),
                          const Spacer(),
                          const FigureSkeletonBar(width: 64),
                          const SizedBox(width: 24),
                          const FigureSkeletonBar(width: 64),
                        ],
                      ),
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

/// A message that has the page to itself, with at most one thing to do
/// about it.
class ReportMessage extends StatelessWidget {
  const ReportMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(InSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: tokens.ink3),
              SizedBox(height: InSpacing.md(context)),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
              ),
              if (actions.isNotEmpty) ...[
                SizedBox(height: InSpacing.lg(context)),
                Wrap(
                  spacing: InSpacing.md(context),
                  runSpacing: InSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
