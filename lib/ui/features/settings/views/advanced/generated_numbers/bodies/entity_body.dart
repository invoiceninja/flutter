import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/generated_numbers/generated_number_preview.dart';
import 'package:admin/ui/features/settings/views/advanced/generated_numbers/generated_numbers_validation.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_number_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// PHP date-format reference linked from the entity tabs. The variable
/// `{\$date:<format>}` uses PHP's `date()` syntax server-side.
const _kPhpDateFormatsUrl = 'https://www.php.net/manual/en/datetime.format.php';

/// Body reused for every per-entity tab on the Generated Numbers settings
/// page. Renders one [FormSection] with:
///   1. Pattern text field bound to `<entity>_number_pattern`.
///   2. Counter integer field bound to `<entity>_number_counter`.
///   3. A labeled row of clickable variable chips that splice the corresponding
///      `{$token}` into the pattern field at the current caret position and
///      keep the field focused.
///   4. A "View date formats" link to PHP's `date()` reference.
///
/// The chip set depends on the entity:
///   * Always: counter, year, date:Y-m-d, user_id, user_custom1-4.
///   * [showClientTokens]: client_counter, group_counter, client_number,
///     client_id_number, client_custom1-4.
///   * [showVendorTokens]: vendor_number, vendor_id_number, vendor_custom1-4.
///
/// Custom-field chips (`*_custom1-4`) render only when the company has
/// configured that custom field; their tooltip shows the configured label.
///
/// This widget owns the pattern field's [TextEditingController] and [FocusNode]
/// so the sibling chips can splice tokens at the caret and return focus to the
/// field — the chips can't reach a controller owned by [_PatternField] because
/// they're siblings, not descendants.
///
/// Mounted by `GeneratedNumbersShell` inside a `CascadeTabbedSettingsShell`, so
/// `SettingsDraftHost` is already supplied via Provider.
class GeneratedNumbersEntityBody extends StatefulWidget {
  const GeneratedNumbersEntityBody({
    super.key,
    required this.company,
    required this.patternKey,
    required this.counterKey,
    required this.titleKey,
    required this.showClientTokens,
    required this.showVendorTokens,
    this.showVendorIdNumberOnly = false,
  });

  /// Active company — the source of the custom-field labels that decide which
  /// `*_custom*` chips are shown. Threaded from the shell rather than read off
  /// `SettingsDraftHost.draft` (which is null at client cascade scope).
  final Company company;

  /// `apiKey` for the pattern field (e.g. `'invoice_number_pattern'`).
  final String patternKey;

  /// `apiKey` for the counter field (e.g. `'invoice_number_counter'`).
  final String counterKey;

  /// Localization key for the section title (matches the tab label, e.g.
  /// `'invoices'`).
  final String titleKey;

  /// Show the client / group token chips. Set on tabs whose entity carries a
  /// client reference (invoices, quotes, credits, payments, recurring
  /// invoices, projects).
  final bool showClientTokens;

  /// Show the vendor token chips. Set only on the Expenses tab — the backend
  /// substitutes `{$vendor_*}` only for `Expense` entities; purchase orders and
  /// recurring expenses leave those tokens literal, so they don't show them.
  final bool showVendorTokens;

  /// Show only the `{$vendor_id_number}` chip — set on the Vendors tab. The
  /// backend substitutes `{$vendor_id_number}` for a `Vendor` entity (the
  /// `instanceof Vendor` branch in `GeneratesCounter`) but NOT the other vendor
  /// tokens (those are Expense-only), so this is narrower than [showVendorTokens].
  final bool showVendorIdNumberOnly;

  @override
  State<GeneratedNumbersEntityBody> createState() =>
      _GeneratedNumbersEntityBodyState();
}

