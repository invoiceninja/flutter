import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Generic multi-select for entity references — a row of removable chips
/// plus a [SearchableDropdownField] underneath that adds the picked item to
/// the selection. Works for any `T` (clients, vendors, projects, expense
/// categories, …); the caller supplies the available list and the
/// `idOf`/`displayString` projections.
///
/// Selection is modelled as an ordered `List<String>` of ids and emitted
/// the same way, so it drops straight into setters like
/// `vm.setStatementClients(List<String>)`. An empty list is the wire's
/// "all / no filter" signal.
///
/// Generalized from `MultiProductPicker` (payment-link edit), which predates
/// this and remains CSV-string based for that screen.
class MultiEntityPicker<T extends Object> extends StatelessWidget {
  const MultiEntityPicker({
    super.key,
    required this.labelKey,
    required this.selectedIds,
    required this.items,
    required this.idOf,
    required this.displayString,
    required this.onChanged,
    this.addLabelKey = 'add_item',
  });

  /// Localization key for the field title (e.g. `'clients'`).
  final String labelKey;

  /// Currently-selected ids, in display order.
  final List<String> selectedIds;

  /// All items that *could* be selected. Already-picked ones are filtered
  /// out of the dropdown automatically.
  final List<T> items;

  final String Function(T) idOf;
  final String Function(T) displayString;

  /// Fires with the new id list after an add / remove.
  final ValueChanged<List<String>> onChanged;

  /// Localization key for the "add" dropdown label.
  final String addLabelKey;

  void _add(String id) {
    if (id.isEmpty || selectedIds.contains(id)) return;
    onChanged([...selectedIds, id]);
  }

  void _remove(String id) {
    if (!selectedIds.contains(id)) return;
    onChanged(selectedIds.where((x) => x != id).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    // O(n) lookup is fine — N ≤ a few hundred items.
    final byId = {for (final it in items) idOf(it): it};
    final available = items
        .where((it) => !selectedIds.contains(idOf(it)))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(labelKey),
          style: theme.textTheme.labelMedium?.copyWith(color: tokens.ink3),
        ),
        SizedBox(height: InSpacing.sm),
        if (selectedIds.isNotEmpty) ...[
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            children: [
              for (final id in selectedIds)
                Semantics(
                  // The id stays available to assistive tech: a row of chips
                  // all reading `—`, each with its own delete button, is worse
                  // than the raw id it replaced.
                  label: byId[id] != null ? null : id,
                  child: InputChip(
                    label: Text(
                      // Never the raw id on screen: a hashid is meaningless to
                      // the user in every state, and after an inline create it
                      // would be a `tmp_` token. Alias resolution is the
                      // caller's job — this widget is generic over T with no
                      // repo access.
                      byId[id] != null ? displayString(byId[id] as T) : '—',
                    ),
                    onDeleted: () => _remove(id),
                  ),
                ),
            ],
          ),
          SizedBox(height: InSpacing.md(context)),
        ],
        SearchableDropdownField<T>(
          label: context.tr(addLabelKey),
          items: available,
          initialValue: null,
          displayString: displayString,
          idOf: idOf,
          onChanged: (it) {
            if (it != null) _add(idOf(it));
          },
        ),
      ],
    );
  }
}
