import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/task_day_load.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/calendar_weekday_header.dart';
import 'package:admin/utils/formatting.dart';

/// The compact month grid behind the dashboard's task-calendar panel: a
/// weekday strip over six rows of seven day cells, each tinted and bar-filled
/// by how much time is booked on it.
///
/// **Pure by design** — no `Services`, no view model, no stream. Everything it
/// renders arrives as a parameter, so its widget test needs no fakes and cannot
/// hang the way a test over a real Drift watch does. The card next door owns
/// the state.
class TaskCalendarGridMini extends StatelessWidget {
  const TaskCalendarGridMini({
    required this.month,
    required this.gridDays,
    required this.firstDayOfWeek,
    required this.loadByDay,
    required this.today,
    required this.formatter,
    required this.onDayTap,
    super.key,
  }) : assert(
         gridDays.length == 42,
         'build gridDays with monthGridDays — the six-week loop indexes 42',
       );

  /// Any day in the focused month; only its year/month are read.
  final Date month;

  /// Always 42 days — build it with `monthGridDays`, never a count derived
  /// from the month, or the card's height swings between 4 and 6 rows as the
  /// user pages.
  final List<Date> gridDays;

  /// 0 = Sunday … 6 = Saturday, resolved through `calendarFirstDayOfWeek`.
  final int firstDayOfWeek;

  /// Booked duration per day; days absent from the map read as free.
  final Map<Date, Duration> loadByDay;

