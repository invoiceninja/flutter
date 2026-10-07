import 'package:flutter/widgets.dart';

/// Registry of the on-stage token search fields' [FocusNode]s. The global `/`
/// shortcut in the authenticated shell reads [current] to focus the search
/// input on the active list screen without coupling the shell to any specific
/// list. `null` when no list screen is on stage (e.g. on the dashboard or
/// settings).
///
/// Claimed by `_TokenSearchFieldState.didChangeDependencies` while that field's
/// branch is **on-stage**, and released when it goes offstage or is disposed.
/// Deliberately not `initState`: `StatefulShellRoute.indexedStack` keeps every
/// visited branch mounted, so several fields are alive at once and a mount-time
/// claim leaves this pointing at whichever one mounted last — i.e. at an
/// offstage branch's box.
///
/// **A stack, not a slot.** A record pane's embedded list mounts a second
/// field *over* the main list's, and when it was one slot the pane's field
/// claimed it and nulled it on dispose — the main list never re-ran
/// `didChangeDependencies`, so `/` went dead until the next branch switch.
/// [release] hands the slot back to the previous claimant instead.
///
/// Plain mutable state — the `/` action runs once per keystroke and reads
/// [current] synchronously, so there is no need to notify listeners on writes.
class SearchFocusRegistry {
  final List<FocusNode> _claims = <FocusNode>[];

  /// The most recent claimant still holding a claim, or null.
  FocusNode? get current => _claims.isEmpty ? null : _claims.last;

  /// Claims the slot for [node], moving it to the top. Assigning `null` drops
  /// every claim.
  set current(FocusNode? node) {
    if (node == null) {
      _claims.clear();
      return;
    }
    _claims
      ..remove(node)
      ..add(node);
  }

  /// Gives [node]'s claim up, wherever it sits; whoever claimed before it
  /// becomes [current] again. A no-op for a node that holds no claim.
  void release(FocusNode node) => _claims.remove(node);
}
