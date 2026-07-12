import 'package:flutter/material.dart';

/// Visual treatment for a [PrimaryDialogAction].
enum DialogActionVariant {
  /// Accent-filled `FilledButton` — the default confirm/submit action.
  primary,

  /// `FilledButton.tonal` — a lower-emphasis primary (e.g. "Discard").
  tonal,

  /// Error-colored `FilledButton` — destructive confirms (delete / purge).
  destructive,
}

/// The standard primary (confirm/submit) button for a dialog's `actions:`.
///
/// Bakes in the conventions every dialog primary used to copy-paste:
/// the `minimumSize: Size(64, 44)` override (so side-by-side actions don't
/// stack — see `theme.dart`), `autofocus` (so Enter activates the focused
/// button), and — new — a subtle trailing **Enter** affordance so users
/// discover that Enter submits.
///
/// Truthfulness: only use this where Enter actually fires the action. In a
/// simple confirm dialog [autofocus] (default true) makes Enter activate the
/// button. In a dialog with a text field, keep [autofocus] `false` and wrap
/// the body in `FormSaveScope` (or wire the field's `onSubmitted`) so Enter
/// submits from the field. If Enter genuinely shouldn't submit (a multi-line
/// main input), pass `showEnterHint: false`.
class PrimaryDialogAction extends StatelessWidget {
  const PrimaryDialogAction({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.variant = DialogActionVariant.primary,
    this.enabled = true,
    this.autofocus = true,
    this.busy = false,
    this.icon,
    this.showEnterHint = true,
  });

  /// Forwarded to the inner button so existing test hooks (e.g. a
  /// `ValueKey`) survive migration from a hand-rolled `FilledButton`.
  final Key? buttonKey;

  final String label;
  final VoidCallback? onPressed;
  final DialogActionVariant variant;

  /// When false (or [busy]), the button is disabled. Mirror the dialog's
  /// own validity gate here (e.g. type-to-confirm text matched).
  final bool enabled;

  /// Autofocus the button so Enter activates it. Keep `true` for simple
  /// confirm dialogs; set `false` when a text field should own focus.
  final bool autofocus;

  /// Swap the label for a fixed-size spinner (e.g. while the confirm is in
  /// flight). Disables the button while shown.
  final bool busy;

  /// Optional leading icon.
  final IconData? icon;

  /// Append the trailing Enter affordance. Leave `true` wherever Enter
  /// submits; set `false` for dialogs where it doesn't.
  final bool showEnterHint;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (enabled && !busy) ? onPressed : null;
    final child = busy ? const _ButtonSpinner() : _buildLabel();

    switch (variant) {
      case DialogActionVariant.primary:
        return FilledButton(
          key: buttonKey,
          autofocus: autofocus,
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: effectiveOnPressed,
          child: child,
        );
      case DialogActionVariant.tonal:
        return FilledButton.tonal(
          key: buttonKey,
          autofocus: autofocus,
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: effectiveOnPressed,
          child: child,
        );
      case DialogActionVariant.destructive:
        final colorScheme = Theme.of(context).colorScheme;
        return FilledButton(
          key: buttonKey,
          autofocus: autofocus,
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        );
    }
  }

  Widget _buildLabel() {
    final Widget text = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );
    if (!showEnterHint) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        const SizedBox(width: 8),
        // `↵` is the app's standard Enter glyph (command palette, filter menu,
        // KeyCap). A bare dimmed glyph — not a bordered KeyCap chip, which
        // would clash on the accent-filled button. It inherits the button's
        // foreground via DefaultTextStyle; ExcludeSemantics keeps a screen
        // reader from announcing "return"/"up-arrow" after the label.
        const ExcludeSemantics(child: Opacity(opacity: 0.7, child: Text('↵'))),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 16,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
