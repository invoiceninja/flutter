import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Hands a universal link to `app_links`, which cannot receive one on macOS:
  /// its own `application(_:continue:restorationHandler:)` is commented out in
  /// the shipped package (AppLinksMacosPlugin.swift), and unlike iOS the macOS
  /// embedder has no built-in deep linking to fall back on — there is no
  /// `FlutterDeepLinkingEnabled` in the macOS engine at all. Custom-scheme links
  /// are unaffected; the plugin handles those through NSAppleEventManager.
  ///
  /// Without this the associated-domains entitlement would be worse than
  /// nothing: macOS would take the click away from the browser and then do
  /// nothing at all. The two must be added — and reverted — together.
  ///
  /// See docs/upstream-workarounds.md.
  override func application(
    _ application: NSApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
  ) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL
    else {
      return false
    }
    AppLinks.shared.handleLink(link: url.absoluteString)
    return true
  }
}
