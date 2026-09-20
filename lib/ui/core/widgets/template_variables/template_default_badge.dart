import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// The small "Default" pill beside a template field's label, marking text the
/// field is *showing* rather than text the user wrote.
///
/// Muted grey content in a form field reads as a placeholder — "your field is
/// empty" — and here it means the opposite: this is the real content, and it
/// is what the server will send. The badge is what overturns that convention,
/// so every surface with a label row to hang it on wears one: the Templates &
/// Reminders body, and both fields of the Send Email composer. (The Templates
/// & Reminders *subject* has no label row of its own — `OverridableTextField`
/// gives the shell an `InputDecoration` — so it makes do with the caption.)
class TemplateDefaultBadge extends StatelessWidget {
  const TemplateDefaultBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(color: t.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: t.ink2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
