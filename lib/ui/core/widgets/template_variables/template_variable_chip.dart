import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';

/// The friendly label for [variable] — its own key, or `<qualifier> · <label>`
/// when the key alone is generic and would be ambiguous on a chip
/// ("Company · Street").
String templateVariableLabel(BuildContext context, TemplateVariable variable) {
  final label = context.tr(variable.labelKey);
  final qualifier = variable.qualifierKey;
  return qualifier == null ? label : '${context.tr(qualifier)} · $label';
}

/// How one `$token` presents: the chip's text and tone. Built by
/// [describeTemplateVariable]; rendered by [TemplateVariableChip].
class TemplateVariableDisplay {
  const TemplateVariableDisplay({
    required this.token,
    required this.label,
    this.monospace = false,
    this.value,
    this.warning,
  });

  /// The literal, `$` included.
  final String token;

  /// Friendly label, or the raw [token] when the catalog has no name for it.
  final String label;

  /// True when [label] is the raw token — set in the code face.
  final bool monospace;

  /// The document's value for it: null renders the label alone, `''` an em
  /// dash (the variable is valid, the document just has nothing there).
  final String? value;

  /// Non-null renders the amber warning tone, with this text in the value slot
  /// ("Not recognized", "Not available").
  final String? warning;
}

/// Resolve [token] for display in [scope], with the document's probed [value]
/// when there is one (the Send Email composer). Null means "leave it as plain
/// text": a token the catalog doesn't know and no probe has spoken for — the
/// app makes no claim about it.
///
/// A probe is the server's own answer, so it outranks the catalog: a resolved
/// value always renders as a normal chip, and an echoed (unrecognised) token
/// always warns. Without one, a catalogued token the scope's engine doesn't
/// define warns "Not available".
///
/// A value that just **repeats the label** is dropped: `$view_button`'s probe
/// answer is the button's own caption, so the chip read "View Invoice  View
/// Invoice", and every server default body ends with that token.
///
/// Deliberately keyed on the duplication and not on `isMarkup`, which the
/// probe sets for *any* HTML in the rendered value: `$public_notes`, `$terms`
/// and `$footer` are stored as HTML by this app's own editor, so suppressing
/// on markup blanked their values — and label-only renders identically to
/// "the probe hasn't answered yet", leaving no way to tell the two apart.
TemplateVariableDisplay? describeTemplateVariable(
  BuildContext context,
  String token,
  TemplateVariableScope scope, {
  TemplateVariableValue? value,
}) {
  final lookup = lookupTemplateVariable(token, scope);
  final notRecognized = context.tr('variable_not_recognized');
  if (lookup == null) {
    return switch (value) {
      // An uncatalogued token's label IS the token, which a value can't
      // repeat, so there is nothing to suppress here.
      TemplateVariableResolved(:final text) => TemplateVariableDisplay(
        token: token,
        label: token,
        monospace: true,
        value: text,
      ),
      TemplateVariableEmpty() => TemplateVariableDisplay(
        token: token,
        label: token,
        monospace: true,
        value: '',
      ),
      TemplateVariableUnknown() => TemplateVariableDisplay(
        token: token,
        label: token,
        monospace: true,
        warning: notRecognized,
      ),
      null => null,
    };
  }
  final label = templateVariableLabel(context, lookup.variable);
  return switch (value) {
    TemplateVariableResolved(:final text) when _repeatsLabel(text, label) =>
      TemplateVariableDisplay(token: token, label: label),
    TemplateVariableResolved(:final text) => TemplateVariableDisplay(
      token: token,
      label: label,
      value: text,
    ),
    TemplateVariableEmpty() => TemplateVariableDisplay(
      token: token,
      label: label,
      value: '',
    ),
    TemplateVariableUnknown() => TemplateVariableDisplay(
      token: token,
      label: label,
      warning: notRecognized,
    ),
    null when !lookup.inScope => TemplateVariableDisplay(
      token: token,
      label: label,
      warning: context.tr('not_available'),
    ),
    null => TemplateVariableDisplay(token: token, label: label),
  };
}

