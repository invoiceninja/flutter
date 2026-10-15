import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/industry.dart';
// Flutter's `Size` (buttons) collides with the domain Size model — alias it.
import 'package:admin/data/models/value/size.dart' as size_model;
import 'package:admin/domain/bulk_update_columns.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/assigned_user_picker_field.dart';
import 'package:admin/ui/core/widgets/client_picker_field.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_picker_field.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/notes_html.dart';

/// Result of the Bulk Update dialog: one server `column` and the `new_value`
/// to set on every selected record.
@immutable
class BulkUpdate {
  const BulkUpdate({
    required this.column,
    required this.newValue,
    this.projectClientId,
  });

  final String column;
  final String newValue;

  /// For `project_id`: the picked project's client, which the server moves
  /// the record onto along with it — so the local write can show it too.
  final String? projectClientId;
}

/// Whether the list multiselect for [entity] (`kBulkUpdate*`) offers Bulk
/// Update at all: the server lists at least one column this app renders, and
/// for tasks the server is one whose task `bulk_update` doesn't 500 (fixed in
/// 5.13.44, `ServerFeatures.taskBulkUpdate`).
bool bulkUpdateOffered(Services services, String entity) {
  if (entity == kBulkUpdateTask &&
      !ServerFeatures.supports(
        services.serverVersion.value,
        ServerFeatures.taskBulkUpdate,
        isHosted: services.auth.session.value?.isHosted ?? false,
      )) {
    return false;
  }
  final columns =
      services.statics.bulkUpdateColumns(entity) ??
      (entity == kBulkUpdateClient ? kLegacyClientBulkUpdateColumns : null) ??
      const <String>[];
  return columns.any((c) => bulkUpdateValueKind(entity, c) != null);
}

