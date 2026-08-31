import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';

/// Capture a keyboard chord for [label] and return it as a [KeyBinding], or
/// null if the user cancels. The recorder produces a **logical-key** binding
/// (a produced-glyph `CharacterActivator` binding only exists as a built-in
/// default) — the platform primary modifier (⌘/Ctrl) is stored portably as
/// [KeyBinding.usesPrimary].
Future<KeyBinding?> showShortcutRecorderDialog(
  BuildContext context, {
  required String label,
}) {
  return showDialog<KeyBinding>(
    context: context,
    builder: (_) => _ShortcutRecorderDialog(label: label),
  );
}

/// Logical keys that are modifiers — pressing one alone shouldn't complete a
/// chord (we wait for the real trigger key).
final Set<LogicalKeyboardKey> _modifierKeys = {
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.alt,
};

/// Primary-modified letters reserved for OS / browser / editing conventions —
/// rebinding these would shadow copy/paste/quit/etc.
final Set<LogicalKeyboardKey> _reservedWithPrimary = {
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyV,
  LogicalKeyboardKey.keyX,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyZ,
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyR,
  LogicalKeyboardKey.keyT,
};

/// Keys that can't be bound unmodified (they have universal meanings).
final Set<LogicalKeyboardKey> _reservedBare = {
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.delete,
};

/// Keys reserved under *any* modifier — arrows drive browser-history
/// back/forward (the fixed ⌘/Alt+Arrow combos) and list / search-menu
/// navigation, so they must never become a remappable shortcut.
final Set<LogicalKeyboardKey> _reservedAlways = {
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
};

/// Returns a localization key for why [key] (with the given modifiers) can't be
/// bound as a shortcut, or null if it's acceptable. Pure + top-level so it's
/// unit-testable independently of the recorder widget.
String? shortcutBindingRejection(
  LogicalKeyboardKey key, {
  required bool usesPrimary,
  required bool alt,
}) {
  // Alt isn't representable in the binding model (reserved for the fixed
  // history combo), so reject any Alt chord.
  if (alt) return 'shortcut_reserved';
  // Arrows drive history + list/menu navigation under every modifier.
  if (_reservedAlways.contains(key)) return 'shortcut_reserved';
  // Bare `G` is the leader key — a bare-`G` binding would be dead (the leader
  // Focus consumes it before Shortcuts sees it). `G` + primary is fine.
  if (!usesPrimary && key == LogicalKeyboardKey.keyG) {
    return 'shortcut_reserved';
  }
  if (usesPrimary && _reservedWithPrimary.contains(key)) {
    return 'shortcut_reserved';
  }
  if (!usesPrimary && _reservedBare.contains(key)) return 'shortcut_reserved';
  return null;
}

class _ShortcutRecorderDialog extends StatefulWidget {
  const _ShortcutRecorderDialog({required this.label});

  final String label;

  @override
  State<_ShortcutRecorderDialog> createState() =>
      _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  KeyBinding? _candidate;

  /// Set to a reason key when the captured chord can't be used; null = ok.
  String? _errorKey;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Only react to presses; swallow repeats/up so a held key doesn't churn.
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    final key = event.logicalKey;
    // Esc cancels the recorder (so Esc itself can never be captured).
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    // Bare modifier — keep waiting for the trigger key.
    if (_modifierKeys.contains(key)) return KeyEventResult.handled;

    final hk = HardwareKeyboard.instance;
    final usesPrimary = hk.isMetaPressed || hk.isControlPressed;
    final shift = hk.isShiftPressed;
    final alt = hk.isAltPressed;

    setState(() {
      _candidate = KeyBinding.logical(
        key.keyId,
        usesPrimary: usesPrimary,
        shift: shift,
      );
      _errorKey = shortcutBindingRejection(
        key,
        usesPrimary: usesPrimary,
        alt: alt,
      );
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final mod = platformModifierLabel();
    final candidate = _candidate;
    final canSave = candidate != null && _errorKey == null;

    return AlertDialog(
      title: Text(widget.label),
      content: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('press_keys_to_record'),
              style: TextStyle(color: tokens.ink3, fontSize: 13),
            ),
            SizedBox(height: InSpacing.lg(context)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.lg(context),
                vertical: InSpacing.lg(context),
              ),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                border: Border.all(
                  color: _errorKey != null ? tokens.overdue : tokens.border,
                ),
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
              child: Center(
                child: candidate == null
                    ? Text(
                        '…',
                        style: TextStyle(color: tokens.ink3, fontSize: 18),
                      )
                    : KeyCapRow(keys: candidate.displayGlyphs(mod)),
              ),
            ),
            if (_errorKey != null) ...[
              SizedBox(height: InSpacing.md(context)),
              Text(
                context.tr(_errorKey!),
                style: TextStyle(color: tokens.overdue, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        SizedBox(width: InSpacing.md(context)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: canSave
              ? () => Navigator.of(context).pop(candidate)
              : null,
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
