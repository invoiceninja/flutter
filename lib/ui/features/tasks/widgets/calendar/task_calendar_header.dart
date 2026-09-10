import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/calendar_connect_menu.dart';
import 'package:admin/utils/formatting.dart';

/// Month navigation bar above the calendar grid: prev / next month, the month
/// label, the events toggle, the calendar account control and a Today
/// shortcut. The label uses the company locale; there is no `Formatter`
/// month-only method, so a locale-aware `DateFormat` skeleton is the minimal
/// acceptable exception (safe — intl date symbols are preloaded by
/// GlobalMaterialLocalizations at boot).
///
/// This row used to have **no width branch at all**, unlike the daily and
/// weekly headers it sits beside, and nothing in it could shrink — the month
/// label was a bare `Text` and the only flexible child was a `Spacer`. On a
/// hosted account with a connected calendar it asked for ~677 px inside a
/// 412 px phone pane and clipped at the right edge, directly above the grid;
/// even self-hosted (where `CalendarConnectMenu` paints nothing) it clipped at
/// 320 px, and at `kTextScaleMax` everywhere. `task_calendar_header_test.dart`
/// sweeps the widths that used to fail.
///
/// [wide] comes from the host screen's `LayoutBuilder` — the **content pane**,
/// not the window — so it agrees with the AppBar and the filter bar by
/// construction. See `taskFiltersInline`.
class TaskCalendarHeader extends StatelessWidget {
  const TaskCalendarHeader({super.key, required this.wide, this.formatter});

  final bool wide;
  final Formatter? formatter;

  /// Everything in the wide row except the month label: two 48 px chevrons,
  /// the 48 + 4 px events toggle, the 280 px account chip (its 200 px address
  /// cap plus the icon, the gap and the ✕), a labelled `Today` and two 8 px
  /// gaps.
  ///
  /// `Today` is counted at its **`kTextScaleMax`** width (80 px, against 65 at
  /// 1x) rather than scaled below, because it is the only other child that
  /// carries text and taking its largest keeps this whole term scale-safe — at
  /// the cost of a gate 15 px conservative at normal scale, which errs toward
  /// the compact address. Every remaining child is an icon button.
  ///
  /// Measured with the bundled Inter Tight, not `flutter test`'s
  /// square-per-glyph substitute, which over-measures text by roughly half —
  /// the whole point of the numbers is that they decide a real layout.
  static const double _wideChromeWithChip = 524;

