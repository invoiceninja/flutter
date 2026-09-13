import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// A form control with its label rendered *above* the field (12px muted
/// label + the child below) — the clean "label-above-field" list look used
/// by both email surfaces.
///
/// Lifted out of `billing_doc_email_sheet.dart` so the bottom sheet and the
/// full-screen [BillingDocEmailScreen] share one definition and stay
/// visually identical.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
  });

  final String label;
  final Widget child;

  /// Optional action at the end of the label row (the composer's "Insert
  /// variable").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: tokens.ink3),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: trailing == null
              ? text
              : Row(
                  children: [
                    // Flexible, or the label takes its full intrinsic width
                    // first and squeezes the action below zero on a narrow
                    // phone at large text — the label is longer than "Subject"
                    // in most locales.
                    Flexible(child: text),
                    const SizedBox(width: InSpacing.sm),
                    // The actions share what the label leaves, end-aligned —
                    // a `Wrap` trailing then drops to a second line on a
                    // narrow phone instead of overflowing.
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: trailing!,
                      ),
                    ),
                  ],
                ),
        ),
        child,
      ],
    );
  }
}
