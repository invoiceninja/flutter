import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/field_action_button.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Markdown-editing counterpart to `OverridableTextField`. Same `apiKey`
/// contract — drop-in replacement for any settings text field that should
/// accept markdown (currently the invoice/quote/credit/purchase-order terms
/// & footer fields on the Defaults tab).
///
/// SuperEditor has no `TextEditingController`-style two-way binding, so this
/// widget detects external value changes (override-toggle resets the cascaded
/// value) by passing an `externalValueKey` derived from `(apiKey, value,
/// isOverridden)` down to [MarkdownTextField]. When that key changes and the
/// VM value differs from the editor's last-emitted markdown, the editor
/// reseeds its document.
class OverridableMarkdownField extends StatelessWidget {
  const OverridableMarkdownField({
    super.key,
    required this.label,
    required this.apiKey,
    this.read,
    this.write,
    this.enabled = true,
    this.debounce,
    this.templateVariables,
    this.defaultValue,
  });

  final String label;
  final String apiKey;
  final SettingsRead? read;
  final SettingsWrite? write;
  final bool enabled;

  /// See [MarkdownTextField.templateVariables].
  final TemplateVariableScope? templateVariables;

  /// The template the server uses when this value is empty. At company scope
  /// an empty field shows it (muted), and a customised one offers "Reset to
  /// default", which writes `''`. At group/client scope the inherited value is
  /// what shows, so this is ignored there.
  final String? defaultValue;

  /// Override [MarkdownTextField]'s default 300 ms quiet period before edits
  /// are flushed. Templates & Reminders tightens this to ~150 ms so the
  /// downstream preview debounce (~400 ms) doesn't compound into a sluggish
  /// keystroke-to-preview path.
  final Duration? debounce;

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final binding = settingsBindingOf(apiKey);
    final readFn = read ?? binding.read;
    final writeFn = write ?? binding.write;
    final value = readFn(host.settings) ?? '';
    final overridden = host.isOverridden(apiKey);
    final errors = host.fieldErrors[apiKey];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;

    // At group/client level with the override off, the field displays the
    // inherited value. `OverridableField` owns the dimming there (Opacity
    // 0.65); doubling it up with the editor's own disabled overlay would
    // compound to ~0.36 alpha and crush legibility, so `enabled` is passed
    // straight through.
    //
    // What the editor does own is *how* it goes inert. It opts out of
    // `OverridableField`'s `IgnorePointer` below and uses `readOnly` instead:
    // an `IgnorePointer` wrapped around this widget would also switch off the
    // editor's internal scroll view, so an inherited Terms longer than the box
    // could not be read at all — invoiceninja/flutter#107 reappearing in the
    // settings cascade. `readOnly` blocks editing while leaving the reader
    // live, which is exactly the state an inherited value wants.
    final isCompany =
        context.watch<SettingsLevelController>().level == SettingsLevel.company;
    final inactive = !overridden && !isCompany;
    final companyDefault = isCompany && (defaultValue ?? '').isNotEmpty
        ? defaultValue
        : null;
    final canReset = companyDefault != null && value.isNotEmpty && enabled;
    final editor = MarkdownTextField(
      label: label,
      initialValue: value,
      enabled: enabled,
      readOnly: inactive,
      // `companyDefault` is in the key because the statics blob it comes from
      // can land *after* this field first builds: without it the editor keeps
      // `defaultValue: null` for ever — no "Default" badge, and text equal to
      // the default never maps back to `''`.
      externalValueKey: Object.hash(apiKey, value, overridden, companyDefault),
      debounce: debounce ?? const Duration(milliseconds: 300),
      templateVariables: templateVariables,
      defaultValue: companyDefault,
      onChanged: (v) {
        // See OverridableTextField: at cascade scope an empty edit removes the
        // override (null) instead of persisting '', which the server treats as
        // inherit and would silently diverge from the rendered PDF/email (L12).
        final value = host.isCascadeScope && v.isEmpty ? null : v;
        host.updateSettings((s) => writeFn(s, value));
      },
    );

    // "Reset to default" sits **below** the editor, right-aligned, not in its
    // label row. It undoes the whole body, so it reads as a conclusion rather
    // than a heading — and the label row already carries "Insert variable",
    // which acts on the caret; two actions of different scope side by side
    // invited the wrong one. It follows the default caption, which is the
    // sentence it answers.
    final reset = canReset
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FieldActionButton(
              icon: Icons.restart_alt,
              label: context.tr('reset_to_default'),
              // At company scope an empty value is the server's default.
              onPressed: () => host.updateSettings((s) => writeFn(s, '')),
            ),
          )
        : null;
    final error = errorText == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: InSpacing.xs, left: 2),
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          );
    final field = reset == null && error == null
        ? editor
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [editor, ?error, ?reset],
          );

    return OverridableField.bind(
      apiKey: apiKey,
      label: label,
      cascadedValueOnEnable: () => readFn(host.settings) ?? '',
      blockPointerWhenInactive: false,
      child: field,
    );
  }
}
