import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Read-only "Custom Fields" card for an entity detail screen.
///
/// Streams the active company, resolves the configured labels/types for
/// `<prefix>1..4`, and renders one row per slot that is both configured and
/// filled (via the shared [customFieldDetailRows]). Collapses to
/// `SizedBox.shrink()` when nothing is configured/filled, so callers can drop
/// it unconditionally into a card list.
///
/// Reusable across entities: pass [prefix] = `'product'` / `'payment'` /
/// `'invoice'` (all billing docs reuse the `invoice` slots) / `'user'`, etc.
/// The four [values] are the entity's `customValue1..4` in order. Pass
/// [formatter] so date-typed slots render in the company's date format (ISO
/// fallback when null).
///
/// This is the extracted, shared form of the per-screen `_CustomFieldsCard`
/// widgets that projects / tasks / expenses grew independently.
class CustomFieldsDetailCard extends StatelessWidget {
  const CustomFieldsDetailCard({
    super.key,
    required this.companyId,
    required this.prefix,
    required this.values,
    this.formatter,
  }) : assert(values.length == 4, 'values must have exactly 4 entries');

  /// Company whose `custom_fields` configuration drives the labels/types.
  final String companyId;

  /// Lookup prefix combined with `1..4` to form keys like `product1`.
  final String prefix;

  /// The entity's `customValue1..4`, in order.
  final List<String> values;

  /// Active company `Formatter` for date-typed slots (ISO fallback when null).
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final yes = context.tr('yes');
    final no = context.tr('no');
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      // Seeded so the card doesn't materialise a frame late and push the rest
      // of the detail body down — it presence-gates on `rows.isEmpty` below.
      initialData: context.read<Services>().company.peek(
        companyId: companyId,
        id: companyId,
      ),
      create: () => context.read<Services>().company.watchCompany(companyId),
      builder: (context, snapshot) {
        final rows = customFieldDetailRows(
          company: snapshot.data,
          prefix: prefix,
          values: values,
          formatter: formatter,
          yes: yes,
          no: no,
        );
        if (rows.isEmpty) return const SizedBox.shrink();
        return DashboardCardShell(
          title: context.tr('custom_fields'),
          child: Column(
            children: [
              for (final r in rows) _Row(label: r.label, value: r.value),
            ],
          ),
        );
      },
    );
  }
}

/// Label / value row, mirroring the per-screen `_Row` helpers
/// (`project_detail_cards_grid.dart:152`) so the card reads identically to the
/// other detail cards.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Narrower label column on phones so the value keeps a usable width.
    final labelWidth = MediaQuery.sizeOf(context).width < 600 ? 104.0 : 160.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.ink3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CopyableValue(
              value: value,
              child: Text(
                value,
                style: TextStyle(fontSize: 13, color: tokens.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