bool _repeatsLabel(String value, String label) =>
    value.trim().toLowerCase() == label.trim().toLowerCase();

/// The chip's fill for [display]. Exposed so a host that makes the chip
/// tappable can paint it on a local `Material` instead (and pass
/// `fill: false`): an opaque fill *inside* an `InkWell` covers the ripple —
/// the reason `Ink` is banned (`test/lint/no_ink_widget_test.dart`).
Color templateVariableChipFill(
  InTheme tokens,
  TemplateVariableDisplay display,
) => display.warning != null ? tokens.warningSoft : tokens.surfaceAlt;

/// One `$variable` rendered as a chip — the filter bar's `FilterTokenChip`
/// anatomy (`surfaceAlt`, a border, `InRadii.r1`), sized to sit inside a line
/// of running text (invoiceninja/flutter#139).
///
/// Three looks, all from [TemplateVariableDisplay]:
///  * **label only** (Templates & Reminders): the label in `ink` w600 — not
///    lowercased, so "PO Number" and German nouns survive;
///  * **label + value** (Send Email): the label steps back to `ink2` w500 and
///    the value takes `ink` w600; an empty value is an em dash;
///  * **warning**: amber `warningSoft` with an icon — never the red that means
///    overdue or destructive in this app.
///
/// It declares **no semantics and no gestures** of its own: inside
/// super_editor it sits under an `IgnorePointer` with no semantics layer at
/// all, and the subject field wraps it in its own button. [editable] adds the
/// filter bar's `▾` "tap to change" cue; an inert chip must not carry it.
class TemplateVariableChip extends StatelessWidget {
  const TemplateVariableChip({
    super.key,
    required this.display,
    this.muted = false,
    this.editable = false,
    this.fontSize = 12,
    this.showTooltip = false,
    this.maxValueWidth = 140,
    this.fill = true,
  });

  final TemplateVariableDisplay display;

  /// False when the host paints [templateVariableChipFill] on a `Material`
  /// around an `InkWell`, so the ripple shows through.
  final bool fill;

  /// The default-template state: the whole chip steps back to `ink2`.
  final bool muted;

  final bool editable;
  final double fontSize;

  /// Pointer platforms only — a tooltip needs hover, and the body's chips
  /// can't receive it at all.
  final bool showTooltip;

  final double maxValueWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final warning = display.warning;
    final value = display.value;
    final hasSecond = warning != null || value != null;
    final base = TextStyle(fontSize: fontSize, height: 1.2);
    final labelStyle = base.copyWith(
      fontFamily: display.monospace ? kMonoFontFamily : null,
      color: (muted || hasSecond) ? t.ink2 : t.ink,
      fontWeight: hasSecond ? FontWeight.w500 : FontWeight.w600,
    );
    final secondText = warning ?? ((value ?? '').isEmpty ? '—' : value!);
    final secondStyle = base.copyWith(
      color: warning == null && (value ?? '').isEmpty ? t.ink3 : t.ink,
      fontWeight: FontWeight.w600,
    );

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: fill ? templateVariableChipFill(t, display) : null,
        // Project rule: rounded rectangles, never pills.
        borderRadius: BorderRadius.circular(InRadii.r1),
        // `borderStrong`, not `border`: on the editor's `surface` the
        // `surfaceAlt` fill is only ~1.05-1.10:1, so the outline is what
        // separates the chip from the text around it.
        border: Border.all(color: warning != null ? t.warning : t.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warning != null) ...[
            Icon(
              Icons.warning_amber_rounded,
              size: fontSize + 1,
              color: t.warning,
            ),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              display.label,
              style: labelStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasSecond) ...[
            const SizedBox(width: 4),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxValueWidth),
                child: Text(
                  secondText,
                  style: secondStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          if (editable)
            Icon(Icons.arrow_drop_down, size: fontSize + 2, color: t.ink3),
        ],
      ),
    );
    if (showTooltip && !Env.isTouchPrimary) {
      chip = Tooltip(message: display.token, child: chip);
    }
    return chip;
  }
}
