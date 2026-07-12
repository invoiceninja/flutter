import 'package:flutter/material.dart';

import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Bottom-sheet body for picking + reordering the columns shown on an
/// entity-list screen. Generic on the entity type — every entity reuses
/// this and supplies its own column registry via [allColumns].
///
/// Behaviour:
///   * Top section is the **selected** columns in user order — drag handle
///     reorders, checkbox unticks (moves the column to the lower section).
///   * Bottom section is the **available** columns in registry order — tick
///     to add them to the selected list (appended at the end).
///   * "Reset to defaults" reverts via [onReset] (the caller writes the
///     entity-specific default order).
///   * Apply happens on Done — closing without Done discards.
class EntityColumnPickerSheet<T> extends StatefulWidget {
  const EntityColumnPickerSheet({
    required this.initial,
    required this.allColumns,
    required this.onApply,
    required this.onReset,
    super.key,
  });

  /// Current selection in user order. Ids not in [allColumns] are filtered
  /// out before showing the picker (they still round-trip in storage).
  final List<String> initial;

  /// Every column the entity knows how to render. Order here drives the
  /// "Available" section's display order.
  final List<ColumnDefinition<T>> allColumns;

  final ValueChanged<List<String>> onApply;
  final VoidCallback onReset;

  @override
  State<EntityColumnPickerSheet<T>> createState() =>
      _EntityColumnPickerSheetState<T>();
}

class _EntityColumnPickerSheetState<T>
    extends State<EntityColumnPickerSheet<T>> {
  late List<String> _selected;
  late Map<String, ColumnDefinition<T>> _byId;

  @override
  void initState() {
    super.initState();
    _byId = {for (final c in widget.allColumns) c.id: c};
    // Keep only ids the registry recognises so the user doesn't see opaque
    // entries (unknown ids still round-trip in storage; they're invisible
    // in the picker).
    _selected = [
      for (final id in widget.initial)
        if (_byId.containsKey(id)) id,
    ];
  }

  List<String> get _available => [
    for (final c in widget.allColumns)
      if (!_selected.contains(c.id)) c.id,
  ];

  String _labelFor(BuildContext context, String id) {
    final key = _byId[id]?.labelKey;
    return key == null ? id : context.tr(key);
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.tr('columns'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: _SectionLabel(
                      text: '${context.tr('selected')} (${_selected.length})',
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: _selected.length,
                    onReorderItem: _onReorder,
                    itemBuilder: (context, i) {
                      final id = _selected[i];
                      return _SelectedRow(
                        key: ValueKey('sel-$id'),
                        index: i,
                        id: id,
                        label: _labelFor(context, id),
                        onToggle: () => _toggleOff(id),
                      );
                    },
                  ),
                  if (available.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    SliverToBoxAdapter(
                      child: _SectionLabel(text: context.tr('available')),
                    ),
                    SliverList.builder(
                      itemCount: available.length,
                      itemBuilder: (context, i) {
                        final id = available[i];
                        return CheckboxListTile(
                          key: ValueKey('avail-$id'),
                          value: false,
                          title: Text(_labelFor(context, id)),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => _toggleOn(id),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      widget.onReset();
                      Navigator.of(context).pop();
                    },
                    child: Text(context.tr('reset_to_defaults')),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                  const SizedBox(width: 8),
                  PrimaryDialogAction(
                    label: context.tr('done'),
                    onPressed: () {
                      widget.onApply(List<String>.unmodifiable(_selected));
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }

  void _toggleOff(String id) {
    setState(() => _selected.remove(id));
  }

  void _toggleOn(String id) {
    setState(() => _selected.add(id));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({
    required this.index,
    required this.id,
    required this.label,
    required this.onToggle,
    super.key,
  });

  final int index;
  final String id;
  final String label;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: true,
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (_) => onToggle(),
      secondary: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
    );
  }
}
