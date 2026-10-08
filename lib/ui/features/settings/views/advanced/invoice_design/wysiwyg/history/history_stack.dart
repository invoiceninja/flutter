/// Bounded undo/redo history for the visual designer.
///
/// Each snapshot is the state to return to — taken **before** a change is
/// applied — so `undo()` reverts it. A new change after an undo drops the redo
/// tail. The view model snapshots the whole design template (blocks *and*
/// document settings), which is immutable, so the stack stores it as is; a
/// `List` is copied on the way in so a caller mutating its own list cannot
/// reach back into history.
class DesignerHistoryStack<T> {
  DesignerHistoryStack({this.maxSize = 50})
    : assert(maxSize > 0, 'maxSize must be positive');

  final int maxSize;

  /// `_undoStack.last` is the most recent snapshot, popped by the next
  /// `undo()`.
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Debug accessor — current undo depth (capped at [maxSize]).
  int get undoDepth => _undoStack.length;
  int get redoDepth => _redoStack.length;

  // `toList()` keeps the list's own element type, so the cast back holds.
  T _own(T value) => value is List ? value.toList() as T : value;

  /// Record [current] as the state the next `undo()` returns to. Call this
  /// BEFORE applying a change. Clears the redo tail.
  void record(T current) {
    _undoStack.add(_own(current));
    if (_undoStack.length > maxSize) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Drop the most recent snapshot — for a gesture that recorded on its first
  /// frame and then changed nothing, which would otherwise leave an undo step
  /// that visibly does nothing.
  void discardLast() {
    if (_undoStack.isNotEmpty) _undoStack.removeLast();
  }

  /// Step backward. Returns the state to revert to, or null when there is
  /// nothing to undo. [current] goes onto the redo stack.
  T? undo(T current) {
    if (_undoStack.isEmpty) return null;
    final previous = _undoStack.removeLast();
    _redoStack.add(_own(current));
    if (_redoStack.length > maxSize) {
      _redoStack.removeAt(0);
    }
    return previous;
  }

  /// Step forward. Returns the state to fast-forward to, or null when there
  /// is nothing to redo. [current] goes back onto the undo stack.
  T? redo(T current) {
    if (_redoStack.isEmpty) return null;
    final next = _redoStack.removeLast();
    _undoStack.add(_own(current));
    if (_undoStack.length > maxSize) {
      _undoStack.removeAt(0);
    }
    return next;
  }

  /// Drop both stacks.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