  /// The widest month label any bundled locale renders at 1x: Spanish
  /// "septiembre de 2026" (145 px, against English "September 2026"'s 121 and
  /// Japanese "2026年9月"'s 64). Scaled by the active text scaler at the call
  /// below — it is the term that actually moves with the setting, `Today`
  /// being pre-counted at its maximum above.
  ///
  /// Measured through `DateFormat.yMMMM`, i.e. the string this row actually
  /// renders; the literal `'MMMM yyyy'` it replaced never produced Spanish's
  /// "de" at all, which is how a number measured off the wrong string came to
  /// gate a real layout.
  static const double _monthLabelWidth = 145;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskCalendarViewModel>();
    final calVm = context.watch<CalendarConnectionViewModel>();
    final tokens = context.inTheme;
    final locale = formatter?.settings.locale;
    // The **skeletons**, never a hand-written `'MMMM yyyy'` / `'MMM yyyy'`:
    // a literal pattern fixes the field order and drops the locale's own
    // connectives, and four of the eleven bundled locales disagree with it.
    // `es` and `pt_BR` write "septiembre de 2026" / "setembro de 2026", so the
    // pattern lost the "de"; `ja` and `zh_CN` put the year first ("2026年9月"),
    // so it rendered a backwards date outright. Several unbundled server
    // languages are worse — a literal `MMMM` takes Polish, Russian, Greek,
    // Finnish and Croatian's *genitive* month ("września 2026", right inside a
    // full date, wrong standing alone) — and `formatter.settings.locale` is the
    // company's language, which is not limited to the bundled set.
    //
    // Narrow drops to the abbreviated month, which is a readability choice
    // rather than an overflow one (the `Expanded` below is what makes overflow
    // impossible): the full name is 145 px in `es`, so on a phone it would
    // ellipsise to nothing, where the 70-90 px abbreviation survives on every
    // phone pane with room for it — `task_calendar_header_test.dart` names the
    // three that have none (a connected account costs a fifth icon button, and
    // 320-360 px minus 48 px of gutters cannot carry five).
    final tag = locale == null || locale.isEmpty ? null : locale;
    final label = (wide ? DateFormat.yMMMM(tag) : DateFormat.yMMM(tag)).format(
      DateTime(vm.month.year, vm.month.month),
    );

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: InSpacing.sm,
      ),
      // A second width read, and deliberately a *local* one: [wide] answers
      // "does this pane get desktop chrome?" for the whole screen, while this
      // answers "is there room for the account address inline?", which only
      // this row can know — it depends on this row's own gutters, its own
      // controls and the active text scale. Reading the constraints inside the
      // padding makes it the content box, so the 24 px gutters are already
      // paid.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // No flex arrangement can rescue the inline chip below this, which
          // is worth knowing before trying: at a 600 px pane the wide row's
          // fixed children already come to 524 of the 552 px content box, so
          // making a child shrink only moves which one gives way. The
          // `Expanded` label alone starved to "…" at a 602 px pane (22 px of
          // the 112 it needed), and adding a `Flexible` around the chip on top
          // of that traded the starvation for a 7 px overflow *inside* the
          // chip at 648 px and 1.4x — it has no flexible child of its own.
          // `RenderFlex` allocates flex proportionally and *before* laying
          // out, so "give the label what it needs and the chip the rest" is
          // not expressible at all.
          //
          // Sized for the *label* rather than the chip, so the invariant this
          // buys is the strong one: on the wide branch the month label is
          // never truncated, and it is the address that steps back into its
          // menu.
          final inlineAccount =
              wide &&
              constraints.maxWidth >=
                  _wideChromeWithChip +
                      MediaQuery.textScalerOf(context).scale(_monthLabelWidth);
          return Row(
            children: [
              IconButton(
                tooltip: context.tr('previous'),
                icon: const Icon(Icons.chevron_left),
                onPressed: vm.prevMonth,
              ),
              IconButton(
                tooltip: context.tr('next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: vm.nextMonth,
              ),
              const SizedBox(width: 8),
              // `Expanded`, not `Text` + `Spacer`: the row's fixed children (two
              // chevrons, the events toggle, the account control, Today) come to
              // ~304 px on a phone, and only a flexible child can absorb whatever
              // is left. This is the change that makes an overflow here impossible
              // rather than merely unlikely — the same shape the daily and weekly
              // headers use for their own labels.
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (calVm.isConnected) ...[
                IconButton(
                  tooltip: context.tr(
                    calVm.hideEvents ? 'show_events' : 'hide_events',
                  ),
                  icon: Icon(
                    calVm.hideEvents
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: calVm.toggleHideEvents,
                ),
                const SizedBox(width: 4),
              ],
              // Never `Flexible`: the chip is either its full inline self or a
              // 48 px icon, and a `Flexible` around it would be wrong in both
              // states. Inline it has no flexible child of its own, so a short
              // allocation overflows *inside* it; compact — and self-hosted, where
              // this widget paints nothing at all — it takes less than its
              // proportional share and `RenderFlex` strands the remainder as
              // trailing space, floating `Today` in from the right gutter.
              CalendarConnectMenu(compact: !inlineAccount),
              const SizedBox(width: 8),
              // Label to icon on narrow — the identical swap `task_daily_header
              // .dart` and `_WeeklyHeader` make for their own Today buttons.
              if (wide)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: vm.goToToday,
                  child: Text(context.tr('today')),
                )
              else
                IconButton(
                  tooltip: context.tr('today'),
                  icon: const Icon(Icons.today_outlined),
                  onPressed: vm.goToToday,
                ),
            ],
          );
        },
      ),
    );
  }
}
