import 'package:flutter/widgets.dart';

/// Registry of the on-stage search fields' [FocusNode]s. The global `/`
/// shortcut in the authenticated shell calls [activate] to focus the search
/// input on the active screen without coupling the shell to any specific
/// screen. [current] is `null` when nothing searchable is on stage (e.g. on the
/// dashboard).
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
/// **A claim can open its field, not only focus it.** The settings search
/// field isn't mounted until the magnifying glass is pressed, and focusing a
/// detached node does nothing, so the settings screen claims through [claim]
/// with an `onActivate` that opens the search first.
///
/// **And it can be a fallback.** On a wide window the settings pane and a list
/// in the pane beside it (Payment Links) are on stage together, and both
/// re-claim when the branch comes back — in an order nothing fixes, since an
/// inherited widget's dependents are notified in no particular order. So `/`
/// could open the settings search over the list the user was looking at. A
/// `fallback` claim sits below every regular one, whenever it was made.
///
/// Plain mutable state — the `/` action runs once per keystroke and reads
/// [current] synchronously, so there is no need to notify listeners on writes.
class SearchFocusRegistry {
  final List<FocusNode> _claims = <FocusNode>[];
  final List<FocusNode> _fallbacks = <FocusNode>[];
  final Map<FocusNode, VoidCallback> _activators = <FocusNode, VoidCallback>{};

  /// The most recent regular claimant still holding a claim, else the most
  /// recent fallback, or null.
  FocusNode? get current => _claims.isNotEmpty
      ? _claims.last
      : (_fallbacks.isEmpty ? null : _fallbacks.last);

  /// Claims the slot for [node], moving it to the top. Assigning `null` drops
  /// every claim.
  set current(FocusNode? node) {
    if (node == null) {
      _claims.clear();
      _fallbacks.clear();
      _activators.clear();
      return;
    }
    claim(node);
  }

  /// Claims the slot for [node], moving it to the top of its tier. [onActivate]
  /// runs in place of `node.requestFocus()` when `/` is pressed — for a field
  /// that has to be revealed before it can take focus. A [fallback] claim is
  /// [current] only while no regular claim is held.
  void claim(
    FocusNode node, {
    VoidCallback? onActivate,
    bool fallback = false,
  }) {
    _claims.remove(node);
    _fallbacks.remove(node);
    (fallback ? _fallbacks : _claims).add(node);
    if (onActivate == null) {
      _activators.remove(node);
    } else {
      _activators[node] = onActivate;
    }
  }

  /// Gives [node]'s claim up, wherever it sits; whoever claimed before it
  /// becomes [current] again. A no-op for a node that holds no claim.
  void release(FocusNode node) {
    _claims.remove(node);
    _fallbacks.remove(node);
    _activators.remove(node);
  }

  /// What `/` does: runs the current claimant's `onActivate`, or focuses it.
  void activate() {
    final node = current;
    if (node == null) return;
    final open = _activators[node];
    if (open != null) {
      open();
    } else {
      node.requestFocus();
    }
  }
}
