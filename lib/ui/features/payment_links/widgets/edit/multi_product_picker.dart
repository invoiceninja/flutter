import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Multi-product selector for the Payment Link edit screen's Overview tab.
/// The four product fields (one-time, recurring, optional one-time,
/// optional recurring) all reuse this widget — each instance manages a
/// single comma-separated `String` of product ids.
///
/// UX: a row of Chips showing the currently selected products + a
/// [SearchableDropdownField] underneath that adds the picked product to
/// the list. Removing a chip rewrites the comma-joined string.
///
/// Stays oblivious to the four-category split — the parent passes the
/// pre-filtered list of available products (e.g. excluding already-picked
/// ones) and an `onChanged` callback that writes back to the matching
/// draft field.
class MultiProductPicker extends StatelessWidget {
  const MultiProductPicker({
    super.key,
    required this.labelKey,
    required this.value,
    required this.products,
    required this.onChanged,
  });

  /// Localization key for the field title (e.g. `'products'`).
  final String labelKey;

  /// Comma-separated string of selected product ids.
  final String value;

  /// All products that *could* be selected. The widget filters out
  /// already-picked ones from the dropdown options automatically.
  final List<Product> products;

  /// Fires with the new comma-separated string after add / remove.
  final ValueChanged<String> onChanged;

  List<String> get _selectedIds {
    if (value.isEmpty) return const <String>[];
    return value.split(',').where((s) => s.isNotEmpty).toList(growable: false);
  }

  void _addProduct(String id) {
    if (id.isEmpty) return;
    final current = _selectedIds;
    if (current.contains(id)) return;
    onChanged([...current, id].join(','));
  }

  void _removeProduct(String id) {
    final current = _selectedIds;
    if (!current.contains(id)) return;
    onChanged(current.where((x) => x != id).join(','));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final selected = _selectedIds;
    // O(n) lookup is fine — N ≤ a few hundred products.
    final byId = {for (final p in products) p.id: p};
    final available = products
        .where((p) => !selected.contains(p.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(labelKey),
          style: theme.textTheme.labelMedium?.copyWith(color: tokens.ink3),
        ),
        SizedBox(height: InSpacing.sm),
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            children: [
              for (final id in selected)
                _ProductChip(
                  product: byId[id],
                  fallbackId: id,
                  onDeleted: () => _removeProduct(id),
                ),
            ],
          ),
          SizedBox(height: InSpacing.md(context)),
        ],
        SearchableDropdownField<Product>(
          label: context.tr('add_item'),
          items: available,
          initialValue: null,
          displayString: (p) => p.productKey.isEmpty ? p.id : p.productKey,
          idOf: (p) => p.id,
          onChanged: (p) {
            if (p != null) _addProduct(p.id);
          },
        ),
      ],
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.product,
    required this.fallbackId,
    required this.onDeleted,
  });

  final Product? product;
  final String fallbackId;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    // Never the raw id — see `MultiEntityPicker`. `fallbackId` is kept so the
    // id stays available to screen readers and `debugDumpApp`.
    final label = product?.productKey.isNotEmpty == true
        ? product!.productKey
        : '—';
    final named = product?.productKey.isNotEmpty == true;
    return Semantics(
      // Keyed on whether a NAME was found, not on whether a product was — a
      // found-but-nameless product renders `—` too, and that is exactly the
      // case where the id must survive for screen readers.
      label: named ? label : fallbackId,
      child: InputChip(label: Text(label), onDeleted: onDeleted),
    );
  }
}