  final Date today;
  final Formatter formatter;
  final void Function(Date) onDayTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CalendarWeekdayHeaderRow(firstDayOfWeek: firstDayOfWeek),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (final day in gridDays.sublist(week * 7, week * 7 + 7))
                Expanded(
                  child: _LoadDayCell(
                    day: day,
                    booked: loadByDay[day] ?? Duration.zero,
                    inMonth: day.month == month.month && day.year == month.year,
                    isToday: day == today,
                    formatter: formatter,
                    onTap: () => onDayTap(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// One day: the number, a tint, and a proportional load bar.
///
/// The tint answers the issue's literal ask — *colour coded days* — and the bar
/// carries what a three-step tint cannot: a continuous magnitude (5 h and 7 h
/// are both "limited" but visibly different) plus a length cue that survives
/// red-green colour blindness, which is the rule that the colour must never be
/// the only signal.
class _LoadDayCell extends StatelessWidget {
  const _LoadDayCell({
    required this.day,
    required this.booked,
    required this.inMonth,
    required this.isToday,
    required this.formatter,
    required this.onTap,
  });

  final Date day;
  final Duration booked;
  final bool inMonth;
  final bool isToday;
  final Formatter formatter;
  final VoidCallback onTap;

  /// Unscaled: the bar's LENGTH is the signal, so growing its thickness with
  /// the text scaler would only eat the day number's box.
  static const double _barThickness = 3;

  /// A ten-minute entry must still be visible, so a non-zero load never draws
  /// a hairline.
  static const double _minBarFraction = 0.15;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final bucket = dayLoadBucket(booked);
    final hue = _hueFor(bucket, tokens);
    final label = _semanticsLabel(context);

    // The fill rides on this cell's own Material, never on a DecoratedBox
    // inside the InkWell: `_RenderInkFeatures` paints ink features BEFORE its
    // child subtree, so an opaque fill below the ancestor Material swallows the
    // splash — the same mechanism that makes `Ink` banned in this codebase.
    Widget cell = Material(
      // `canvas` (the default) builds a `_MaterialInterior` and an
      // `AnimatedDefaultTextStyle` — two implicit animations per cell, 42 of
      // them on the app's landing route. A free cell has no fill to animate, so
      // it takes `transparency`, which still provides the ink controller the
      // ripple needs.
      type: hue == null ? MaterialType.transparency : MaterialType.canvas,
      color: hue == null
          ? null
          : Color.alphaBlend(hue.withAlpha(_tintAlpha(bucket)), tokens.surface),
      borderRadius: BorderRadius.circular(InRadii.r1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          // `Expanded` already forces this column to fill the cell's fixed
          // height, so `mainAxisSize` / `mainAxisAlignment` would be inert —
          // the number centres in whatever the bar leaves behind.
          child: Column(
            children: [
              Expanded(child: Center(child: _number(context, tokens))),
              const SizedBox(height: 2),
              SizedBox(
                height: _barThickness,
                child: hue == null
                    ? null
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: _barFraction(),
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: hue,
                              borderRadius: BorderRadius.circular(
                                _barThickness / 2,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    // Hover-only: a Tooltip is a StatefulWidget owning an OverlayEntry, and 42
    // of them on the app's landing screen is a real cost for something touch
    // can only reach by a long-press nobody will try. The screen-reader label
    // below carries the same text on every platform.
    // Not gated on the day being booked: "am I free on the 12th?" is the
    // question this panel exists to answer, so the free days are exactly the
    // ones a hover must not stay silent about.
    if (!Env.isTouchPrimary) {
      cell = Tooltip(message: label, child: cell);
    }

    return SizedBox(
      height: miniCalendarCellExtent(
        touch: Env.isTouchPrimary,
        scaler: MediaQuery.textScalerOf(context),
      ),
      // `excludeSemantics` drops the descendant InkWell's tap ACTION along with
      // its text node, so the action has to be re-declared here or the cell
      // becomes a role a screen reader can announce but not activate.
      child: Semantics(
        button: true,
        excludeSemantics: true,
        onTap: onTap,
        label: label,
        child: cell,
      ),
    );
  }

  /// Spoken as decimal hours with a unit, never `H:MM` — "five colon three
  /// zero" carries no unit, and inside a *calendar* it is heard as a clock
  /// time. That is the same ambiguity that keeps hours out of the cell itself.
  String _semanticsLabel(BuildContext context) {
    final date = formatter.date(day.toIso());
    if (booked <= Duration.zero) {
      return '$date, ${context.tr('availability_free')}';
    }
    final value = booked.inMinutes / 60;
    final hours = formatter.decimal(value, maxDecimals: 2);
    // Singular matters here because this label is the *only* representation of
    // the data a screen-reader user gets — "1 hours booked" is the kind of
    // thing a sighted user never sees and a listener cannot ignore.
    final key = value == 1
        ? 'availability_booked_hour'
        : 'availability_booked_hours';
    return '$date, ${context.tr(key, {'hours': hours})}';
  }

  double _barFraction() {
    final f = dayLoadFraction(booked);
    return f < _minBarFraction ? _minBarFraction : f;
  }

  Widget _number(BuildContext context, InTheme tokens) {
    final text = '${day.day}';
    if (isToday) {
      // The same marker the full Tasks calendar paints, scaled down, so the two
      // surfaces mark today identically. `accent` carries "today" here and
      // never the load — which is why the load scale uses the status tokens.
      final size = MediaQuery.textScalerOf(context).scale(18);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tokens.accent, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.onAccent,
            ),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        // Only the NUMBER dims outside the month — the tint and the bar stay at
        // full strength. Dimming the whole cell (as the full-size calendar
        // does) would fade exactly the days this panel exists to answer about:
        // "can you do the 2nd?" lands in the spill row.
        style: TextStyle(
          fontSize: 12,
          color: inMonth ? tokens.ink : tokens.ink3,
        ),
      ),
    );
  }
}

/// Saturated status token per bucket, or null when the day is free.
///
/// Deliberately the status tokens rather than `accent`: none of them is in
/// `CustomToken`, and every preset keeps the hue family, so no user override
/// can invert the scale. `accent` is overridable, and its second stock swatch
/// clamps to near-black in light mode — an accent ramp would be grey-on-grey
/// for that user.
Color? _hueFor(DayLoadBucket bucket, InTheme tokens) => switch (bucket) {
  DayLoadBucket.free => null,
  DayLoadBucket.light => tokens.paid,
  DayLoadBucket.limited => tokens.sent,
  DayLoadBucket.full => tokens.overdue,
};

/// Alpha for the cell tint, blended into the LIVE surface rather than taken
/// from the fixed `*Soft` tokens: `surface` is user-overridable, so a fixed
/// pale-green would sit on an arbitrary background and strand `ink` at
/// unreadable contrast. Blending keeps every cell near whatever surface the
/// user actually chose — `_deriveAccentSoft`'s idiom.
int _tintAlpha(DayLoadBucket bucket) => switch (bucket) {
  DayLoadBucket.free => 0,
  DayLoadBucket.light => 0x1F,
  DayLoadBucket.limited => 0x33,
  DayLoadBucket.full => 0x47,
};

/// Height of one day cell.
///
/// Its own number rather than the date-range picker's: that cell holds a single
/// glyph inside a selection band its comment sizes for, while this one holds a
/// glyph *plus* a bar plus a gap, so one shared constant would be wrong for one
/// of them. Scaled with the text scaler for the reason every extent in this app
/// is — a fixed one slices Inter Tight's descenders past ~1.14x.
///
/// A pure function, not a `BuildContext` read, because `Env.isTouchPrimary` is
/// always true under `flutter test`: no widget test in this repo could see a
/// pointer-platform regression, so the decision is asserted directly instead.
///
/// Takes the [TextScaler] rather than a factor. `TextScaler.scale` returns a
/// scaled *font size*, and the system scaler on Android 14+ is deliberately
/// non-linear — which is why `TextScaler.textScaleFactor` is deprecated — so
/// extracting a multiplier with `scale(1)` samples the curve at 1 px, the
/// least representative point there is, and the extent stops tracking the
/// glyphs it is sized for. Scale the extent directly, as `_dayCellExtent` in
/// the date-range popover does.
///
/// 38 rather than [InSizes.touchTarget]'s 44, knowingly: a day cell cannot grow
/// its *width* to match (seven columns share a card capped at 440), so 44 would
/// leave visibly loose rows around a 12 px number and add 36 px to a card
/// already ~364 px tall on a phone. The date-range popover makes the same trade
/// at 36 for the same reason; 38 is a little more generous because these cells
/// also carry a load bar.
double miniCalendarCellExtent({
  required bool touch,
  required TextScaler scaler,
}) => scaler.scale(touch ? 38.0 : 32.0);
