import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/shortcut_hint_controller.dart';

/// Registers the modifier shortcuts available in the wrapped subtree's
/// context with the app-wide [ShortcutHintController], so the hold-modifier
/// hint bar can surface them. Registered while the subtree is **on-stage**,
/// removed when it goes offstage or disposes.
///
/// Pure passthrough — no layout, no painting. Used by the shell (the global
/// shortcut set) and by screens that add a context shortcut (e.g. ⌘S on
/// entity edit screens, ⌘N on billing-doc edit).
///
/// Registration is gated on [TickerMode]: go_router's
/// `StatefulShellRoute.indexedStack` keeps every visited branch mounted but
/// wraps the inactive ones in `TickerMode(enabled: false)`. Without this gate a
/// still-mounted edit screen in an offstage branch would keep advertising its
/// `⌘S`/`⌘N` chips on the visible screen's hint bar — shortcuts that do nothing
/// there (finding #40).
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

  /// Whether we currently hold a registration (i.e. we are on-stage). Tracked
  /// so an offstage→onstage TickerMode flip re-registers exactly once.
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = context.read<Services>().shortcutHints;
    } catch (_) {
      _controller = null;
    }
    // Registration is deferred to didChangeDependencies — it depends on
    // TickerMode, an inherited widget that must be read there / in build.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode flips (offstage↔onstage in an IndexedStack branch) arrive as
    // a dependency change; reading it here also subscribes us to future flips.
    _syncRegistration();
  }

  @override
  void didUpdateWidget(ShortcutHintScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuilds pass a fresh list instance with identical content; the
    // value-equality check keeps that from churning the registry. Only
    // re-register when we're currently on-stage (registered).
    if (_registered && !listEquals(oldWidget.hints, widget.hints)) {
      _controller?.register(_token, widget.hints);
    }
  }

  /// Register while on-stage (`TickerMode` enabled), unregister when offstage.
  void _syncRegistration() {
    final onStage = TickerMode.valuesOf(context).enabled;
    if (onStage && !_registered) {
      _controller?.register(_token, widget.hints);
      _registered = true;
    } else if (!onStage && _registered) {
      _controller?.unregister(_token);
      _registered = false;
    }
  }

  @override
  void dispose() {
    if (_registered) _controller?.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
