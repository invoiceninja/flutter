import 'package:web/web.dart' as web;

/// Web half of the [browser_chrome] seam.
///
/// `browser` and `minimal-ui` are the two display modes that keep the address
/// bar / navigation controls on screen. `standalone` and `fullscreen` — an
/// installed PWA, which this app's `manifest.json` asks for — show neither, so
/// the in-app arrows have to stay.
///
/// Both failure directions are deliberate: when the query cannot be answered
/// we report `false`, which *keeps* the in-app arrows. A redundant pair of
/// arrows is a cosmetic wart; missing ones strand a touch user who followed a
/// cross-entity link with no keyboard and no toolbar.
bool browserProvidesHistoryControls() {
  try {
    return web.window.matchMedia('(display-mode: browser)').matches ||
        web.window.matchMedia('(display-mode: minimal-ui)').matches;
  } catch (_) {
    return false;
  }
}
