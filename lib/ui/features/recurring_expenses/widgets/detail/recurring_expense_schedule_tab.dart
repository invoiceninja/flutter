import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_schedule_date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_refresh_scope.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/utils/formatting.dart';

/// The dates a recurring expense will run on, as the server works them out
/// (`GET /recurring_expenses/{id}?show_dates=true`). Mirrors the recurring
/// invoice's Schedule tab, minus the due date an expense does not have.
///
/// Read-only and fetched on demand: `recurring_dates` is deliberately not
/// kept in the local database, so there is nothing to watch. **The request is
/// made when this tab is first opened**, not when the record is — the card it
/// replaces asked on every open, including each record passed while stepping
/// down a list.
///
/// It asks again when the record changes under it ([revision] — an edit can
/// move every date) and when the screen is refreshed while this tab is the
/// one on stage.
class RecurringExpenseScheduleTab extends StatefulWidget {
  const RecurringExpenseScheduleTab({
    super.key,
    required this.recurringExpenseId,
    required this.revision,
    required this.formatter,
  });

  final String recurringExpenseId;

  /// Anything that changes when the record does — its `updatedAt`.
  final Object? revision;
  final Formatter? formatter;

  @override
  State<RecurringExpenseScheduleTab> createState() =>
      _RecurringExpenseScheduleTabState();
}

class _RecurringExpenseScheduleTabState
    extends State<RecurringExpenseScheduleTab> {
  late Future<List<RecurringScheduleDate>> _future;
  DetailRefreshSignal? _refresh;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RecurringScheduleDate>> _load() => context
      .read<Services>()
      .recurringExpenses
      .api
      .fetchSchedule(id: widget.recurringExpenseId);

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  /// The screen was refreshed. Offstage, this tab is still mounted; it does
  /// not answer for a pull the user made while looking at another tab.
  void _onRefresh() {
    if (mounted && TickerMode.valuesOf(context).enabled) _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refresh = DetailRefreshScope.maybeOf(context);
    if (identical(refresh, _refresh)) return;
    _refresh?.removeListener(_onRefresh);
    _refresh = refresh;
    _refresh?.addListener(_onRefresh);
  }

  @override
  void didUpdateWidget(RecurringExpenseScheduleTab old) {
    super.didUpdateWidget(old);
    if (old.recurringExpenseId != widget.recurringExpenseId ||
        old.revision != widget.revision) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _refresh?.removeListener(_onRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final f = widget.formatter;
    return FutureBuilder<List<RecurringScheduleDate>>(
      future: _future,
      builder: (context, snap) {
        // Top only: the record page already insets a tab's body at the
        // sides, and a second inset set this tab in from every other.
        Widget pad(Widget child) => Padding(
          padding: EdgeInsets.only(top: InSpacing.lg(context)),
          child: child,
        );
        if (snap.connectionState == ConnectionState.waiting) {
          return pad(const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return pad(
            ErrorView(
              message: context.tr('an_error_occurred'),
              onRetry: _reload,
            ),
          );
        }
        final dates = [
          for (final r in snap.data ?? const <RecurringScheduleDate>[])
            if (r.sendDate != null) r.sendDate!,
        ];
        if (dates.isEmpty) {
          return pad(
            EmptyState(
              icon: Icons.calendar_month_outlined,
              title: context.tr('no_records_found'),
            ),
          );
        }
        final rowPadding = EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.md(context),
        );
        return pad(
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(InRadii.r3),
              color: tokens.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: rowPadding,
                  child: Text(
                    context.tr('send_date'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      // `ink2`: `ink3` at this size is under the contrast
                      // floor on a card.
                      color: tokens.ink2,
                    ),
                  ),
                ),
                for (final date in dates) ...[
                  Divider(height: 1, color: tokens.border),
                  Padding(
                    padding: rowPadding,
                    // Never the raw ISO date: blank until the company's
                    // format is here.
                    child: Text(
                      f?.date(date.toIso()) ?? '',
                      style: TextStyle(color: tokens.ink),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
