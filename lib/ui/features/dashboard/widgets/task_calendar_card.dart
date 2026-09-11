import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/utils/calendar_week_start.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_grid_mini.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Widest the month grid is allowed to get inside its card.
///
/// Not a wide-desktop nicety: the bottom grid stays **one column** from 600 px
/// all the way to 1199 (`_MultiColumnGrid` only splits at 1200), so without a
/// cap a 768 px tablet pane or a half-screen desktop window renders seven
/// ~110-165 px columns against a ~38 px row height — a month grid stretched
/// into a banner.
const double kMiniCalendarMaxWidth = 440;

/// Dashboard panel: a month at a glance, each day coloured by how much time is
/// already booked on it, so a user on the phone can see whether they are free
/// before agreeing to a date (invoiceninja/flutter#137).
///
/// Three things about this widget are load-bearing and none of them is visible
/// at the call site.
///
/// **It must keep itself alive.** Both dashboard bodies are lazily-collected
/// `ListView`s and this panel is appended last, so it *starts* off-screen: a
/// plain `StatefulWidget` here is garbage-collected past the cache extent,
/// taking its view model, its Drift subscription, the month the user paged to
/// and the fetch latch with it — every scroll back would reset the month and
/// re-request. Every other dashboard card is stateless, so nothing else in the
/// feature guards this.
///
/// **Nothing under it may be a `LayoutBuilder`.** The wide grid wraps each row
/// in `IntrinsicHeight`, which throws on an intrinsic query against a
/// `LayoutBuilder` in debug and silently answers 0 in release. Width-dependent
/// decisions here are made with `MediaQuery.textScalerOf` and a fixed cap
/// instead. `Center` is genuinely inert under an intrinsic query, but
/// `ConstrainedBox` is only *safe*, not transparent: `RenderConstrainedBox`
/// forwards the **incoming** width to its child without clamping it to
/// `maxWidth`, so under `IntrinsicHeight` the body is measured at the full
/// column width and then laid out at [kMiniCalendarMaxWidth]. Nothing inside
/// currently changes height with width — the caption is capped at one line for
/// exactly that reason — and anything added that does (a wrapping legend, a
/// longer translated string without `maxLines`) would be measured too short
/// and overflow.
///
/// **It is gated on `view_task`, unlike its six siblings.** They render
/// server-fed data the API has already permission-scoped, so an empty card
/// honestly means "nothing to show"; this one reads the local tasks table, and
/// a user who cannot view tasks has none in Drift — so an ungated grid would
/// paint every day unbooked, which is a positive claim of availability rather
/// than an absence of data. See `enabledPanelKinds`.
class DashboardTaskCalendarCard extends StatefulWidget {
  const DashboardTaskCalendarCard({
    required this.companyId,
    required this.formatter,
    required this.refreshNonce,
    super.key,
  });

  final String companyId;
  final Formatter formatter;

  /// The dashboard's last completed refresh. Pull-to-refresh runs
  /// `DashboardRepository.refreshAll`, which iterates the *cache-backed* kinds
  /// only — so without this the one gesture a user makes on a stale dashboard
  /// would refresh every panel except this one. A change re-arms the window
  /// fetch; a plain value comparison, so nothing happens during `build`.
  final DateTime? refreshNonce;

  @override
  State<DashboardTaskCalendarCard> createState() =>
      _DashboardTaskCalendarCardState();
}

