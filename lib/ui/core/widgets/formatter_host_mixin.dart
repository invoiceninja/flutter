import 'package:flutter/widgets.dart';

import 'package:admin/app/services.dart';
import 'package:admin/utils/formatting.dart';

/// Mixed into a [State] that needs a [Formatter] tied to the current
/// company. Holds the resolved formatter and a "loading for" company id so
/// late futures from a previous company can be ignored when the user
/// switches workspaces mid-flight.
///
/// Typical use:
///
/// ```dart
/// class _MyScreenState extends State<MyScreen> with FormatterHostMixin {
///   late final Services _services;
///   late String _companyId;
///
///   @override
///   void initState() {
///     super.initState();
///     _services = context.read<Services>();
///     _companyId = _services.auth.session.value!.currentCompanyId;
///     loadFormatter(_services, _companyId);
///   }
///
///   void _onCompanyChanged(String newId) {
///     _companyId = newId;
///     clearFormatter();
///     loadFormatter(_services, newId);
///   }
/// }
/// ```
mixin FormatterHostMixin<T extends StatefulWidget> on State<T> {
  Formatter? _formatter;
  String? _formatterLoadingFor;

  /// Resolved formatter, or null while the [formatterFor] future is in
  /// flight. Money columns typically render as `—` while null.
  Formatter? get formatter => _formatter;

  /// Kick off a `formatterFor(companyId)` future and adopt its result.
  /// Safe to call repeatedly: stale futures (where [companyId] no longer
  /// matches the in-progress request) are dropped.
  void loadFormatter(Services services, String companyId) {
    _formatterLoadingFor = companyId;
    // Fast path. `Services` memoizes the per-company Formatter and the list
    // scaffold warms it in its own `initState` (`wantsFormatter`), so a detail
    // screen opened from a list almost always resolves right here — no async
    // gap, so no frame where money renders as `—` and no FormatterScope
    // mount/unmount. `_formatterReady` is cleared in lockstep with the future
    // cache by `invalidateFormatter`, so this can never be staler than the
    // async path.
    //
    // `setState`, not a plain assign: `clearFormatter()` early-returns without
    // marking dirty when nothing was loaded yet, so a caller doing
    // `clearFormatter(); loadFormatter(...)` would otherwise get the new value
    // with no rebuild scheduled. It is a provable no-op from `initState` (the
    // element is already dirty for its first build).
    final ready = services.formatterIfReady(companyId);
    if (ready != null) {
      setState(() => _formatter = ready);
      return;
    }
    services.formatterFor(companyId).then((f) {
      // Discard if the widget is gone or the user switched company while
      // the future was in flight — otherwise the new company would briefly
      // render with the previous company's currency settings.
      if (!mounted || _formatterLoadingFor != companyId) return;
      setState(() => _formatter = f);
    });
  }

  /// Drop the current formatter so the UI renders the `—` placeholder
  /// until a follow-up [loadFormatter] resolves. Call this before
  /// [loadFormatter] when the company id changes so the previous
  /// company's currency doesn't briefly flash on screen.
  void clearFormatter() {
    if (_formatter == null && _formatterLoadingFor == null) return;
    setState(() {
      _formatter = null;
      _formatterLoadingFor = null;
    });
  }
}
