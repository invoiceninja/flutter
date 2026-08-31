import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';

/// Global overlay for the Slack-style "hold the platform modifier to reveal
/// shortcuts" hint bar. Mounted once near the app root (a sibling of
/// `ToastHost` in `main.dart`'s builder Stack) so it paints above every
/// route and modal.
///
/// Detection re-derives "only the platform modifier is held" from the live
/// pressed-set on every key event (never tracking down/up deltas, so
/// key-repeats and missed events can't desync). A ~400 ms hold reveals the
/// bar; releasing the modifier, pressing any other key, a pointer-down, or
/// an app-lifecycle change hides it. The handler always returns `false`, so
/// it never swallows real shortcuts (⌘K/⌘S/…) or platform/browser defaults.
///
/// The bar is non-interactive ([IgnorePointer] + [ExcludeSemantics]) and
/// only shows on layouts with the global nav visible (≥ 600 px), which also
/// keeps it clear of the mobile `NavigationBar`.
class ShortcutHintOverlay extends StatefulWidget {
  const ShortcutHintOverlay({super.key, required this.controller});

  final ShortcutHintController controller;

  @override
  State<ShortcutHintOverlay> createState() => _ShortcutHintOverlayState();
}

/// How long the modifier must be held (alone) before the bar appears. Long
/// enough that a quick ⌘K never flashes the bar; short enough to feel
/// responsive on a deliberate hold.
const Duration _kHoldDelay = Duration(milliseconds: 400);

/// Every modifier key (both physical sides + synonyms) that may legitimately
/// be held while the bar shows. Anything else in the pressed-set means a
/// non-modifier key is down → hide. Not `const`: `LogicalKeyboardKey`
/// overrides `==`, which a const set forbids.
final Set<LogicalKeyboardKey> _kModifierKeys = {
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
};

class _ShortcutHintOverlayState extends State<ShortcutHintOverlay>
    with WidgetsBindingObserver {
  Timer? _revealTimer;

  // Computed per access (not a cached static) so a widget test that flips
  // `debugDefaultTargetPlatformOverride` isn't order-dependent.
  bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  // ALWAYS returns false: a passive observer, never a consumer. Returning
  // true would OR into the embedder's "handled" result and suppress browser
  // defaults (⌘W/⌘L) on web; it wouldn't stop Flutter's Shortcuts dispatch.
  bool _onKey(KeyEvent event) {
    _evaluate();
    return false;
  }

  void _onPointer(PointerEvent event) {
    // Holding ⌘ then clicking (or clicking away on web) dismisses the bar.
    if (event is PointerDownEvent) _cancelAndHide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Any transition clears our side — incl. `resumed`, where regaining
    // focus can leave `logicalKeysPressed` stale (a missed key-up during
    // ⌘Tab / Spotlight). Never call `HardwareKeyboard.clearState()`: that
    // global state is shared with the shell's leader-key guard.
    _cancelAndHide();
  }

  void _evaluate() {
    if (_onlyPlatformModifierHeld()) {
      if (!widget.controller.visible && _revealTimer == null) {
        _revealTimer = Timer(_kHoldDelay, _fireReveal);
      }
    } else {
      _cancelAndHide();
    }
  }

  void _fireReveal() {
    _revealTimer = null;
    if (mounted && _onlyPlatformModifierHeld()) widget.controller.reveal();
  }

  void _cancelAndHide() {
    _revealTimer?.cancel();
    _revealTimer = null;
    widget.controller.hide();
  }

  bool _onlyPlatformModifierHeld() {
    final hk = HardwareKeyboard.instance;
    final modDown = _isApple ? hk.isMetaPressed : hk.isControlPressed;
    if (!modDown) return false;
    // No secondary modifier: keeps the bar to a bare ⌘/Ctrl hold, and
    // rejects AltGr (which reports as Ctrl+Alt on Windows/Linux).
    if (hk.isAltPressed || hk.isShiftPressed) return false;
    if (_isApple ? hk.isControlPressed : hk.isMetaPressed) return false;
    // No non-modifier key held: pressing a letter fires the combo + hides.
    return hk.logicalKeysPressed.every(_kModifierKeys.contains);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final show =
            widget.controller.visible &&
            Breakpoints.isGlobalNavVisible(context);
        final hints = show
            ? widget.controller.activeHints
            : const <ShortcutHint>[];
        return IgnorePointer(
          child: ExcludeSemantics(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    child: hints.isEmpty
                        ? const SizedBox.shrink()
                        : _HintBar(hints: hints),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar({required this.hints});

  final List<ShortcutHint> hints;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // The overlay mounts at the app root (sibling of `ToastHost`), so this bar
    // has no `Scaffold`/`Material` ancestor. Bare `Text` (and the `KeyCap`
    // glyphs) would then inherit `WidgetsApp`'s fallback text style and paint
    // the yellow "missing Material" double underline. A transparent `Material`
    // supplies the ancestor without drawing anything — the `Container` below
    // keeps its own surface, border, and shadow.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.md(context),
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r3),
          boxShadow: tokens.shadow2,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: InSpacing.lg(context),
          runSpacing: InSpacing.sm,
          children: [
            for (final hint in hints)
              KeyCapRow(keys: hint.keys, label: context.tr(hint.labelKey)),
            // Trailing pointer to the full list — the modifier-only bar isn't
            // exhaustive (single-key shortcuts + the G-leader live in the ?
            // dialog). `?` is itself a global shortcut that opens it.
            KeyCapRow(keys: const ['?'], label: context.tr('all_shortcuts')),
          ],
        ),
      ),
    );
  }
}
