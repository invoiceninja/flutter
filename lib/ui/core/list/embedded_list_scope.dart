import 'package:flutter/widgets.dart';

/// Marks the subtree as an **embedded** entity list — one rendered inside a
/// detail screen tab (Client/Vendor/Bank-account), not a standalone list
/// screen. Row tiles read this to adopt the Client-datatable look — **roomier
/// row padding**, and nothing else — so the bottom-of-detail tables match the
/// polished standalone Clients list.
///
/// It used to carry the `⋮`-vs-`⋯` decision too, forcing the vertical menu on
/// an embedded row while a standalone row kept whatever glyph its tile passed.
/// Every overflow menu is `⋮` now (CLAUDE.md § Design system (v2)), so
/// `EntityActionsPopupButton` no longer reads this at all and that divergence
/// is gone.
///
/// Absent in standalone list screens, so [of] returns `false` there and those
/// rows keep the tighter padding (per-context divergence is intended).
///
/// Mirrors the `FormatterScope` / `DetailScrollScope` pattern. Presence is
/// structurally constant for a given subtree, so [updateShouldNotify] is
/// always `false` — reading it registers a dependency that never forces an
/// extra rebuild.
class EmbeddedListScope extends InheritedWidget {
  const EmbeddedListScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EmbeddedListScope>() != null;

  @override
  bool updateShouldNotify(EmbeddedListScope oldWidget) => false;
}
