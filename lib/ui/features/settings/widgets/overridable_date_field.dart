import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';
import 'package:admin/utils/formatting.dart';

/// Date-only counterpart of [OverridableTextField]. The settings cascade
/// stores the value as an ISO `"YYYY-MM-DD"` string (matches the
/// server's `date_format` wire shape and the [Date] type's `toIso()`).
/// Empty string means "no value" / "inherit from parent."
///
/// The display uses [Formatter.date] so the user sees their company's
/// configured format; the stored value stays ISO so the cascade stays
/// portable across company date-format choices.
///
/// Wraps [InDateField] for typed entry + shortcuts (`today`, `+7`) with a
/// calendar-picker fallback, per CLAUDE.md § Forms — single-date inputs use
/// `InDateField`, not `showDatePicker` directly.
class OverridableDateField extends StatelessWidget {
  const OverridableDateField({
    super.key,
    required this.label,
    required this.apiKey,
    required this.formatter,
    this.read,
    this.write,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final String apiKey;

  /// User's company-scoped [Formatter] — used for the display string.
  /// Storage stays ISO regardless. Pass `services.formatterFor(companyId)`.
  final Formatter formatter;
  final SettingsRead? read;
  final SettingsWrite? write;
  final bool enabled;

  /// `showDatePicker` bounds. Default to 1900-2100 — matches `flutter`'s
  /// default scaffold.
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final binding = settingsBindingOf(apiKey);
    final readFn = read ?? binding.read;
    final writeFn = write ?? binding.write;

    final host = context.watch<SettingsDraftHost>();
    final raw = readFn(host.settings) ?? '';
    final parsed = Date.tryParse(raw);
    final errors = host.fieldErrors[apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;

    final dateField = InDateField(
      value: parsed?.toDateTime(),
      formatter: formatter,
      labelText: label,
      enabled: enabled,
      firstDate: firstDate,
      lastDate: lastDate,
      onChanged: (picked) {
        final iso = picked == null
            ? ''
            : Date(picked.year, picked.month, picked.day).toIso();
        host.updateSettings((s) => writeFn(s, iso));
      },
    );

    // InDateField has no `errorText` slot, so surface 422s in a standalone
    // line below it — same style as OverridableSwitchField (12pt, error color).
    final field = errorText == null
        ? dateField
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              dateField,
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: InSpacing.md(context),
                  top: InSpacing.xs,
                ),
                child: Text(
                  errorText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );

    return OverridableField.bind(
      apiKey: apiKey,
      label: label,
      cascadedValueOnEnable: () => readFn(host.settings) ?? '',
      child: field,
    );
  }
}
