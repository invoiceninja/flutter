import 'package:flutter/widgets.dart';

/// The app-wide focus traversal policy: [ReadingOrderTraversalPolicy] that
/// never measures a focus node whose render box was never laid out.
///
/// A page covered by an opaque page above it (every page under the top of a
/// restored or deep-linked route stack, and the stacked pages of a
/// `StatefulShellRoute` branch) is mounted but skipped by the `Overlay`'s
/// layout. Its route only marks its own focus scope `skipTraversal`, so the
/// fields inside it are still candidates whenever focus sits in a scope above
/// that Navigator — and Tab, Shift+Tab or an arrow key then reads their
/// `FocusNode.rect`, whose size getter throws `RenderBox was not laid out`
/// (Sentry FLUTTER-ADMIN-H/J/S/Z, macOS and Linux). Such a node is not on
/// screen, so leaving it out is the correct traversal anyway.
///
/// Installed once above the router (`main.dart`); every Navigator copies the
/// enclosing policy, so it reaches every route. → `docs/upstream-workarounds.md`
class LaidOutReadingOrderTraversalPolicy extends ReadingOrderTraversalPolicy {
  LaidOutReadingOrderTraversalPolicy({super.requestFocusCallback});

  /// Whether [node] can be measured: its render object is attached and, if a
  /// box, has been given a size.
  static bool isLaidOut(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    final object = context.findRenderObject();
    if (object == null || !object.attached) return false;
    return object is! RenderBox || object.hasSize;
  }

  // Tab / Shift+Tab, and first / last focus, all sort through here. The
  // reading-order sort never reads `currentNode` unless it is in the list.
  // Focus can itself be on an unmeasurable node — a field left focused on a
  // page that was then covered — and the caller needs it in the result to
  // step from, so it goes first: Tab leaves it for the first visible node.
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final sorted = super.sortDescendants(
      descendants.where(isLaidOut),
      currentNode,
    );
    if (isLaidOut(currentNode) || !descendants.contains(currentNode)) {
      return sorted;
    }
    return [currentNode, ...sorted];
  }

  // The directional mixin reads `nearestScope.traversalDescendants` itself,
  // with no hook to filter it, so the unmeasurable nodes are taken out of
  // traversal for the length of the (synchronous) call and put back after.
  // From an unmeasurable node there is no "to the right of", so it is a no-op.
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final scope = currentNode.nearestScope;
    if (scope == null) return super.inDirection(currentNode, direction);
    final from = scope.focusedChild ?? currentNode;
    if (!isLaidOut(from) || !isLaidOut(currentNode)) return false;
    final hidden = [
      for (final n in scope.traversalDescendants)
        if (!isLaidOut(n)) n,
    ];
    for (final n in hidden) {
      n.skipTraversal = true;
    }
    try {
      return super.inDirection(currentNode, direction);
    } finally {
      for (final n in hidden) {
        n.skipTraversal = false;
      }
    }
  }
}
