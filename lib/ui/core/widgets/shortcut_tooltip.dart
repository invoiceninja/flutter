import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';

/// Wraps [child] in a Material [Tooltip] whose message shows [label] plus the
/// keyboard shortcut rendered as [KeyCap] chips — so hovering a button
/// reveals how to trigger it from the keyboard.
///
/// [keys] are display glyphs: `['N']`, `[platformModifierLabel(), 'K']`
/// (⌘ K), etc. Set [sequence] `true` for a leader sequence (`G` then `C`),
/// which inserts a localized "then" between the caps instead of a bare gap.
///
/// The label rides the tooltip's own text style (so it stays legible on the
/// tooltip background in both themes); the caps are self-styled chips.
class ShortcutTooltip extends StatelessWidget {
  const ShortcutTooltip({
    super.key,
    required this.label,
    required this.keys,
    this.sequence = false,
    this.waitDuration,
    required this.child,
  });

  final String label;
  final List<String> keys;
  final bool sequence;

  /// Hover delay before the tooltip appears. Defaults to the Material
  /// default; pass e.g. 600 ms to match the sidebar's tooltips.
  final Duration? waitDuration;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final separator = sequence ? ' ${context.tr('then')} ' : ' ';
    return Tooltip(
      waitDuration: waitDuration,
      richMessage: TextSpan(
        children: [
          TextSpan(text: '$label   '),
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) TextSpan(text: separator),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: KeyCap(label: keys[i]),
            ),
          ],
        ],
      ),
      child: child,
    );
  }
}
