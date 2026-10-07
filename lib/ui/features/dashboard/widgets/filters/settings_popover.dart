import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';

/// Opens the dashboard's currency picker anchored to whichever widget
/// [context] points at.
///
/// This file used to hold a "Settings" button and a popover carrying currency
/// *and* include-drafts. Both now sit in `DashboardPeriodBar`, above the
/// figures they change and showing their value at rest; what is left here is
/// the picker the currency button opens — a searchable list, because a company
/// can trade in more currencies than a menu should scroll through.
Future<void> openDashboardCurrencyPopover(
  BuildContext context, {
  required DashboardViewModel vm,
}) async {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  final Offset offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = box?.size ?? const Size(160, 32);
  await showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height + 4,
      offset.dx + size.width,
      offset.dy,
    ),
    items: [
      PopupMenuItem<void>(
        enabled: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => DashboardCurrencyForm(vm: vm),
        ),
      ),
    ],
  );
}

/// The currency dropdown: "All currencies" first, then the currencies the
/// company's totals report, alphabetically.
class DashboardCurrencyForm extends StatelessWidget {
  const DashboardCurrencyForm({super.key, required this.vm});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final allLabel = context.tr('all_currencies');
    final options = <_CurrencyOption>[
      _CurrencyOption(id: kDashboardCurrencyAll, name: allLabel),
      ...vm.availableCurrencies.entries
          .map(
            (e) => _CurrencyOption(
              id: int.tryParse(e.key) ?? kDashboardCurrencyAll,
              name: e.value,
            ),
          )
          .where((o) => o.id != kDashboardCurrencyAll)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    ];
    final selected = options.firstWhere(
      (o) => o.id == vm.filter.currencyId,
      orElse: () => options.first,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: SearchableDropdownField<_CurrencyOption>(
          label: context.tr('currency'),
          items: options,
          initialValue: selected,
          displayString: (o) => o.name,
          idOf: (o) => o.id.toString(),
          onChanged: (o) => vm.setCurrency(o?.id ?? kDashboardCurrencyAll),
        ),
      ),
    );
  }
}

class _CurrencyOption {
  const _CurrencyOption({required this.id, required this.name});

  final int id;
  final String name;
}
