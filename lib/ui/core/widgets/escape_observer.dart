import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Observes Escape **without consuming it**.
///
/// Exists for the `RawAutocomplete`-based pickers. Flutter's `DismissIntent`
/// hides the options overlay without touching focus, so nothing else notices
/// that it is gone — and a picker that tracks "are my options showing?" in a
/// field would keep answering yes, and act on a popover the user just
/// dismissed. Wrap the field, clear the flag in [onEscape].
///
/// Returning [KeyEventResult.ignored] is the point: the key still reaches
/// `RawAutocomplete`'s own shortcut, which is what actually hides the overlay.
class EscapeObserver extends StatelessWidget {
  const EscapeObserver({
    super.key,
    required this.onEscape,
    required this.child,
  });

  final VoidCallback onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onEscape();
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
