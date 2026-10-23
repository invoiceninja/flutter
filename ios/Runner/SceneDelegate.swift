import Flutter
import UIKit

/// No deep-link code here: app_links (7.x) registers its own scene delegate
/// and reads a cold-start link from `connectionOptions` itself. Through 6.4.1
/// it did not, and this class handed the launch URL over by hand — see
/// docs/upstream-workarounds.md § 11.
class SceneDelegate: FlutterSceneDelegate {

}
