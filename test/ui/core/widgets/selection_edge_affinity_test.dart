import 'package:admin/ui/core/widgets/selection_edge_affinity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

/// super_editor deletes an expanded selection with an affinity-sensitive edge
/// check, and paste places the caret with an affinity-blind one. A selection
/// ending at the end of a node with upstream affinity therefore left the
/// selection on a node the deletion had removed, and paste threw (Sentry
/// FLUTTER-ADMIN-V, FLUTTER-ADMIN-W).
void main() {
  final documents = <String, List<DocumentNode> Function()>{
    'paragraphs': () => [
      ParagraphNode(id: 'a', text: AttributedText('first')),
      ParagraphNode(id: 'b', text: AttributedText('second')),
      ParagraphNode(id: 'c', text: AttributedText('third')),
    ],
    'list items': () => [
      ListItemNode.unordered(id: 'a', text: AttributedText('first')),
      ListItemNode.unordered(id: 'b', text: AttributedText('second')),
      ParagraphNode(id: 'c', text: AttributedText('third')),
    ],
    'empty paragraphs': () => [
      ParagraphNode(id: 'a', text: AttributedText('')),
      ParagraphNode(id: 'b', text: AttributedText('second')),
      ParagraphNode(id: 'c', text: AttributedText('')),
    ],
  };

  NodePosition at(TextNode node, String where, TextAffinity affinity) {
    final length = node.text.length;
    final offset = switch (where) {
      'start' => 0,
      'end' => length,
      _ => length ~/ 2,
    };
    return TextNodePosition(offset: offset, affinity: affinity);
  }

  /// Every multi-node selection over every document — each end at a node's
  /// start, middle or end, with either affinity, in both directions.
  Iterable<
    ({String label, MutableDocument document, DocumentSelection selection})
  >
  selections() sync* {
    const places = ['start', 'mid', 'end'];
    for (final MapEntry(key: name, value: nodes) in documents.entries) {
      for (final (top, bottom) in [('a', 'b'), ('a', 'c'), ('b', 'c')]) {
        for (final topAt in places) {
          for (final bottomAt in places) {
            for (final topAffinity in TextAffinity.values) {
              for (final bottomAffinity in TextAffinity.values) {
                for (final reversed in [false, true]) {
                  final document = MutableDocument(nodes: nodes());
                  final from = DocumentPosition(
                    nodeId: top,
                    nodePosition: at(
                      document.getNodeById(top)! as TextNode,
                      topAt,
                      topAffinity,
                    ),
                  );
                  final to = DocumentPosition(
                    nodeId: bottom,
                    nodePosition: at(
                      document.getNodeById(bottom)! as TextNode,
                      bottomAt,
                      bottomAffinity,
                    ),
                  );
                  yield (
                    label:
                        '$name $top/$topAt/${topAffinity.name} → '
                        '$bottom/$bottomAt/${bottomAffinity.name}'
                        '${reversed ? ' (reversed)' : ''}',
                    document: document,
                    selection: reversed
                        ? DocumentSelection(base: to, extent: from)
                        : DocumentSelection(base: from, extent: to),
                  );
                }
              }
            }
          }
        }
      }
    }
  }

  bool dangles(MutableDocument document, DocumentSelection? selection) =>
      selection != null &&
      (document.getNodeById(selection.base.nodeId) == null ||
          document.getNodeById(selection.extent.nodeId) == null);

  /// The synchronous half of `CommonEditorOperations.paste`: compute where the
  /// paste will land, delete the selection, collapse onto that spot.
  List<String> deleteLikePaste({required bool normalize}) {
    final failures = <String>[];
    for (final (:label, :document, :selection) in selections()) {
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(
        document: document,
        composer: composer,
      );
      final applied = normalize
          ? withDownstreamEdgeAffinity(document, selection)!
          : selection;
      composer.setSelectionWithReason(applied);
      final pastePosition =
          CommonEditorOperations.getDocumentPositionAfterExpandedDeletion(
            document: document,
            selection: applied,
          );
      if (pastePosition == null) continue;
      editor.execute([
        DeleteContentRequest(documentRange: applied),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: pastePosition),
          SelectionChangeType.deleteContent,
          SelectionReason.userInteraction,
        ),
      ]);
      if (dangles(document, composer.selection)) failures.add(label);
    }
    return failures;
  }

  test('unpatched super_editor leaves the selection on a deleted node '
      '(pins the upstream bug)', () {
    expect(
      deleteLikePaste(normalize: false),
      contains('paragraphs a/start/downstream → b/end/upstream'),
      reason: 'when this stops failing, super_editor has fixed it',
    );
  });

  test('with the edges normalized, no selection is left dangling', () {
    expect(deleteLikePaste(normalize: true), isEmpty);
  });

  testWidgets('a real paste over every normalized selection lands', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData' ? {'text': 'X'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final failures = <String>[];
    for (final (:label, :document, :selection) in selections()) {
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(
        document: document,
        composer: composer,
      );
      composer.setSelectionWithReason(
        withDownstreamEdgeAffinity(document, selection),
      );
      CommonEditorOperations(
        document: document,
        editor: editor,
        composer: composer,
        documentLayoutResolver: () => throw UnimplementedError(),
      ).paste();
      await tester.pump();
      if (tester.takeException() != null ||
          dangles(document, composer.selection)) {
        failures.add(label);
      }
    }
    expect(failures, isEmpty);
  });

  test('leaves a collapsed selection, and a mid-node endpoint, alone', () {
    final document = MutableDocument(
      nodes: [
        ParagraphNode(id: 'a', text: AttributedText('first')),
        ParagraphNode(id: 'b', text: AttributedText('second')),
      ],
    );
    const collapsed = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: 'a',
        nodePosition: TextNodePosition(
          offset: 5,
          affinity: TextAffinity.upstream,
        ),
      ),
    );
    expect(withDownstreamEdgeAffinity(document, collapsed), same(collapsed));

    const midNode = DocumentSelection(
      base: DocumentPosition(
        nodeId: 'a',
        nodePosition: TextNodePosition(offset: 2),
      ),
      extent: DocumentPosition(
        nodeId: 'b',
        nodePosition: TextNodePosition(
          offset: 3,
          affinity: TextAffinity.upstream,
        ),
      ),
    );
    expect(withDownstreamEdgeAffinity(document, midNode), same(midNode));
  });

  test('rewrites only the endpoint at an edge', () {
    final document = MutableDocument(
      nodes: [
        ParagraphNode(id: 'a', text: AttributedText('first')),
        ParagraphNode(id: 'b', text: AttributedText('second')),
      ],
    );
    final result = withDownstreamEdgeAffinity(
      document,
      const DocumentSelection(
        base: DocumentPosition(
          nodeId: 'a',
          nodePosition: TextNodePosition(
            offset: 2,
            affinity: TextAffinity.upstream,
          ),
        ),
        extent: DocumentPosition(
          nodeId: 'b',
          nodePosition: TextNodePosition(
            offset: 6,
            affinity: TextAffinity.upstream,
          ),
        ),
      ),
    )!;
    expect(
      result.base.nodePosition,
      const TextNodePosition(offset: 2, affinity: TextAffinity.upstream),
    );
    expect(result.extent.nodePosition, const TextNodePosition(offset: 6));
  });
}
