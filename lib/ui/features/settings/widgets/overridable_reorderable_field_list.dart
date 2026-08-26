import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/static/pdf_catalogs.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Cascade-aware multi-select list with drag-to-reorder, backing one slice
/// of `company.settings.pdf_variables` (e.g. `pdf_variables.client_details`).
///
/// The wire shape is `Map<String, List<String>>` — this widget reads / writes
/// the list under [catalog.sectionKey] via [OverridableField.bindInline] (the
/// static binding registry can't enumerate dynamic map keys).
///
/// When the saved list is empty / missing, the catalog's `defaultSelected`
/// renders on first paint; the user's first edit replaces it.
class OverridableReorderableFieldList extends StatelessWidget {
  const OverridableReorderableFieldList({super.key, required this.catalog});

  final PdfVariableCatalog catalog;

  /// Built once at module init — same instance per section key. Inline
  /// closures because the wire schema is a dynamic-keyed sub-map; the static
  /// `settings_field_bindings.dart` registry only handles top-level keys.
  static SettingsBinding bindingFor(String sectionKey) {
    return (
      read: (CompanySettings s) {
        final list = s.pdfVariables?[sectionKey];
        if (list == null) return null;
        // Encode the list as a CSV string so the (String?-typed) override
        // toggle can detect "set vs. unset" via null check. No real callsite
        // calls `read` for the value; the override checkbox only reads it
        // for the "is set" check. A present-but-empty list is an explicit
        // empty override (the user cleared every variable) — return '' so it
        // reads as overridden, not as "inherit from parent" (which only an
        // absent key, `null`, should signal).
        return list.join(',');
      },
      write: (CompanySettings s, String? value) {
        final next = Map<String, List<String>>.from(
          s.pdfVariables ?? const <String, List<String>>{},
        );
        if (value == null) {
          next.remove(sectionKey);
        } else {
          next[sectionKey] = value.isEmpty
              ? const <String>[]
              : value.split(',');
        }
        return s.copyWith(pdfVariables: next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final binding = bindingFor(catalog.sectionKey);
    final saved = host.settings.pdfVariables?[catalog.sectionKey];
    final selected = saved ?? catalog.defaultSelected;

    void write(List<String> list) {
      host.updateSettings((s) => binding.write(s, list.join(',')));
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: InSpacing.md(context)),
            child: Text(
              context.tr('no_records_selected'),
              style: TextStyle(color: context.inTheme.ink3),
            ),
          )
        else
          _ReorderableSelected(
            keys: selected,
            onReorder: (oldIndex, newIndex) {
              final list = [...selected];
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
              write(list);
            },
            onRemove: (key) {
              final list = [...selected]..remove(key);
              write(list);
            },
          ),
        const SizedBox(height: InSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _AddVariableButton(
                available: catalog.available
                    .where((v) => !selected.contains(v))
                    .toList(),
                onPicked: (key) {
                  final list = [...selected, key];
                  write(list);
                },
              ),
            ),
            // Bottom-right per tab: restore the catalog default for this
            // section. Disabled when the list already equals the default so it
            // never pointlessly dirties the draft. Sits inside the
            // `OverridableField.bindInline` child, so at group/client scope it
            // inherits the same override-gating as the rows above.
            Tooltip(
              message: context.tr('use_default'),
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(context.tr('reset')),
                onPressed: listEquals(selected, catalog.defaultSelected)
                    ? null
                    : () => write(catalog.defaultSelected),
              ),
            ),
          ],
        ),
      ],
    );

    return OverridableField.bindInline(
      apiKey: 'pdf_variables.${catalog.sectionKey}',
      label: context.tr(catalog.titleKey),
      binding: binding,
      cascadedValueOnEnable: () => selected.join(','),
      child: body,
    );
  }
}

class _ReorderableSelected extends StatelessWidget {
  const _ReorderableSelected({
    required this.keys,
    required this.onReorder,
    required this.onRemove,
  });

  final List<String> keys;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    // ReorderableListView needs a bounded height; we wrap with
    // shrinkWrap+NeverScroll so the surrounding ListView owns the scrollable.
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: keys.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final key = keys[index];
        return _VariableRow(
          key: ValueKey(key),
          index: index,
          variable: key,
          onRemove: () => onRemove(key),
        );
      },
    );
  }
}

class _VariableRow extends StatelessWidget {
  const _VariableRow({
    super.key,
    required this.index,
    required this.variable,
    required this.onRemove,
  });

  final int index;
  final String variable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = _humanizeVariable(context, variable);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_indicator, color: tokens.ink3, size: 20),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Tooltip(
            message: variable,
            child: Text(
              variable,
              style: TextStyle(
                color: tokens.ink3,
                fontFamily: kMonoFontFamily,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 18,
            tooltip: context.tr('remove'),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddVariableButton extends StatelessWidget {
  const _AddVariableButton({required this.available, required this.onPicked});

  final List<String> available;
  final ValueChanged<String> onPicked;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _AddVariableDialog(available: available),
    );
    if (picked != null && picked.isNotEmpty) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.add),
        label: Text(context.tr('add_field')),
        onPressed: available.isEmpty ? null : () => _open(context),
      ),
    );
  }
}

class _AddVariableDialog extends StatefulWidget {
  const _AddVariableDialog({required this.available});

  final List<String> available;

  @override
  State<_AddVariableDialog> createState() => _AddVariableDialogState();
}

class _AddVariableDialogState extends State<_AddVariableDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.available
        : widget.available
              .where(
                (v) =>
                    v.toLowerCase().contains(_query.toLowerCase()) ||
                    _humanizeVariable(
                      context,
                      v,
                    ).toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();
    return AlertDialog(
      title: Text(context.tr('add_field')),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search),
              ),
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: InSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final v = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text(_humanizeVariable(context, v)),
                    subtitle: Text(
                      v,
                      style: const TextStyle(
                        fontFamily: kMonoFontFamily,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('cancel')),
        ),
      ],
    );
  }
}

/// `$client.first_name` → "First Name"; `$task.line_total` → "Line Total".
///
/// Reuses localization keys when one matches the suffix verbatim (e.g.
/// `'address1'` is already in `en.json`); falls back to title-casing the
/// suffix when no key matches (`tr` returns the key itself on miss).
String _humanizeVariable(BuildContext context, String variable) {
  final dot = variable.indexOf('.');
  final raw = dot < 0 ? variable.substring(1) : variable.substring(dot + 1);
  final keyed = context.tr(raw);
  if (keyed != raw) return keyed;
  return raw
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}
