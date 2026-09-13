import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/email_template_variables.dart';

/// A [TextEditingController] that tints the `$variables` it recognises while
/// the text is being edited raw — the edit mode of the subject field and the
/// Send Email body (invoiceninja/flutter#139).
///
/// Styling only: every token keeps its own characters, so text offsets map
/// 1:1 onto the layout and the caret, selection and IME behave exactly as in
/// a plain field. (A chip `WidgetSpan` standing in for a 13-character token
/// would break that mapping — which is why editing is raw text at all.)
/// Tokens get a background as well as a colour, so colour is never the only
/// cue.
///
/// While the IME is composing, the platform's composing underline wins: the
/// controller defers to [TextEditingController.buildTextSpan] unchanged
/// rather than splitting the span under the region being composed.
class TemplateVariableTextController extends TextEditingController {
  TemplateVariableTextController({
    super.text,
    required TemplateVariableScope scope,
  }) : _scope = scope;

  TemplateVariableScope _scope;

  /// Which variables count as recognised — the template's (Templates &
  /// Reminders) or the document's (Send Email).
  TemplateVariableScope get scope => _scope;

  set scope(TemplateVariableScope value) {
    if (value == _scope) return;
    _scope = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing =
        withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed;
    final matches = composing
        ? const <TemplateVariableMatch>[]
        : [
            for (final m in findTemplateVariables(text))
              if (lookupTemplateVariable(m.token, _scope) != null) m,
          ];
    if (matches.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final t = context.inTheme;
    final tokenStyle = TextStyle(
      color: t.accentInk,
      backgroundColor: t.accentSoft,
      fontWeight: FontWeight.w600,
    );
    final children = <TextSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      children.add(TextSpan(text: m.token, style: tokenStyle));
      cursor = m.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}
