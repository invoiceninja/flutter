import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';

/// One editable slot in `company.custom_fields` — e.g. `client2` or
/// `surcharge3`. Used by every tab body under
/// `lib/ui/features/settings/views/advanced/custom_fields/`.
///
/// Storage is pipe-delimited: `"<label>|<type>"`. Type segment is one of
/// `single_line_text`, `multi_line_text`, `switch`, `date`, or the dropdown
/// options list (comma-separated, no recognized keyword); an empty suffix
/// (`"Color|"`) is a dropdown with no options yet. A no-pipe legacy value
/// (`"Color"`) hydrates as `multi_line_text` — see `useEffect` in React's
/// `Field.tsx`.
///
/// **Surcharge slots are different**: the value is the raw label (no pipe),
/// the type column is omitted entirely, and a "Charge taxes" Switch on a
/// second line writes to `customSurchargeTaxes<slot>` instead.
class CustomFieldRow<V extends SettingsDraftHost> extends StatefulWidget {
  const CustomFieldRow({
    super.key,
    required this.prefix,
    required this.slot,
    this.enabled = true,
  });

  /// One of `company`, `client`, `contact`, `location`, `product`, `invoice`,
  /// `surcharge`, `payment`, `project`, `task`, `vendor`, `vendor_contact`,
  /// `expense`, `user`.
  final String prefix;

  /// Slot index `1..4`. Combined with [prefix] to form the
  /// `company.custom_fields` map key (e.g. `client2`).
  final int slot;

  /// When `false`, every input renders read-only — used to enforce the
  /// non-Pro plan gate without hiding values the user can still see.
  final bool enabled;

  @override
  State<CustomFieldRow<V>> createState() => _CustomFieldRowState<V>();
}