class _DashboardTaskCalendarCardState extends State<DashboardTaskCalendarCard>
    with AutomaticKeepAliveClientMixin {
  late Services _services;
  late TaskCalendarViewModel _vm;

  /// See [_applyCalendarWeekStart] — the first application is synchronous and
  /// every later one defers a frame.
  bool _weekStartApplied = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _vm = _buildVm();
  }

  TaskCalendarViewModel _buildVm() => TaskCalendarViewModel(
    repo: _services.tasks,
    companyId: widget.companyId,
    // Seeded from the company here and corrected against the locale in
    // `didChangeDependencies`, which is the only place `MaterialLocalizations`
    // is reachable.
    firstDayOfWeek: widget.formatter.settings.firstDayOfWeek,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyCalendarWeekStart();
  }

  @override
  void didUpdateWidget(covariant DashboardTaskCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.formatter != widget.formatter) {
      // A company switch usually tears this whole subtree down (the dashboard
      // nulls its formatter and swaps the body for a spinner), but not when the
      // new company's formatter is already cached — then the swap never paints
      // and only this runs. Both paths have to rebind, so this is not dead.
      //
      // The formatter is in the condition because `_buildVm` seeds the week
      // start from it and `_navRow` formats the month label from it: watching
      // only the company would let the label switch locale on a rebuild while
      // the grid kept the old rotation, so one header would disagree with
      // itself until the card remounted.
      _vm.dispose();
      _vm = _buildVm();
      _weekStartApplied = false;
      _applyCalendarWeekStart();
    } else if (oldWidget.refreshNonce != null &&
        oldWidget.refreshNonce != widget.refreshNonce) {
      // `null` → the first stamp is not a refresh, it is the dashboard's
      // initial load completing — and it carries no task data, since
      // `refreshAll` only walks the cache-backed kinds. Re-arming on it would
      // make every cold start fetch this window twice, the second walk racing
      // the constructor's on a slow link.
      _vm.invalidateLoadedWindow();
      unawaited(_vm.ensureMonthLoaded());
    }
  }

  /// Align the grid's week start with every other rendered calendar in the app.
  ///
  /// The FIRST call runs synchronously: `didChangeDependencies` precedes this
  /// widget's first `build`, so nothing is watching the view model yet and
  /// there is nothing to notify — and applying it now means frame 1 already
  /// paints the right week start instead of flashing Sunday and correcting.
  /// Every later call defers a frame, because by then the grid is bound and
  /// `setFirstDayOfWeek` notifies, which inside the build phase is a
  /// setState-during-build on a mounted descendant. The view model's own
  /// no-change guard means the steady state schedules nothing.
  ///
  /// Safe for the window fetch either way: that window is month-aligned, so a
  /// change of week start cannot move it.
  void _applyCalendarWeekStart() {
    final value = calendarFirstDayOfWeek(context, widget.formatter);
    // Latched FIRST, before the no-change early return. Latching only when a
    // change was applied leaves the flag false forever in the common case (the
    // seeded company value already matches) — and a later locale change, which
    // is exactly what moves this when the company setting is unset, would then
    // take the synchronous branch with the grid long since bound and notify
    // mid-build.
    final isFirst = !_weekStartApplied;
    _weekStartApplied = true;
    if (value == _vm.firstDayOfWeek) return;
    if (isFirst) {
      _vm.setFirstDayOfWeek(value);
      return;
    }
    // Captured, not re-read: `didUpdateWidget` can replace `_vm` before this
    // fires, and applying company A's week start to company B's view model
    // sticks for the life of the card.
    final vm = _vm;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(vm, _vm)) return;
      vm.setFirstDayOfWeek(value);
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  // Both destinations are spelled once, here. Handing them down from the two
  // hosts as callbacks would make two copies of each — the drift the full-size
  // day cell avoids, and whose day-view string this deliberately matches so
  // both calendars land in the same place.
  void _openDay(Date day) =>
      context.go('/tasks?view=daily&date=${day.toIso()}');
  void _openCalendar() => context.go('/tasks?view=calendar');

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return DashboardCardShell(
      title: context.tr('task_calendar'),
      trailing: DashboardCardFooterLink(
        label: context.tr('view_all'),
        onTap: _openCalendar,
      ),
      padding: EdgeInsets.zero,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMiniCalendarMaxWidth),
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final tokens = context.inTheme;
    final loadByDay = _vm.loadByDayFiltered();
    final month = _vm.month;
    // Over the VISIBLE GRID, and on the duration rather than the key:
    // `taskLoadByDay` inserts a key for a zero-length entry too, so a month
    // whose only rows are `start == end` would suppress the caption while
    // every cell rendered untinted — a blank grid with no explanation, which
    // is the one state the caption exists for. Scoping it to the month rather
    // than the grid has the mirror-image failure: spill days that ARE booked
    // paint tinted cells under a caption saying nothing is.
    final hasVisibleLoad = _vm.gridDays.any(
      (d) => (loadByDay[d] ?? Duration.zero) > Duration.zero,
    );
    // A Drift watch emits on subscribe, so `hasLoaded` flips within a frame of
    // construction — before the window fetch that fills the grid's far edges
    // has resolved. The confident sentence waits for the fetch to have
    // *succeeded*, not merely to have stopped: a failed sweep leaves the
    // window unloaded, so an offline user is never told they are free on data
    // that never arrived. The dimming waits only on `hasLoaded`, or it would
    // flicker on every month change.
    final ready = _vm.hasLoaded && _vm.isVisibleWindowLoaded;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.md(context),
        0,
        InSpacing.md(context),
        InSpacing.md(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _navRow(context, tokens),
          // Until the Drift watch emits, every day would read as free — which
          // a surface about availability must not assert. Dimmed rather than
          // replaced by a skeleton, because the geometry is already correct
          // and only the confidence is missing — but `Opacity` is paint-only,
          // and on its own the un-loaded grid still announces "<date>, Free"
          // for all 42 cells to a screen reader and still accepts taps into a
          // day the panel has no data for. That is the same positive claim of
          // availability the `view_task` gate exists to prevent, so the
          // semantics and the hit test are suppressed with the paint.
          ExcludeSemantics(
            excluding: !_vm.hasLoaded,
            child: IgnorePointer(
              ignoring: !_vm.hasLoaded,
              child: Opacity(
                opacity: _vm.hasLoaded ? 1 : 0.4,
                child: TaskCalendarGridMini(
                  month: month,
                  gridDays: _vm.gridDays,
                  firstDayOfWeek: _vm.firstDayOfWeek,
                  loadByDay: loadByDay,
                  today: Date.today(),
                  formatter: widget.formatter,
                  onDayTap: _openDay,
                ),
              ),
            ),
          ),
          // The one caption, in the one state that needs it. A standing "a full
          // day is 8 hours" hint would never change and would cost a line on
          // every glance; this appears only when the grid would otherwise look
          // broken — a new account, or a month still wide open.
          if (ready && !hasVisibleLoad)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.tr('availability_nothing_booked'),
                textAlign: TextAlign.center,
                // One line, so this card's height cannot depend on its width —
                // see the `ConstrainedBox` note in the class doc.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: tokens.ink3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navRow(BuildContext context, InTheme tokens) {
    final locale = widget.formatter.settings.locale;
    // The empty→null guard matters: `DateFormat` misbehaves on `''`.
    final tag = locale.isEmpty ? null : locale;
    // The **skeleton**, never a literal `'MMM yyyy'`: a literal pins the field
    // order and drops the locale's own connectives, so `es` / `pt_BR` lose
    // their "de" and both bundled CJK locales render the year and month
    // backwards. Always the abbreviated form — there is no width branch to make
    // here, since a `LayoutBuilder` is forbidden under this card.
    final label = DateFormat.yMMM(
      tag,
    ).format(DateTime(_vm.month.year, _vm.month.month));
    final onThisMonth =
        _vm.month.year == Date.today().year &&
        _vm.month.month == Date.today().month;
    final size = actionButtonSize();

    return Row(
      children: [
        _navButton(Icons.chevron_left, context.tr('previous'), _vm.prevMonth),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
        ),
        _navButton(Icons.chevron_right, context.tr('next'), _vm.nextMonth),
        // Shown only off the current month, with its slot reserved so nothing
        // shifts: always-on it would be a control that does nothing on the very
        // month the panel opens to.
        if (onThisMonth)
          SizedBox(width: size)
        else
          _navButton(Icons.today_outlined, context.tr('today'), _vm.goToToday),
      ],
    );
  }

  Widget _navButton(IconData icon, String tooltip, VoidCallback onPressed) {
    final size = actionButtonSize();
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      // Pinned in one direction: an IconButton's layout box is otherwise
      // floored at `kMinInteractiveDimension` plus a density adjustment, and
      // three of them in a narrow card's row would blow the box.
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        minimumSize: Size.zero,
        maximumSize: Size.infinite,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
