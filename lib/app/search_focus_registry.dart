import 'package:flutter/widgets.dart';

/// One-slot registry of the currently-mounted token search field's
/// [FocusNode]. The global `/` shortcut in the authenticated shell reads
/// this to focus the search input on the active list screen without
/// coupling the shell to any specific list. `null` when no list screen is
/// mounted (e.g. on the dashboard or settings).
///
/// Claimed by `_TokenSearchFieldState.didChangeDependencies` while that field's
/// branch is **on-stage**, and cleared (identity-guarded) in its `dispose`.
/// Deliberately not `initState`: `StatefulShellRoute.indexedStack` keeps every
/// visited branch mounted, so several fields are alive at once and a mount-time
/// claim leaves this pointing at whichever one mounted last — i.e. at an
/// offstage branch's box.
///
/// Plain mutable field — the `/` action runs once per keystroke and
/// reads the slot synchronously, so there is no need to notify
/// listeners on writes.
class SearchFocusRegistry {
  FocusNode? current;
}
