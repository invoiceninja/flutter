import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';

/// A small labelled action attached to a form field rather than to the form —
/// "Insert variable", "Reset", "Reset to default".
///
/// It exists as a widget because the touch-target style is not optional and is
/// easy to get wrong: `VisualDensity.compact` subtracts 8 from `minimumSize`
/// (§ Design system, touch-target trap 2), so a 44 written there renders as
/// 36, and `MaterialTapTargetSize.padded` — the iOS/Android default — hides
/// the mistake behind a 48 px floor that is not the button. Density is
/// therefore dropped on touch, where the theme default is already `standard`.
///
/// Always icon **and** label: these sit outside the field they act on, where
/// a bare glyph has no tooltip on touch and nothing to say what it does.
class FieldActionButton extends StatelessWidget {
  const FieldActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;

  /// Null disables it — kept enabled-but-inert rather than hidden where the
  /// action is merely unavailable this moment.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: Env.isTouchPrimary ? null : VisualDensity.compact,
        minimumSize: Size(0, Env.isTouchPrimary ? InSizes.touchTarget : 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