class _CustomFieldRowState<V extends SettingsDraftHost>
    extends State<CustomFieldRow<V>> {
  late final TextEditingController _label;
  late final TextEditingController _options;
  late final V _vm;

  /// A slot is stored pipe-delimited (`"label|type"`), so a literal `|` in the
  /// label — or in a dropdown option — would corrupt the value for every
  /// client that parses it. Deny it at the input rather than sanitizing later.
  static final List<TextInputFormatter> _denyPipe = [
    FilteringTextInputFormatter.deny(RegExp(r'\|')),
  ];

  String get _key => '${widget.prefix}${widget.slot}';

  bool get _isSurcharge => widget.prefix == 'surcharge';

  @override
  void initState() {
    super.initState();
    _vm = context.read<V>();
    _label = TextEditingController(text: _parsedLabel(_vm));
    _options = TextEditingController(text: _parsedOptions(_vm));
    // The type dropdown self-heals on reset via a value-bearing ValueKey, but
    // these two text controllers are seeded once. Reseed them when the draft
    // returns to its baseline (Discard / post-save / background refresh) so an
    // in-place Discard reverts the visible text too. Guarding on `!isDirty`
    // makes this a no-op during active typing — the draft tracks the
    // controller then, so it never fights the cursor.
    _vm.addListener(_syncFromDraft);
  }

  void _syncFromDraft() {
    if (!mounted || _vm.isDirty) return;
    final label = _parsedLabel(_vm);
    if (_label.text != label) {
      _label.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
    }
    if (_isSurcharge) return;
    final options = _parsedOptions(_vm);
    if (_options.text != options) {
      _options.value = TextEditingValue(
        text: options,
        selection: TextSelection.collapsed(offset: options.length),
      );
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_syncFromDraft);
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  String _rawValue(V vm) => vm.draft?.customFields[_key] ?? '';

  /// Trim each comma-separated dropdown option (keeps empty segments so a
  /// `"Label|"` no-options dropdown round-trips).
  String _normalizeOptions(String raw) =>
      raw.split(',').map((p) => p.trim()).join(',');

  /// Label portion of the stored value. Surcharge slots store the bare label
  /// (an admin-portal one may carry a type suffix — see [surchargeLabel]);
  /// everything else takes the first pipe segment via the shared
  /// [parseCustomField].
  String _parsedLabel(V vm) {
    final raw = _rawValue(vm);
    if (_isSurcharge) return surchargeLabel(raw);
    return parseCustomField(raw).label;
  }

  /// Type code shown in the dropdown. The editor uses `''` for both an empty
  /// slot and single-line text; everything else passes through the shared
  /// [parseCustomField] type (`multi_line_text`, `switch`, `date`, `dropdown`).
  /// A `"Label|"` (empty suffix) surfaces as a dropdown with no options typed
  /// yet; options live in [_parsedOptions].
  String _parsedType(V vm) {
    if (_isSurcharge) return '';
    final parsed = parseCustomField(_rawValue(vm));
    if (parsed.label.isEmpty) return '';
    if (parsed.type == kFieldTypeSingleLineText) return '';
    return parsed.type;
  }

  /// Comma-separated options when the slot is a dropdown; empty otherwise.
  String _parsedOptions(V vm) {
    if (_isSurcharge) return '';
    return parseCustomField(_rawValue(vm)).options.join(',');
  }

  /// Rewrite the slot. Override [label] / [type] / [options] to change one
  /// piece; the rest are read from the current draft.
  ///
  /// Empty label → delete the slot entirely so the server-side
  /// `custom_fields` map doesn't grow stale keys.
  ///
  /// Note on legacy data: a stored `"Color"` (no pipe) parses as
  /// `multi_line_text`. The first edit through this method rewrites it as
  /// `"Color|multi_line_text"` — silent shape upgrade matching React's
  /// `Field.tsx`. Server treats both encodings identically.
  void _write(V vm, {String? label, String? type, String? options}) {
    final draft = vm.draft;
    if (draft == null) return;
    final next = Map<String, String>.from(draft.customFields);
    final newLabel = label ?? _label.text;

    if (_isSurcharge) {
      if (newLabel.isEmpty) {
        next.remove(_key);
        // Clearing the label retires the surcharge slot — also reset the
        // paired "charge taxes" boolean so the server doesn't keep a flag
        // pointing at a non-existent slot.
        vm.updateCompany(
          (c) => _writeSurchargeTax(
            c,
            widget.slot,
            false,
          ).copyWith(customFields: next),
        );
        return;
      } else {
        next[_key] = newLabel;
      }
    } else {
      final newType = type ?? _parsedType(vm);
      final newOptions = options ?? _options.text;
      final suffix = switch (newType) {
        // Single-line text persists with the explicit `single_line_text`
        // keyword (the React / admin-portal canonical encoding). A bare
        // label would re-parse as `multi_line_text` — see `_parsedType` and
        // `handleChange` in React's `Field.tsx`.
        '' => 'single_line_text',
        // Normalize the comma-separated options — trim each entry so stored
        // values don't carry stray spaces (which would surface as padded
        // option labels on entity dropdowns / in other clients). Matches
        // React + admin-portal's `split(',').map(trim).join(',')`.
        'dropdown' => _normalizeOptions(newOptions),
        _ => newType,
      };
      // Empty label retires the slot, regardless of type/options — mirrors
      // React's `useHandleCustomFieldChange` (`if (label === '') delete`).
      if (newLabel.isEmpty) {
        next.remove(_key);
      } else {
        // Always keep the pipe. The only empty `suffix` here is a dropdown
        // with no options yet → stored as `"Label|"`, which `_parsedType`
        // reads back as a dropdown (so the options field stays visible). A
        // bare label would re-parse as multi-line text.
        next[_key] = '$newLabel|$suffix';
      }
    }
    vm.updateCompany((c) => c.copyWith(customFields: next));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<V>();

    final labelField = TextField(
      controller: _label,
      enabled: widget.enabled,
      inputFormatters: _denyPipe,
      decoration: InputDecoration(
        labelText: '${context.tr('label')} ${widget.slot}',
      ),
      onChanged: (v) => _write(vm, label: v),
    );

    if (_isSurcharge) {
      return _SurchargeLayout(
        slot: widget.slot,
        enabled: widget.enabled,
        labelField: labelField,
        vm: vm,
      );
    }

    final type = _parsedType(vm);
    final isDropdown = type == 'dropdown';
    // Drift the widget key with the resolved `type` so external state changes
    // (e.g. `vm.reset()` reverting a Discard) remount the dropdown with the
    // fresh `initialValue`. Flutter's `DropdownButtonFormField` only reads
    // `initialValue` on first mount — without a value-bearing key the UI
    // would stay stale after a non-user-driven reset. Same idiom as
    // `tax_settings_body.dart:195`.
    final selectedType = switch (type) {
      'multi_line_text' || 'switch' || 'date' || 'dropdown' => type,
      _ => '',
    };
    final typeField = DropdownButtonFormField<String>(
      key: ValueKey('type-${widget.prefix}${widget.slot}-$selectedType'),
      decoration: InputDecoration(labelText: context.tr('field_type')),
      initialValue: selectedType,
      // Fill the column and ellipsize a long selected label instead of
      // overflowing — the dropdown sits in an `Expanded` in the wide
      // three-column (label / type / options) layout.
      isExpanded: true,
      // Literal-key calls keep `search_catalog_consistency_test` happy — its
      // regex scans for `context.tr('<key>')` at parse time.
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(context.tr('single_line_text')),
        ),
        DropdownMenuItem(
          value: 'multi_line_text',
          child: Text(context.tr('multi_line_text')),
        ),
        DropdownMenuItem(value: 'switch', child: Text(context.tr('switch'))),
        DropdownMenuItem(value: 'date', child: Text(context.tr('date'))),
        DropdownMenuItem(
          value: 'dropdown',
          child: Text(context.tr('dropdown')),
        ),
      ],
      onChanged: widget.enabled ? (v) => _write(vm, type: v ?? '') : null,
    );
    final optionsField = TextField(
      controller: _options,
      enabled: widget.enabled,
      inputFormatters: _denyPipe,
      decoration: InputDecoration(hintText: context.tr('comma_sparated_list')),
      onChanged: (v) => _write(vm, options: v),
    );

    // Wide: label / type [/ options when dropdown]
    // Narrow: stacked
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!Breakpoints.isWide(constraints)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelField,
              SizedBox(height: InSpacing.sm),
              typeField,
              if (isDropdown) ...[SizedBox(height: InSpacing.sm), optionsField],
            ],
          );
        }
        final rightColumn = isDropdown
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: typeField),
                  SizedBox(width: InSpacing.md(context)),
                  Expanded(child: optionsField),
                ],
              )
            : typeField;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: labelField),
            SizedBox(width: InSpacing.md(context)),
            Expanded(flex: 3, child: rightColumn),
          ],
        );
      },
    );
  }
}

