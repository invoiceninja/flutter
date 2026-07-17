import 'package:flutter/material.dart';

/// Whether the currently-focused element is inside any kind of text input.
///
/// Used by single-key shortcut actions across the app (pane `F`/`J`/`K`/
/// arrows, list `N` + arrows, detail `E`, shell `/` + `?` + leader-key)
/// to stand down while the user is typing — otherwise `f` toggles the
/// pane's full-screen instead of inserting the letter.
///
/// The historical guard was `primaryFocus.context.widget is EditableText`.
/// That check is **always false** in current Flutter: `EditableText`
/// (see `flutter/lib/src/widgets/editable_text.dart`, around line 5766)
/// builds a child `Focus` widget that hosts its `focusNode`, so the
/// `FocusNode.context` resolves to the inner `Focus` element, not
/// `EditableText`. We walk up the element tree instead.
///
/// We also honour [TextInputFocusScope] — a marker widget that
/// non-`EditableText` editors (currently `super_editor` via
/// `MarkdownTextField`) wrap themselves in so the same guard applies.
bool isTextInputFocused() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  // Cheap direct check (unlikely to hit, but harmless).
  if (ctx.widget is EditableText) return true;
  if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) return true;
  if (ctx.findAncestorWidgetOfExactType<TextInputFocusScope>() != null) {
    return true;
  }
  return false;
}

/// Marker widget that declares "the subtree below me is a text input,
/// even if no [EditableText] is involved." Wrap rich editors that
/// handle their own IME (e.g. `super_editor`) in this so
/// [isTextInputFocused] returns true while their caret is active.
///
/// Pure passthrough — no layout, no painting, no rebuild cost.
class TextInputFocusScope extends StatelessWidget {
  const TextInputFocusScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Global latch for the shell's `G`-then-`<key>` leader sequence
/// (`scaffold_with_nav`). Armed while the shell waits for the second key.
///
/// Single-key shortcuts ([GuardedShortcutAction]) stand down while it's true so
/// the second key reaches the shell's ancestor leader handler instead of being
/// swallowed by a descendant list/pane shortcut — finding U3: on the Tasks list
/// the single-key `S` (toggle timer) consumed the `S` of `G then S` (→ Settings)
/// because key events dispatch leaf-first, so the leader jump silently failed.
///
/// A plain flag, not a notifier: it's polled synchronously at key-press time
/// (in [Action.isEnabled], which has no `BuildContext`), never listened to.
/// Mirrors the existing global [isTextInputFocused] guard.
bool leaderModeArmed = false;

/// A [CallbackAction] that is *disabled* — not merely a no-op — while a
/// text input has focus, or while the shell's leader sequence is armed. Use
/// for any single-key shortcut whose key should pass through (to a focused
/// field, or up to the leader handler) instead of being swallowed.
///
/// Why disabling matters: `ShortcutManager.handleKeypress` returns
/// `KeyEventResult.ignored` (letting the key fall through) only when the
/// matched action's `isEnabled` is false. `Action.consumesKey` defaults to
/// `true`, so a guard that only no-ops in `onInvoke` still reports the key as
/// handled and swallows it. `consumesKey` is overridden too as belt-and-braces.
class GuardedShortcutAction<T extends Intent> extends CallbackAction<T> {
  GuardedShortcutAction({required super.onInvoke});

  @override
  bool isEnabled(T intent) => !isTextInputFocused() && !leaderModeArmed;

  @override
  bool consumesKey(T intent) => !isTextInputFocused() && !leaderModeArmed;
}