class _GeneratedNumbersEntityBodyState
    extends State<GeneratedNumbersEntityBody> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SettingsBinding _binding;

  @override
  void initState() {
    super.initState();
    _binding = settingsBindingOf(widget.patternKey);
    _focusNode = FocusNode();
    final host = context.read<SettingsDraftHost>();
    _controller = TextEditingController(
      text: _binding.read(host.settings) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _writePattern(String value) {
    final host = context.read<SettingsDraftHost>();
    host.updateSettings((s) => _binding.write(s, value.isEmpty ? null : value));
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final hostValue = _binding.read(host.settings) ?? '';
    // Pull host-side changes (override toggle, programmatic reset) into the
    // controller — but skip when the user is actively typing (controller +
    // host already in sync). Same idea as OverridableTextField. Load-bearing:
    // running this in the watch-driven parent build is what makes a cascade
    // override-toggle reset reflect into the field.
    if (_controller.text != hostValue) {
      _controller.value = TextEditingValue(
        text: hostValue,
        selection: TextSelection.collapsed(offset: hostValue.length),
      );
    }
    // At group/client scope the pattern field is disabled (and dimmed) by its
    // OverridableField until the user opts into overriding. The chips are
    // siblings — not wrapped by that — so mirror the same gate here, keyed off
    // the same `isOverridden` that drives the field's checkbox, so a user can't
    // edit (and silently force-on the override of) a field they can't type in.
    // At company scope the field is always editable, so the chips always are.
    final level = context.watch<SettingsLevelController>().level;
    final patternEditable =
        level == SettingsLevel.company || host.isOverridden(widget.patternKey);
    // Live, read-only example of the generated number. Reads the effective
    // (merged) settings, so it's NOT gated by the override toggle like the
    // chips — at client scope it shows the inherited-or-overridden result.
    final counter =
        int.tryParse(
          settingsBindingOf(widget.counterKey).read(host.settings) ?? '',
        ) ??
        1;
    final padding =
        int.tryParse(
          settingsBindingOf('counter_padding').read(host.settings) ?? '',
        ) ??
        4;
    final preview = buildNumberPreview(
      pattern: hostValue,
      counter: counter,
      padding: padding,
      now: DateTime.now(),
      showClient: widget.showClientTokens,
      showVendor: widget.showVendorTokens,
      showVendorIdNumber: widget.showVendorIdNumberOnly,
      company: widget.company,
    );
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr(widget.titleKey),
          children: [
            _PatternField(
              apiKey: widget.patternKey,
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _writePattern,
            ),
            OverridableNumberField(
              label: context.tr('number_counter'),
              apiKey: widget.counterKey,
              integerOnly: true,
            ),
            _PreviewRow(value: preview),
            IgnorePointer(
              ignoring: !patternEditable,
              child: Opacity(
                opacity: patternEditable ? 1.0 : 0.65,
                child: _VariableChips(
                  controller: _controller,
                  focusNode: _focusNode,
                  company: widget.company,
                  onChanged: _writePattern,
                  showClientTokens: widget.showClientTokens,
                  showVendorTokens: widget.showVendorTokens,
                  showVendorIdNumberOnly: widget.showVendorIdNumberOnly,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: LinkText(
                label: context.tr('view_date_formats'),
                color: context.inTheme.accent,
                onTap: () =>
                    unawaited(launchUrl(Uri.parse(_kPhpDateFormatsUrl))),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pattern field for the Generated Numbers entity tabs. Mirrors
/// [OverridableTextField] but reads its [TextEditingController] / [FocusNode]
/// from the parent so the sibling variable chips can splice tokens at the caret
/// and return focus here. Watches [SettingsDraftHost] itself for `errorText`
/// and the cascade override toggle.
class _PatternField extends StatelessWidget {
  const _PatternField({
    required this.apiKey,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String apiKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final binding = settingsBindingOf(apiKey);
    final scope = FormSaveScope.maybeOf(context);
    final errors = host.fieldErrors[apiKey];
    final serverError = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;
    // Client-side guard ported from the legacy app: a pattern with
    // {$client_counter} but no distinguishing token mints duplicate numbers
    // across clients. Shown inline at every cascade scope (the server doesn't
    // validate it); a server-side 422 for this field still wins if present.
    final localError = violatesClientCounterRule(controller.text)
        ? context.tr('counter_pattern_error').replaceAll(':', r'$')
        : null;
    final errorText = serverError ?? localError;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: context.tr('number_pattern'),
        errorText: errorText,
      ),
      onChanged: onChanged,
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
      autocorrect: false,
    );
    return OverridableField.bind(
      apiKey: apiKey,
      label: context.tr('number_pattern'),
      cascadedValueOnEnable: () => binding.read(host.settings) ?? '',
      child: field,
    );
  }
}

/// Labeled wrap of clickable chips that splice variable tokens into the pattern
/// field at the current caret position and refocus it. Custom-field chips
/// (`*_custom*`) render only when the company has configured that field.
class _VariableChips extends StatelessWidget {
  const _VariableChips({
    required this.controller,
    required this.focusNode,
    required this.company,
    required this.onChanged,
    required this.showClientTokens,
    required this.showVendorTokens,
    required this.showVendorIdNumberOnly,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Company company;
  final ValueChanged<String> onChanged;
  final bool showClientTokens;
  final bool showVendorTokens;
  final bool showVendorIdNumberOnly;

  @override
  Widget build(BuildContext context) {
    final tokens = <_TokenSpec>[
      const _TokenSpec(token: 'counter'),
      if (showClientTokens) ...const [
        _TokenSpec(token: 'client_counter'),
        _TokenSpec(token: 'group_counter'),
      ],
      const _TokenSpec(token: 'year'),
      const _TokenSpec(token: 'date:Y-m-d'),
      if (showClientTokens) ...const [
        _TokenSpec(token: 'client_number'),
        _TokenSpec(token: 'client_id_number'),
        _TokenSpec(token: 'client_custom1', customFieldKey: 'client1'),
        _TokenSpec(token: 'client_custom2', customFieldKey: 'client2'),
        _TokenSpec(token: 'client_custom3', customFieldKey: 'client3'),
        _TokenSpec(token: 'client_custom4', customFieldKey: 'client4'),
      ],
      if (showVendorTokens) ...const [
        _TokenSpec(token: 'vendor_number'),
        _TokenSpec(token: 'vendor_id_number'),
        _TokenSpec(token: 'vendor_custom1', customFieldKey: 'vendor1'),
        _TokenSpec(token: 'vendor_custom2', customFieldKey: 'vendor2'),
        _TokenSpec(token: 'vendor_custom3', customFieldKey: 'vendor3'),
        _TokenSpec(token: 'vendor_custom4', customFieldKey: 'vendor4'),
      ],
      // Vendors tab: only {$vendor_id_number} (the backend substitutes it for a
      // Vendor entity; the other vendor tokens are Expense-only).
      if (showVendorIdNumberOnly) const _TokenSpec(token: 'vendor_id_number'),
      const _TokenSpec(token: 'user_id'),
      const _TokenSpec(token: 'user_custom1', customFieldKey: 'user1'),
      const _TokenSpec(token: 'user_custom2', customFieldKey: 'user2'),
      const _TokenSpec(token: 'user_custom3', customFieldKey: 'user3'),
      const _TokenSpec(token: 'user_custom4', customFieldKey: 'user4'),
    ];
    final theme = Theme.of(context);
    final t = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('variables'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.md(context),
          runSpacing: InSpacing.sm,
          children: [
            for (final spec in tokens)
              // Custom-field chips are gated on the company having configured
              // that field; non-custom tokens (customFieldKey == null) always
              // render.
              if (spec.customFieldKey == null ||
                  company.customFieldLabel(spec.customFieldKey!).isNotEmpty)
                ActionChip(
                  label: Text('{\$${spec.token}}'),
                  // Custom-field chips explain the opaque token with the
                  // configured label (e.g. "Region"); base tokens are
                  // self-documenting, so no tooltip.
                  tooltip: spec.customFieldKey == null
                      ? null
                      : company.customFieldLabel(spec.customFieldKey!),
                  onPressed: () => _insertToken(spec.token),
                ),
          ],
        ),
      ],
    );
  }

  void _insertToken(String token) {
    final insertion = '{\$$token}';
    final selection = controller.selection;
    final text = controller.text;
    // If the field has never had focus / there's no valid selection, append
    // the token to the end. Otherwise splice at the caret (replacing the
    // selected range if any). Read the selection BEFORE requesting focus so
    // this first-tap append path is preserved.
    final hasValidSelection = selection.start >= 0 && selection.end >= 0;
    final start = hasValidSelection ? selection.start : text.length;
    final end = hasValidSelection ? selection.end : text.length;
    final newText = text.replaceRange(start, end, insertion);
    final caret = TextSelection.collapsed(offset: start + insertion.length);
    controller.value = TextEditingValue(text: newText, selection: caret);
    onChanged(newText);
    focusNode.requestFocus();
    // macOS echoes a select-all back through the IME after a programmatic
    // text.value write while the field is focused, clobbering the caret we just
    // set — which would make the next chip replace the whole field instead of
    // appending. Re-assert the caret next frame, guarded so we don't fight a
    // user who has since typed or moved it. Mirrors TokenSearchController.selectKey.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!focusNode.hasFocus) return;
      if (controller.text != newText) return;
      if (controller.selection == caret) return;
      controller.selection = caret;
    });
  }
}

/// One variable chip. `token` is the bare PHP token without the `{$…}` braces
/// (e.g. `'counter'`, `'date:Y-m-d'`, `'client_custom1'`). [customFieldKey],
/// when set, marks a custom-field token and names its `company.customFields`
/// slot (e.g. `'client1'`) — the chip then renders only when that field is
/// active and shows its configured label as the tooltip.
class _TokenSpec {
  const _TokenSpec({required this.token, this.customFieldKey});

  final String token;
  final String? customFieldKey;
}

/// Read-only example of the generated number, rendered below the inputs. The
/// value is computed by [buildNumberPreview] and refreshes on every host change
/// (counter / pattern / padding). Styled as inset "output" (alt surface, ink2,
/// monospace) to read distinctly from the editable fields above.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('preview'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: InSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: t.ink2,
              fontFamily: kMonoFontFamily,
            ),
          ),
        ),
      ],
    );
  }
}