/// Surcharge slot: label on top, "Charge taxes" Switch below (visible only
/// when company-wide tax rates are enabled). The toggle writes to
/// `customSurchargeTaxes<slot>`, not to the `customFields` map.
class _SurchargeLayout<V extends SettingsDraftHost> extends StatelessWidget {
  const _SurchargeLayout({
    required this.slot,
    required this.enabled,
    required this.labelField,
    required this.vm,
  });

  final int slot;
  final bool enabled;
  final Widget labelField;
  final V vm;

  bool _readSwitch(Company draft) => switch (slot) {
    1 => draft.customSurchargeTaxes1,
    2 => draft.customSurchargeTaxes2,
    3 => draft.customSurchargeTaxes3,
    4 => draft.customSurchargeTaxes4,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final showSwitch = draft != null && draft.enabledTaxRates != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labelField,
        if (showSwitch)
          Padding(
            padding: EdgeInsets.only(top: InSpacing.sm),
            child: Row(
              children: [
                Switch(
                  value: _readSwitch(draft),
                  onChanged: enabled
                      ? (v) => vm.updateCompany(
                          (c) => _writeSurchargeTax(c, slot, v),
                        )
                      : null,
                ),
                SizedBox(width: InSpacing.sm),
                Flexible(
                  child: Text(
                    context.tr('charge_taxes'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Per-slot writer for the four `customSurchargeTaxes<n>` booleans. Lives
/// outside the widget so the row's `_write` can clear the boolean when the
/// label is emptied without depending on the surcharge layout being mounted.
Company _writeSurchargeTax(Company c, int slot, bool value) => switch (slot) {
  1 => c.copyWith(customSurchargeTaxes1: value),
  2 => c.copyWith(customSurchargeTaxes2: value),
  3 => c.copyWith(customSurchargeTaxes3: value),
  4 => c.copyWith(customSurchargeTaxes4: value),
  _ => c,
};
