import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/shortcut_hint_controller.dart';

/// Registers the modifier shortcuts available in the wrapped subtree's
/// context with the app-wide [ShortcutHintController], so the hold-modifier
/// hint bar can surface them. Registered on mount, removed on dispose.
///
/// Pure passthrough — no layout, no painting. Used by the shell (the global
/// shortcut set) and by screens that add a context shortcut (e.g. ⌘S on
/// entity edit screens, ⌘N on billing-doc edit).
class ShortcutHintScope extends StatefulWidget {
  const ShortcutHintScope({
    super.key,
    required this.hints,
    required this.child,
  });

  final List<ShortcutHint> hints;
  final Widget child;

  @override
  State<ShortcutHintScope> createState() => _ShortcutHintScopeState();
}

class _ShortcutHintScopeState extends State<ShortcutHintScope> {
  final Object _token = Object();

  // Captured once (Services never changes) so [dispose] never touches an
  // inherited widget on an unmounting element. Null when the controller
  // isn't reachable — the scope is a *passive* registration, so an isolated
  // widget test that pumps a host screen without a Services provider (or with
  // a fake Services that doesn't stub `shortcutHints`) just no-ops instead of
  // breaking the screen. In the real app Services is always present.
  ShortcutHintController? _controller;

  @override
  void initState() {
    super.initState();
    try {
      _controller = context.read<Services>().shortcutHints;
    } catch (_) {
      _controller = null;
    }
    _controller?.register(_token, widget.hints);
  }

  @override
  void didUpdateWidget(ShortcutHintScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuilds pass a fresh list instance with identical content; the
    // value-equality check keeps that from churning the registry.
    if (!listEquals(oldWidget.hints, widget.hints)) {
      _controller?.register(_token, widget.hints);
    }
  }

  @override
  void dispose() {
    _controller?.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
