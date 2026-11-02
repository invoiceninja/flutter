import Flutter
import UIKit
import app_links

/// No deep-link code here: app_links (7.x) registers its own scene delegate
/// and reads a cold-start link from `connectionOptions` itself. Through 6.4.1
/// it did not, and this class handed the launch URL over by hand — see
/// docs/upstream-workarounds.md § 11.
///
/// App-icon quick actions (Info.plist `UIApplicationShortcutItems`) are the one
/// thing handled here. Each carries an `invoiceninja://app/…` link in its
/// `userInfo`, handed straight to app_links (its shared `handleLink`) —
/// so `DeepLinkRouter` validates it, holds it while the app is locked, and
/// switches company, like any other link. Handed over, not reopened through
/// `UIApplication.open`: at a cold start that would race the scene coming up,
/// while `handleLink` records it as the initial link until Dart listens.
/// (docs/home-screen-widgets.md)
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // A cold start from a quick action.
    if let item = connectionOptions.shortcutItem { Self.open(item) }
  }

  override func windowScene(
    _ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(Self.open(shortcutItem))
  }

  /// Hands [item]'s link to app_links; false for an item that carries none
  /// we accept.
  @discardableResult
  static func open(_ item: UIApplicationShortcutItem) -> Bool {
    guard
      let link = item.userInfo?["link"] as? String,
      let url = URL(string: link),
      url.scheme == "invoiceninja", url.host == "app"
    else { return false }
    AppLinks.shared.handleLink(url: url)
    return true
  }
}
