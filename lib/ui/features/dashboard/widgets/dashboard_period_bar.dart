import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/value/dashboard_comparison.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/converted_hint.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/settings_popover.dart';
import 'package:admin/utils/formatting.dart';

/// The controls that decide what the period figures and the chart cover: the
/// date range, the currency, and whether drafts count — sitting directly above
/// the things they change.
///
/// They used to live in the page's top bar, and two of them behind a cog
/// labelled "Settings". Up there the range read as a filter on the whole page,
/// but the needs-attention band and the list panels are about *now* and ignore
/// it; and a control you have to open to learn its state is a control you
/// forget is set. Here each one shows its value at rest, and the period the
/// trends compare with is named once, beside the range it derives from.
///
/// **Currency is drawn only when there is a choice** — the company's totals
/// carry a second currency, or one is already selected — and never on the
/// strength of totals that have not loaded: the old dropdown fell back to
/// every currency in the catalogue until they did.
class DashboardPeriodBar extends StatelessWidget {
  const DashboardPeriodBar({
    super.key,
    required this.vm,
    required this.formatter,
    this.compact = false,
  });

  final DashboardViewModel vm;
  final Formatter formatter;

  /// The narrow arrangement: the controls on one wrapping row and what they
  /// resolve to — the windows compared, the conversion — as a caption beneath.
  ///
  /// Inline, as the wide layout has them, each control and its note is too
  /// wide to share a phone's row with the next, so the block came to three
  /// rows of 44 px to say what one row and a line can. Passed by the host
  /// rather than measured: the body already knows which layout it is.
  final bool compact;

  /// "Oct 1 - Oct 7 vs Sep 1 - Sep 7": the days the trends measure, and the
  /// days they measure them against.
  ///
  /// The first half is what a preset's name leaves unsaid — "This Month" on
  /// the 7th is seven days, set against the first seven of the month before
  /// (flutter#37 was a header that named only the window's last month). A
  /// custom range already prints its own dates on the button, so there it is
  /// only the compared window that needs saying.
  String _windows(BuildContext context, DashboardComparison comparison) {
    final previous = formatter.dateRange(
      comparison.previousStart.toIso(),
      comparison.previousEnd.toIso(),
    );
    if (vm.filter.range is DashboardCustomRange) {
      return context.tr('compared_with_range', {'range': previous});
    }
    return context.tr('period_vs_period', {
      'current': formatter.dateRange(
        comparison.currentStart.toIso(),
        comparison.currentEnd.toIso(),
      ),
      'previous': previous,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final comparison = vm.comparison;
    final showCurrency =
        vm.filter.currencyId != kDashboardCurrencyAll ||
        hasForeignCurrency(vm.totals.data, formatter.settings.currencyId);
    final converted = convertedToBaseCaption(
      context,
      selectedCurrencyId: vm.filter.currencyId,
      totals: vm.totals.data,
      formatter: formatter,
    );
    final caption = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: tokens.ink2);
    final range = DateRangePickerButton(
      current: vm.filter.range,
      onChange: vm.setDateRange,
      formatter: formatter,
    );
    final windows = comparison == null ? null : _windows(context, comparison);

    if (compact) {
      final notes = [?windows, ?converted].join(' · ');
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: InSpacing.md(context),
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              range,
              if (showCurrency) _CurrencyButton(vm: vm),
              IncludeDraftsSwitch(vm: vm),
            ],
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(notes, style: caption),
            ),
        ],
      );
    }

    return Wrap(
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        range,
        if (windows != null) Text(windows, style: caption),
        if (showCurrency) _CurrencyButton(vm: vm),
        // Said once, beside the control it is about: under "All currencies"
        // the figures and the chart below are the server's conversion into
        // the company's own currency. It used to be repeated under each card.
        if (converted != null) Text(converted, style: caption),
        IncludeDraftsSwitch(vm: vm),
      ],
    );
  }
}

/// The selected currency, as a button that opens the (searchable) picker.
class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({required this.vm});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final id = vm.filter.currencyId;
    final name = id == kDashboardCurrencyAll
        ? context.tr('all_currencies')
        : (vm.availableCurrencies['$id'] ?? context.tr('currency'));
    return Builder(
      builder: (anchor) => TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: tokens.ink2,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InRadii.r2),
            side: BorderSide(color: tokens.border),
          ),
        ),
        icon: const Icon(Icons.payments_outlined, size: 14),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        onPressed: () => openDashboardCurrencyPopover(anchor, vm: vm),
      ),
    );
  }
}

/// "Include Drafts" as a label and a switch — its state visible without
/// opening anything.
///
/// The server applies it to the totals (`totals_v2`) and to nothing else, so it
/// sits with the figures and is not offered as if it re-scoped the chart or the
/// lists (`BACKEND.md`).
class IncludeDraftsSwitch extends StatelessWidget {
  const IncludeDraftsSwitch({super.key, required this.vm});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final on = vm.filter.includeDrafts;
    return Tooltip(
      message: context.tr('count_unsent_in_totals'),
      child: _control(context, tokens, on),
    );
  }

  Widget _control(BuildContext context, InTheme tokens, bool on) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact on a pointer so the row stays one line; the touch theme's
            // own switch size stands on touch.
            Transform.scale(
              scale: Env.isTouchPrimary ? 1 : 0.8,
              child: Switch.adaptive(
                value: on,
                onChanged: vm.setIncludeDrafts,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // A larger target for a finger only: the merged node already
              // carries the switch's own toggle action.
              excludeFromSemantics: true,
              onTap: () => vm.setIncludeDrafts(!on),
              child: Text(
                context.tr('include_drafts'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
