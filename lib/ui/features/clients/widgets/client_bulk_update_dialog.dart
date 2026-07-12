import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/industry.dart';
// Flutter's `Size` (buttons) collides with the domain Size model — alias it.
import 'package:admin/data/models/value/size.dart' as size_model;
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/utils/formatting.dart';

/// Result of the client bulk-update dialog: one server `column` and the
/// `new_value` to set on every selected client.
@immutable
class ClientBulkUpdate {
  const ClientBulkUpdate({required this.column, required this.newValue});

  final String column;
  final String newValue;
}

/// The columns `Client::$bulk_update_columns` always allows. `custom_value1..4`
/// are appended only for slots the company has configured a label for.
const List<String> _kStandardColumns = [
  'public_notes',
  'industry_id',
  'size_id',
  'country_id',
];

/// Bulk-update prep dialog for the clients list multiselect: the user picks one
/// whitelisted field, enters/selects a value, and the result is fanned across
/// the selected clients as `MutationKind.bulkUpdate` mutations. Returns null on
/// cancel. Top-level (not a closure) so it stays a const tear-off in the list
/// screen's `bulkActions`.
Future<ClientBulkUpdate?> showClientBulkUpdateDialog(
  BuildContext context,
) async {
  final services = context.read<Services>();
  final companyId = services.auth.currentCompanyId ?? '';
  // Resolve the formatter + a one-shot company snapshot up front so the dialog
  // is fully synchronous. The company's custom-field config is static for the
  // dialog's lifetime, so a value (not a stream) is correct — and it avoids
  // re-subscribing a fresh `watchCompany` stream on every keystroke/rebuild
  // (which would make the value input flicker). The formatter lets date-typed
  // custom fields render in the company's format (ISO fallback when null).
  final formatter = await services.formatterFor(companyId);
  if (!context.mounted) return null;
  final company = await services.company.get(companyId);
  if (!context.mounted) return null;
  return showDialog<ClientBulkUpdate>(
    context: context,
    builder: (_) =>
        _ClientBulkUpdateDialog(company: company, formatter: formatter),
  );
}

class _ClientBulkUpdateDialog extends StatefulWidget {
  const _ClientBulkUpdateDialog({
    required this.company,
    required this.formatter,
  });

  final Company? company;
  final Formatter formatter;

  @override
  State<_ClientBulkUpdateDialog> createState() =>
      _ClientBulkUpdateDialogState();
}

class _ClientBulkUpdateDialogState extends State<_ClientBulkUpdateDialog> {
  /// Selected column wire name; null until the user picks a field.
  String? _column;

  /// Current value for the selected column.
  String _value = '';

  // A non-empty value is required: an empty submit would mass-clear the field
  // (irreversible, no undo), and the server's `new_value` validation is too
  // malformed to rely on. Bulk-clear is intentionally unsupported.
  bool get _canSubmit => _column != null && _value.trim().isNotEmpty;

