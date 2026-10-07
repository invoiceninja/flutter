import 'package:flutter/widgets.dart';

/// Fires when the user asks a record screen to refresh — by pulling the page
/// down, or with `R`.
///
/// The screen re-fetches the record itself; this is how the *embedded lists*
/// under its tabs find out. They sit several layers down inside lazily built
/// tab bodies, the screen holds no handle on their view models, and only the
/// one currently on stage should answer (see `EntityListScreenScaffold`'s
/// `_tickerActive`) — so the screen broadcasts and each list decides.
class DetailRefreshSignal extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Publishes a record screen's [DetailRefreshSignal] to the lists embedded in
/// it. Mirrors `DetailScrollScope`, which does the same job for pagination.
class DetailRefreshScope extends InheritedWidget {
  const DetailRefreshScope({
    super.key,
    required this.signal,
    required super.child,
  });

  final DetailRefreshSignal signal;

  static DetailRefreshSignal? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailRefreshScope>()?.signal;

  @override
  bool updateShouldNotify(DetailRefreshScope oldWidget) =>
      !identical(oldWidget.signal, signal);
}
