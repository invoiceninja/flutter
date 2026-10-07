import 'dart:async';

/// One subscription to a source stream, shared by however many listeners come
/// and go, and torn down on demand.
///
/// The sidebar keeps its Drift watches behind these so a rebuild does not
/// re-subscribe every `StreamBuilder`. It owns a broadcast controller fed by a
/// single source subscription rather than using `Stream.asBroadcastStream()`,
/// which does not cancel its source when listeners drop — that would leak a
/// live Drift query per replaced cache generation.
///
/// **Replays the latest value to each new listener.** A bare broadcast
/// controller hands a late listener nothing until the source next emits, so a
/// `StreamBuilder` that is re-created — the rail collapsing, a row moving in
/// the menu — would sit empty until then. That was survivable while a count
/// stream re-emitted on every write to its table. Count streams are `distinct`
/// now, so "the next emission" can be the next time the number changes: without
/// the replay, a badge could stay blank indefinitely.
class CachedStream<T> {
  CachedStream(Stream<T> source) {
    _sub = source.listen(
      (value) {
        _latest = value;
        _hasValue = true;
        _controller.add(value);
      },
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  final StreamController<T> _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _sub;
  T? _latest;
  bool _hasValue = false;

  /// The latest value the source has emitted, or null before the first one —
  /// for a `StreamBuilder`'s `initialData`, so a re-created builder paints the
  /// value on its first frame instead of one frame after subscribing.
  T? get latest => _hasValue ? _latest : null;

  /// The shared stream. One object for the life of the cache: a
  /// `StreamBuilder` re-subscribes whenever it is handed a different one.
  late final Stream<T> stream = Stream<T>.multi((listener) {
    if (_hasValue) listener.add(_latest as T);
    final forward = _controller.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = forward.cancel;
  }, isBroadcast: true);

  void close() {
    unawaited(_sub.cancel());
    unawaited(_controller.close());
  }
}