  void _selectColumn(String? column) => setState(() {
    _column = column;
    _value = ''; // reset so a stale value can't leak across field types
  });

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(
      context,
    ).pop(ClientBulkUpdate(column: _column!, newValue: _value));
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final columns = _availableColumns(widget.company);
    return AlertDialog(
      title: Text(context.tr('bulk_update')),
      content: SizedBox(
        width: 380,
        child: FormSaveScope(
          onSubmit: _submit,
          enabled: _canSubmit,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchableDropdownField<String>(
                label: context.tr('field'),
                items: columns,
                initialValue: _column,
                displayString: (c) => _columnLabel(context, c),
                idOf: (c) => c,
                onChanged: _selectColumn,
              ),
              if (_column != null) ...[
                SizedBox(height: InSpacing.md(context)),
                _buildValueInput(context, services),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('done'),
              enabled: _canSubmit,
              // Column selector is a dropdown and most value inputs don't submit
              // on Enter — so no Enter hint (avoids an untruthful ⏎).
              autofocus: false,
              showEnterHint: false,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  /// Standard four columns + any configured custom-field slots.
  List<String> _availableColumns(Company? company) {
    final columns = [..._kStandardColumns];
    if (company != null) {
      for (var i = 1; i <= 4; i++) {
        if (parseCustomField(
          company.customFields['client$i'],
        ).label.isNotEmpty) {
          columns.add('custom_value$i');
        }
      }
    }
    return columns;
  }

  /// User-facing label for a column wire name (custom slots use the company's
  /// configured label).
  String _columnLabel(BuildContext context, String column) {
    switch (column) {
      case 'public_notes':
        return context.tr('public_notes');
      case 'industry_id':
        return context.tr('industry');
      case 'size_id':
        return context.tr('size_id');
      case 'country_id':
        return context.tr('country');
      default:
        final slot = column.substring('custom_value'.length);
        final company = widget.company;
        final label = company == null
            ? ''
            : parseCustomField(company.customFields['client$slot']).label;
        return label.isEmpty ? column : label;
    }
  }

  /// The value input for the selected column. Keyed by column so switching the
  /// field always rebuilds a fresh control (resets internal text controllers).
  Widget _buildValueInput(BuildContext context, Services services) {
    switch (_column!) {
      case 'public_notes':
        return EntityEditField(
          key: const ValueKey('bulk_public_notes'),
          label: context.tr('public_notes'),
          initial: '',
          minLines: 3,
          maxLines: 6,
          onChanged: (v) => setState(() => _value = v),
        );
      case 'industry_id':
        final items = services.statics.industries.values.toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        return SearchableDropdownField<Industry>(
          key: const ValueKey('bulk_industry'),
          label: context.tr('industry'),
          items: items,
          initialValue: null,
          displayString: (i) => i.name,
          idOf: (i) => i.id,
          onChanged: (i) => setState(() => _value = i?.id ?? ''),
        );
      case 'size_id':
        final items = services.statics.sizes.values.toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        return SearchableDropdownField<size_model.Size>(
          key: const ValueKey('bulk_size'),
          label: context.tr('size_id'),
          items: items,
          initialValue: null,
          displayString: (s) => s.name,
          idOf: (s) => s.id,
          onChanged: (s) => setState(() => _value = s?.id ?? ''),
        );
      case 'country_id':
        final items = services.statics.countries.values.toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        return SearchableDropdownField<Country>(
          key: const ValueKey('bulk_country'),
          label: context.tr('country'),
          items: items,
          initialValue: null,
          displayString: (c) => c.name,
          idOf: (c) => c.id,
          onChanged: (c) => setState(() => _value = c?.id ?? ''),
        );
      default:
        // custom_value1..4 — render inline by configured type. (Mirrors
        // EntityCustomFieldsSection._buildField; inlined so the dialog stays
        // value-based with no per-build company stream to re-subscribe.)
        return _buildCustomValueInput(
          int.parse(_column!.substring('custom_value'.length)),
        );
    }
  }

  /// Inline render of one custom-value slot, by its configured type.
  Widget _buildCustomValueInput(int slot) {
    final parsed = parseCustomField(
      widget.company?.customFields['client$slot'],
    );
    final key = ValueKey('bulk_$_column');
    switch (parsed.type) {
      case kFieldTypeMultiLineText:
        return EntityEditField(
          key: key,
          label: parsed.label,
          initial: '',
          minLines: 3,
          maxLines: 6,
          onChanged: (v) => setState(() => _value = v),
        );
      case kFieldTypeSwitch:
        return Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: Row(
            children: [
              Switch(
                value: isSwitchTruthy(_value),
                onChanged: (v) => setState(
                  () => _value = v ? kSwitchValueYes : kSwitchValueNo,
                ),
              ),
              SizedBox(width: InSpacing.sm),
              Expanded(child: Text(parsed.label)),
            ],
          ),
        );
      case kFieldTypeDate:
        return InDateField(
          key: key,
          labelText: parsed.label,
          formatter: widget.formatter,
          clearable: true,
          value: _value.isEmpty ? null : DateTime.tryParse(_value),
          onChanged: (d) =>
              setState(() => _value = d == null ? '' : _isoDate(d)),
        );
      case kFieldTypeDropdown:
        final items = <String>['', ...parsed.options];
        return SearchableDropdownField<String>(
          key: key,
          label: parsed.label,
          items: items,
          initialValue: '',
          displayString: (o) => o,
          idOf: (o) => o,
          onChanged: (o) => setState(() => _value = o ?? ''),
        );
      case kFieldTypeSingleLineText:
      default:
        return EntityEditField(
          key: key,
          label: parsed.label,
          initial: '',
          onChanged: (v) => setState(() => _value = v),
        );
    }
  }
}

/// ISO `yyyy-MM-dd` — the wire format for date-typed custom values (matches
/// `EntityCustomFieldsSection`).
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