/// Bulk-update prep dialog for a list multiselect: the user picks one
/// whitelisted field, enters / selects a value, and the result is fanned
/// across the selection as `MutationKind.bulkUpdate` mutations. Returns null
/// on cancel.
///
/// [entity] is a `kBulkUpdate*` key. The fields offered are the server's own
/// whitelist (`statics.bulk_updates`) narrowed by [availableBulkUpdateColumns]
/// to the ones this app renders, the tax slots the company has turned on and
/// the custom fields it has labelled.
Future<BulkUpdate?> showBulkUpdateDialog(
  BuildContext context, {
  required String entity,
}) async {
  final services = context.read<Services>();
  final companyId = services.auth.currentCompanyId ?? '';
  // Resolve everything up front so the dialog is synchronous: the company's
  // custom-field config and tax rates are static for its lifetime, and a
  // per-build stream would re-subscribe on every keystroke and flicker the
  // value input. The formatter renders date-typed custom fields in the
  // company's format (ISO fallback when null).
  final formatter = await services.formatterFor(companyId);
  if (!context.mounted) return null;
  final company = await services.company.get(companyId);
  if (!context.mounted) return null;
  final prefix = bulkUpdateCustomFieldPrefix(entity);
  final columns = availableBulkUpdateColumns(
    entity,
    serverColumns: services.statics.bulkUpdateColumns(entity),
    enabledTaxRates: entity == kBulkUpdateExpense
        ? company?.enabledExpenseTaxRates ?? 0
        : company?.enabledTaxRates ?? 0,
    customFieldLabels: {
      for (var i = 1; i <= 4; i++)
        '$prefix$i': parseCustomField(company?.customFields['$prefix$i']).label,
    },
  );
  final needsTaxRates = columns.any(
    (c) => bulkUpdateValueKind(entity, c) == BulkUpdateValueKind.tax,
  );
  final taxRates = needsTaxRates
      ? await services.taxRates.watchAll(companyId: companyId).first
      : const <TaxRate>[];
  if (!context.mounted) return null;
  return showDialog<BulkUpdate>(
    context: context,
    builder: (_) => _BulkUpdateDialog(
      entity: entity,
      companyId: companyId,
      columns: columns,
      company: company,
      formatter: formatter,
      taxRates: [
        for (final r in taxRates)
          if (!r.isDeleted && r.archivedAt == null) r,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    ),
  );
}

class _BulkUpdateDialog extends StatefulWidget {
  const _BulkUpdateDialog({
    required this.entity,
    required this.companyId,
    required this.columns,
    required this.company,
    required this.formatter,
    required this.taxRates,
  });

  final String entity;
  final String companyId;
  final List<String> columns;
  final Company? company;
  final Formatter formatter;
  final List<TaxRate> taxRates;

  @override
  State<_BulkUpdateDialog> createState() => _BulkUpdateDialogState();
}

class _BulkUpdateDialogState extends State<_BulkUpdateDialog> {
  /// Selected column wire name; null until the user picks a field.
  String? _column;

  /// Current value for the selected column.
  String _value = '';

  String? _projectClientId;

  BulkUpdateValueKind? get _kind =>
      _column == null ? null : bulkUpdateValueKind(widget.entity, _column!);

  // A non-empty value is required: an empty submit would mass-clear the field
  // (irreversible, no undo), and the server's `new_value` validation is too
  // malformed to rely on. Bulk-clear is intentionally unsupported — a toggle
  // and the two fixed choices always carry a value, so they are never blank.
  bool get _canSubmit => _column != null && _value.trim().isNotEmpty;

  void _selectColumn(String? column) => setState(() {
    _column = column;
    _projectClientId = null;
    // Reset so a stale value can't leak across field types; a control that
    // always shows a value starts on the one it shows.
    _value = switch (_kind) {
      BulkUpdateValueKind.toggle => '0',
      BulkUpdateValueKind.remainingCycles => '-1',
      _ => '',
    };
  });

  void _submit() {
    if (!_canSubmit) return;
    // Rich-text notes / terms / footer are HTML on the wire — React edits them
    // with a rich editor and every consumer renders the stored string as
    // markup, so a typed line break would vanish (invoiceninja/flutter#159).
    // The field itself stays plain text: a WYSIWYG editor inside a dialog buys
    // nothing here, and the value is short. Markdown is deliberately *not*
    // interpreted, so a note reading `5 * 3 * 2` writes exactly that.
    final newValue = _kind == BulkUpdateValueKind.html
        ? htmlFromPlainText(_value)
        : _value;
    Navigator.of(context).pop(
      BulkUpdate(
        column: _column!,
        newValue: newValue,
        projectClientId: _projectClientId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
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
                items: widget.columns,
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
            SizedBox(width: InSpacing.md(context)),
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

  String _customFieldKey(String column) => column.replaceFirst(
    'custom_value',
    bulkUpdateCustomFieldPrefix(widget.entity),
  );

  /// User-facing label for a column wire name (custom slots use the company's
  /// configured label).
  String _columnLabel(BuildContext context, String column) {
    if (column.startsWith('custom_value')) {
      final label = parseCustomField(
        widget.company?.customFields[_customFieldKey(column)],
      ).label;
      return label.isEmpty ? column : label;
    }
    return context.tr(bulkUpdateLabelKey(column));
  }

  /// The value input for the selected column. Keyed by column so switching the
  /// field always rebuilds a fresh control (resets internal text controllers).
  Widget _buildValueInput(BuildContext context, Services services) {
    final column = _column!;
    final key = ValueKey('bulk_$column');
    final label = _columnLabel(context, column);
    void set(String v) => setState(() => _value = v);
    switch (_kind!) {
      case BulkUpdateValueKind.text:
      case BulkUpdateValueKind.html:
        return EntityEditField(
          key: key,
          label: label,
          initial: '',
          minLines: 3,
          maxLines: 6,
          onChanged: set,
          textCapitalization: TextCapitalization.sentences,
        );
      case BulkUpdateValueKind.industry:
        return SearchableDropdownField<Industry>(
          key: key,
          label: label,
          items: _byName(services.statics.industries.values, (i) => i.name),
          initialValue: null,
          displayString: (i) => i.name,
          idOf: (i) => i.id,
          onChanged: (i) => set(i?.id ?? ''),
        );
      case BulkUpdateValueKind.size:
        return SearchableDropdownField<size_model.Size>(
          key: key,
          label: label,
          items: _byName(services.statics.sizes.values, (s) => s.name),
          initialValue: null,
          displayString: (s) => s.name,
          idOf: (s) => s.id,
          onChanged: (s) => set(s?.id ?? ''),
        );
      case BulkUpdateValueKind.country:
        return SearchableDropdownField<Country>(
          key: key,
          label: label,
          items: _byName(services.statics.countries.values, (c) => c.name),
          initialValue: null,
          displayString: (c) => c.name,
          idOf: (c) => c.id,
          onChanged: (c) => set(c?.id ?? ''),
        );
      case BulkUpdateValueKind.customField:
        return _buildCustomValueInput(key, column);
      case BulkUpdateValueKind.tax:
        return SearchableDropdownField<TaxRate>(
          key: key,
          label: label,
          items: widget.taxRates,
          initialValue: null,
          displayString: (r) => '${r.name} ${widget.formatter.percent(r.rate)}',
          idOf: (r) => r.id,
          onChanged: (r) =>
              set(r == null ? '' : bulkUpdateTaxValue(r.name, r.rate)),
        );
      case BulkUpdateValueKind.toggle:
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _value == '1',
          onChanged: (v) => set(v ? '1' : '0'),
        );
      case BulkUpdateValueKind.remainingCycles:
        return SearchableDropdownField<String>(
          key: key,
          label: label,
          items: ['-1', for (var i = 0; i <= 36; i++) '$i'],
          initialValue: _value,
          displayString: (v) => v == '-1' ? context.tr('endless') : v,
          idOf: (v) => v,
          onChanged: (v) => set(v ?? '-1'),
        );
      case BulkUpdateValueKind.autoBill:
        // Labels match the recurring invoice form's: `always` reads
        // "Enabled", as React labels it.
        return DropdownButtonFormField<String>(
          key: key,
          initialValue: _value.isEmpty ? null : _value,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem(value: 'off', child: Text(context.tr('off'))),
            DropdownMenuItem(
              value: 'always',
              child: Text(context.tr('enabled')),
            ),
            DropdownMenuItem(
              value: 'optout',
              child: Text(context.tr('opt_out')),
            ),
            DropdownMenuItem(value: 'optin', child: Text(context.tr('opt_in'))),
          ],
          onChanged: (v) => set(v ?? ''),
        );
      case BulkUpdateValueKind.taskStatus:
        return TaskStatusPickerField(
          key: key,
          companyId: widget.companyId,
          selectedId: _value,
          onChanged: set,
        );
      case BulkUpdateValueKind.user:
        return AssignedUserPickerField(
          key: key,
          companyId: widget.companyId,
          selectedId: _value,
          onChanged: set,
        );
      case BulkUpdateValueKind.client:
        return ClientPickerField(
          key: key,
          companyId: widget.companyId,
          selectedClientId: _value,
          onSelected: (c) => set(c?.id ?? ''),
        );
      case BulkUpdateValueKind.project:
        return EntityPickerField<Project>(
          key: key,
          label: label,
          cacheKey: widget.companyId,
          selectedId: _value,
          itemsStream: () => services.projects.watchPage(
            companyId: widget.companyId,
            loadedPages: 100,
          ),
          watchById: (id) =>
              services.projects.watch(companyId: widget.companyId, id: id),
          displayString: (p) => p.name.isEmpty ? p.id : p.name,
          idOf: (p) => p.id,
          onChanged: (p) => setState(() {
            _value = p?.id ?? '';
            _projectClientId = p?.clientId;
          }),
        );
    }
  }

  /// Inline render of one custom-value slot, by its configured type. (Mirrors
  /// EntityCustomFieldsSection._buildField; inlined so the dialog stays
  /// value-based with no per-build company stream to re-subscribe.)
  Widget _buildCustomValueInput(Key key, String column) {
    final parsed = parseCustomField(
      widget.company?.customFields[_customFieldKey(column)],
    );
    void set(String v) => setState(() => _value = v);
    switch (parsed.type) {
      case kFieldTypeMultiLineText:
        return EntityEditField(
          key: key,
          label: parsed.label,
          initial: '',
          minLines: 3,
          maxLines: 6,
          onChanged: set,
        );
      case kFieldTypeSwitch:
        return Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: Row(
            children: [
              Switch(
                value: isSwitchTruthy(_value),
                onChanged: (v) => set(v ? kSwitchValueYes : kSwitchValueNo),
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
          onChanged: (d) => set(d == null ? '' : _isoDate(d)),
        );
      case kFieldTypeDropdown:
        return SearchableDropdownField<String>(
          key: key,
          label: parsed.label,
          items: <String>['', ...parsed.options],
          initialValue: '',
          displayString: (o) => o,
          idOf: (o) => o,
          onChanged: (o) => set(o ?? ''),
        );
      case kFieldTypeSingleLineText:
      default:
        return EntityEditField(
          key: key,
          label: parsed.label,
          initial: '',
          onChanged: set,
        );
    }
  }
}

List<T> _byName<T>(Iterable<T> items, String Function(T) name) =>
    items.toList()
      ..sort((a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()));

/// ISO `yyyy-MM-dd` — the wire format for date-typed custom values (matches
/// `EntityCustomFieldsSection`).
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
