import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys exported for the settings sidebar search. Colocated with the
/// screen so adding / renaming a field updates both ends in one place.
const kTaxRatesSearchKeys = <String>['tax_rates', 'name', 'rate'];

/// `/settings/tax_rates` — manage the company's tax-rate registry. Tap a
/// row to edit; tap "+ New tax rate" to create. The per-company *default*
/// rate pickers live on the Tax Settings screen; this screen manages the
/// underlying list those pickers choose from.
class TaxRatesScreen extends StatelessWidget {
  const TaxRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.taxRates;
    // Decimal-separator setting so the rate reads "19%" / "19,5%" instead of a
    // raw `double.toString()` ("19.0%"), matching the pickers on Tax Settings.
    final useComma =
        services.formatterIfReady(companyId)?.settings.useCommaAsDecimalPlace ??
        false;

    return SettingsEntityListScaffold<TaxRate>(
      titleKey: 'tax_rates',
      sectionTitleKey: 'tax_rates',
      newRoute: '/settings/tax_rates/new',
      newLabelKey: 'new_tax_rate',
      emptyIcon: Icons.percent_outlined,
      emptyTitleKey: 'no_tax_rates',
      emptyHintKey: 'no_tax_rates_hint',
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      streamKey: companyId,
      stream: () => repo.watchAll(companyId: companyId),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf: (t) => t.isDeleted,
      rowBuilder: (t) =>
          _TaxRateRow(key: ValueKey(t.id), rate: t, useComma: useComma),
    );
  }
}

class _TaxRateRow extends StatelessWidget {
  const _TaxRateRow({required this.rate, required this.useComma, super.key});

  final TaxRate rate;
  final bool useComma;

  @override
  Widget build(BuildContext context) {
    final displayName = rate.name.trim().isEmpty
        ? context.tr('untitled')
        : rate.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(displayName),
          subtitle: Text(
            '${rateInputText(rate.rate, useCommaAsDecimalPlace: useComma, blankZero: false)}%',
          ),
          trailing: rate.isDirty
              ? const UnsyncedPill()
              : const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/tax_rates/${rate.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
