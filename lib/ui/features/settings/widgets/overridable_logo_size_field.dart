import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/static/pdf_catalogs.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/field_text_direction.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Composite cascade-aware editor for `company.settings.company_logo_size`.
///
/// The wire value is a single string like `"100%"` or `"80px"`. Internally
/// we split into a numeric `TextField` + a `SegmentedButton<String>` for the
/// unit; one [OverridableField] checkbox covers the pair.
class OverridableLogoSizeField extends StatefulWidget {
  const OverridableLogoSizeField({
    super.key,
    this.apiKey = 'company_logo_size',
  });

  final String apiKey;

  @override
  State<OverridableLogoSizeField> createState() =>
      _OverridableLogoSizeFieldState();
}

class _OverridableLogoSizeFieldState extends State<OverridableLogoSizeField> {
  late final TextEditingController _controller;
  String? _lastValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _numericPart(_readRaw()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _readRaw() {
    final host = context.read<SettingsDraftHost>();
    final binding = settingsBindingOf(widget.apiKey);
    return binding.read(host.settings);
  }

  static String _numericPart(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final s = raw.endsWith(LogoSizeUnit.pixels)
        ? raw.substring(0, raw.length - LogoSizeUnit.pixels.length)
        : raw.endsWith(LogoSizeUnit.percent)
        ? raw.substring(0, raw.length - LogoSizeUnit.percent.length)
        : raw;
    return s.trim();
  }

  static String _unitPart(String? raw) {
    if (raw != null && raw.endsWith(LogoSizeUnit.pixels)) {
      return LogoSizeUnit.pixels;
    }
    return LogoSizeUnit.percent;
  }

  void _commit({String? overrideNumeric, String? overrideUnit}) {
    final host = context.read<SettingsDraftHost>();
    final binding = settingsBindingOf(widget.apiKey);
    final raw = binding.read(host.settings);
    final numeric = (overrideNumeric ?? _controller.text).trim();
    final unit = overrideUnit ?? _unitPart(raw);
    // Clear sentinel by scope (see SettingsDraftHost.isCascadeScope):
    // company scope writes '' (survives the rawSettings PUT merge; also the
    // server default for company_logo_size = "auto"); cascade scope writes
    // null so the override is removed rather than left as a phantom.
    final value = numeric.isEmpty
        ? (host.isCascadeScope ? null : '')
        : '$numeric$unit';
    host.updateSettings((s) => binding.write(s, value));
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final binding = settingsBindingOf(widget.apiKey);
    final raw = binding.read(host.settings);
    // Resync the controller when the host pushes a fresh value down (load,
    // reset, override toggle). Skip echo of our own writes — those land
    // through `_commit`, which produces the same raw on the next watch
    // emission, so the `_lastValue` guard suppresses the redundant write.
    if (raw != _lastValue) {
      _lastValue = raw;
      final numeric = _numericPart(raw);
      if (_controller.text != numeric) {
        _controller.value = TextEditingValue(
          text: numeric,
          selection: TextSelection.collapsed(offset: numeric.length),
        );
      }
    }
    final unit = _unitPart(raw);
    final errors = host.fieldErrors[widget.apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;

    final field = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textDirection: TextDirection.ltr,
            textAlign: ltrValueAlign(context, ltr: true),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.tr('logo_size'),
              errorText: errorText,
            ),
            onChanged: (_) => _commit(),
            onSubmitted: (_) => _commit(),
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: LogoSizeUnit.percent,
              label: Text(context.tr('percent')),
            ),
            ButtonSegment(
              value: LogoSizeUnit.pixels,
              label: Text(context.tr('pixels')),
            ),
          ],
          selected: {unit},
          showSelectedIcon: false,
          onSelectionChanged: (set) => _commit(overrideUnit: set.first),
        ),
      ],
    );

    return OverridableField.bind(
      apiKey: widget.apiKey,
      label: context.tr('logo_size'),
      cascadedValueOnEnable: () => raw,
      child: field,
    );
  }
}
