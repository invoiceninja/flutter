import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  /// Hands the launching URL to `app_links` on a cold start.
  ///
  /// Without this, a link tapped with the app not running does **nothing**.
  /// Under the UIScene lifecycle UIKit delivers it only in `connectionOptions`;
  /// the engine's `sceneWillConnectFallback:` converts that to launchOptions and
  /// calls `application:didFinishLaunchingWithOptions:`, which app_links (6.4.1)
  /// does not implement — it implements `application:openURL:options:` and
  /// `application:continue:restorationHandler:`, neither of which UIKit calls
  /// here. The only other delivery is Flutter's built-in deep linking, which
  /// `FlutterDeepLinkingEnabled` deliberately turns off (it would bypass
  /// DeepLinkRouter's validation, company switch and biometric hold).
  ///
  /// Warm links are unaffected: `scene:openURLContexts:` and
  /// `scene:continueUserActivity:` both fall back to the app-delegate plugin
  /// list, which app_links is on.
  ///
  /// `handleLink` sets `initialLink` only when it is nil and replays through the
  /// event sink once one attaches, so calling it before plugin registration is
  /// safe and DeepLinkRouter's existing double-delivery de-dup still applies.
  ///
  /// See docs/upstream-workarounds.md — remove when app_links handles scenes.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let url = connectionOptions.urlContexts.first?.url {
      AppLinks.shared.handleLink(url: url)
    } else if let url = connectionOptions.userActivities
      .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?
      .webpageURL
    {
      AppLinks.shared.handleLink(url: url)
    }
  }
}
