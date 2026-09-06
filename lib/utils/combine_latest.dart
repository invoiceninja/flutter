import 'dart:async';

/// Minimal combine-latest (the project has no rxdart). Emits once **both**
/// sources have produced a value, then on every subsequent event from either.
///
/// The list stack uses this inside `GenericListViewModel.watchPage()` to fold a
/// second reactive source into the entity page stream — company settings for
/// gateways, the tag-name cache for grouped products. That placement is the
/// point: `notifyListeners()` cannot re-run `watchPage()`'s `.map()`, so
/// per-row state derived from anything *outside* the entity table has to enter
/// through the stream or it goes stale until an unrelated write.
///
/// **Build both source streams inside `watchPage()`, never capture instances.**
/// `watchPage()` is re-invoked on every re-subscribe (load-more, sync re-arm,
/// any filter/sort change). A Drift `.watch().map(...)` that has already been
/// listened to may not re-emit for a second listener, and because this only
/// emits once both sides have a value, one silent source stalls the whole list
/// at empty rather than failing loudly.
///
/// Errors from either source are forwarded, so the caller's existing stream
/// `onError` handling applies unchanged.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        latestA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        latestB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
