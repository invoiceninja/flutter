import 'package:flutter/widgets.dart';

/// "Scroll to and flash the field labelled [label] once [route] is showing" —
/// what a settings search hit asks for as it navigates.
@immutable
class SettingsRevealRequest {
  const SettingsRevealRequest({
    required this.route,
    required this.label,
    required this.seq,
    required this.at,
  });

  /// The location the field lives at (`/settings/company_details/address`).
  final String route;

  /// The field's label as rendered — `Localization.lookup(fieldKey)`. The
  /// page is searched for this text; nothing on a settings screen carries an
  /// anchor.
  final String label;

  /// Bumped on every request, so searching for the same field twice reveals
  /// it twice — a plain value would go silent on an unchanged one.
  final int seq;

  final DateTime at;
}

/// Carries a settings search hit's field across the navigation it triggers,
/// to the `SettingsFormShell` that renders it. Provided once at the app root
/// (`main.dart`) and read as `context.read<SettingsRevealController?>()`, so a
/// widget test that pumps a settings page without it simply gets no reveal. Same shape as
/// `ActivityRevealController` (`docs/comments-and-activity.md` § A one-shot
/// reveal outlives its consumer): the request **persists** rather than being a
/// pure event, because the page it targets is usually not mounted yet when the
/// hit is tapped.
///
/// Held in memory, never in the URL: `nav_state` and the history stack record
/// the full location, so a `?field=` would replay the flash on every restart
/// and every Back. A request nobody consumes goes stale after [lifetime], so a
/// hit whose page never appeared (a redirect, a refused navigation) can't fire
/// on some later visit.
class SettingsRevealController extends ChangeNotifier {
  SettingsRevealController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const lifetime = Duration(seconds: 3);

  final DateTime Function() _now;
  SettingsRevealRequest? _request;
  int _seq = 0;

  /// The outstanding request, or null once it was consumed or went stale.
  SettingsRevealRequest? get request {
    final r = _request;
    if (r == null) return null;
    if (_now().difference(r.at) > lifetime) {
      _request = null;
      return null;
    }
    return r;
  }

  void reveal({required String route, required String label}) {
    _request = SettingsRevealRequest(
      route: route,
      label: label,
      seq: ++_seq,
      at: _now(),
    );
    notifyListeners();
  }

  /// Marks [seq] handled — found and flashed, or looked for on its own page
  /// and given up on. A newer request is left alone.
  void consume(int seq) {
    if (_request?.seq == seq) _request = null;
  }
}
