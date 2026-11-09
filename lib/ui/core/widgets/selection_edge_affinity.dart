import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// [selection] with every endpoint that sits exactly at the start or the end
/// of a text node given downstream affinity, or [selection] itself when none
/// needs it.
///
/// super_editor deletes an expanded selection with `DeleteContentCommand`,
/// which compares an endpoint against the node's `beginningPosition` /
/// `endPosition` with `==` — affinity included. The caret position it then
/// moves to comes from `getDocumentPositionAfterExpandedDeletion`, which
/// compares with `isEquivalentTo`. A selection ending at the end of a node with
/// upstream affinity (⌘A, a drag or Shift+End to the end of a line) is "all
/// deleted, keep the top node" to the second and "empty the bottom node, delete
/// the top one" to the first, so the selection lands on a node that no longer
/// exists. Paste then throws in the IME serializer and in `PasteEditorCommand`
/// (Sentry FLUTTER-ADMIN-W, FLUTTER-ADMIN-V); typing over the selection takes
/// the same path.
///
/// At a node's edge the two affinities draw the same caret and highlight —
/// there is no soft wrap before offset 0 or after the last character — so the
/// rewrite changes nothing the user can see. → `docs/upstream-workarounds.md`
DocumentSelection? withDownstreamEdgeAffinity(
  Document document,
  DocumentSelection? selection,
) {
  if (selection == null || selection.isCollapsed) return selection;
  final base = _downstreamAtEdge(document, selection.base);
  final extent = _downstreamAtEdge(document, selection.extent);
  if (identical(base, selection.base) && identical(extent, selection.extent)) {
    return selection;
  }
  return DocumentSelection(base: base, extent: extent);
}

DocumentPosition _downstreamAtEdge(
  Document document,
  DocumentPosition position,
) {
  final nodePosition = position.nodePosition;
  if (nodePosition is! TextNodePosition ||
      nodePosition.affinity == TextAffinity.downstream) {
    return position;
  }
  final node = document.getNodeById(position.nodeId);
  if (node is! TextNode) return position;
  final offset = nodePosition.offset;
  if (offset != 0 && offset != node.text.length) return position;
  return DocumentPosition(
    nodeId: position.nodeId,
    nodePosition: TextNodePosition(offset: offset),
  );
}
