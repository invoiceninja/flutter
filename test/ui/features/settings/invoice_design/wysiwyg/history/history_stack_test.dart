import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/history/history_stack.dart';

DesignBlock _b(String id) => DesignBlock(
  id: id,
  type: 't',
  gridPosition: const GridPosition(x: 0, y: 0, w: 1, h: 1),
);

void main() {
  group('DesignerHistoryStack', () {
    test('starts empty and reports false for canUndo/canRedo', () {
      final h = DesignerHistoryStack<List<DesignBlock>>();
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
    });

    test('record + undo returns the recorded snapshot', () {
      final h = DesignerHistoryStack<List<DesignBlock>>();
      final initial = [_b('a')];
      h.record(initial);
      expect(h.canUndo, isTrue);
      final next = [_b('a'), _b('b')];
      expect(h.undo(next), equals(initial));
      expect(h.canRedo, isTrue);
      expect(h.canUndo, isFalse);
    });

    test('undo + redo round-trips the blocks list', () {
      final h = DesignerHistoryStack<List<DesignBlock>>();
      final v0 = [_b('a')];
      final v1 = [_b('a'), _b('b')];
      h.record(v0); // snapshot v0 before applying v1
      final undone = h.undo(v1);
      expect(undone, equals(v0));
      final redone = h.redo(v0);
      expect(redone, equals(v1));
    });

    test('record clears the redo tail', () {
      final h = DesignerHistoryStack<List<DesignBlock>>();
      final v0 = [_b('a')];
      final v1 = [_b('a'), _b('b')];
      final v2 = [_b('a'), _b('b'), _b('c')];
      h.record(v0);
      h.undo(v1); // v0 → undo stack empty, v1 → redo stack
      expect(h.canRedo, isTrue);
      h.record(v0); // branching off: redo tail wiped
      expect(h.canRedo, isFalse);
      // The new branch's undo still works.
      expect(h.undo(v2), equals(v0));
    });

    test('undo/redo return null when nothing to apply', () {
      final h = DesignerHistoryStack<List<DesignBlock>>();
      expect(h.undo([_b('a')]), isNull);
      expect(h.redo([_b('a')]), isNull);
    });

    test('cap (maxSize) drops oldest entries', () {
      final h = DesignerHistoryStack<List<DesignBlock>>(maxSize: 3);
      for (var i = 0; i < 5; i++) {
        h.record([_b('v$i')]);
      }
      expect(h.undoDepth, 3);
      // Oldest 'v0' / 'v1' fell off; first undo returns 'v4' (most recent).
      final live = [_b('current')];
      expect(h.undo(live), equals([_b('v4')]));
    });

    test('clear empties both stacks', () {
      final h = DesignerHistoryStack<List<DesignBlock>>();
      h.record([_b('a')]);
      h.undo([_b('b')]);
      expect(h.canRedo, isTrue);
      h.clear();
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
    });

    test('discardLast drops the newest snapshot only', () {
      // A gesture records on its first frame; one that then changed nothing
      // must not leave a step whose undo visibly does nothing.
      final h = DesignerHistoryStack<List<DesignBlock>>();
      h.record([_b('a')]);
      h.record([_b('b')]);
      h.discardLast();
      expect(h.undoDepth, 1);
      expect(h.undo([_b('live')]), equals([_b('a')]));
      h.discardLast(); // nothing left — a no-op, not an error
      expect(h.canUndo, isFalse);
    });

    test('snapshots are independent of caller mutations (shallow copy)', () {
      // List<DesignBlock>.of copies the list, so the caller can mutate
      // their own list without affecting the snapshot.
      final h = DesignerHistoryStack<List<DesignBlock>>();
      final mutable = [_b('a')];
      h.record(mutable);
      mutable.add(_b('b'));
      expect(h.undo(const <DesignBlock>[]), equals([_b('a')]));
    });
  });
}
