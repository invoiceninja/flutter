import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareIntake") {
      ShareIntake.register(messenger: registrar.messenger())
    }
  }
}

/// The app's half of the iOS share target (invoiceninja/flutter#173).
///
/// The Share Extension can't write into this app's sandbox, so it leaves each
/// share in the App Group container — the files in `SharedIntake/<uuid>/`, and
/// a `SharedIntake/<uuid>.json` listing them, written last. `takeShares` moves
/// every listed share into `Application Support/shared_intake/<uuid>/` (what
/// Dart's `getApplicationSupportDirectory()` returns — `SharedIntakeFiles`), so
/// the outbox's `local_path` points into the app's own sandbox, and returns
/// them as `{path, name, issue?}`. Dart pulls (`AppShareIntake`): at start, on
/// every resume, and when the extension opens `invoiceninja://share`.
enum ShareIntake {
  /// Also in both entitlements files and `ShareViewController.swift` —
  /// `test/lint/share_target_wiring_test.dart` keeps them in step.
  static let appGroup = "group.com.invoiceninja.admin"

  /// The extension's folder in the group container.
  private static let inboxFolder = "SharedIntake"

  /// Same name as `SharedIntakeFiles.kFolderName`.
  private static let intakeFolder = "shared_intake"

  /// Same name as `AppShareIntake.kChannel`. Held so the handler outlives
  /// this call.
  private static var channel: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "invoice_ninja/share_intake", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "takeShares": result(takeShares())
      default: result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private static func takeShares() -> [[String: Any]] {
    let fm = FileManager.default
    guard
      let container = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
      let support = try? fm.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
        create: true)
    else { return [] }
    let inbox = container.appendingPathComponent(inboxFolder, isDirectory: true)
    guard
      let listed = try? fm.contentsOfDirectory(
        at: inbox, includingPropertiesForKeys: [.creationDateKey])
    else { return [] }
    let manifests = listed.filter { $0.pathExtension == "json" }.sorted { a, b in
      let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
      let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
      return da < db
    }

    var out: [[String: Any]] = []
    for manifest in manifests {
      let shareId = manifest.deletingPathExtension().lastPathComponent
      let source = inbox.appendingPathComponent(shareId, isDirectory: true)
      let target = support
        .appendingPathComponent(intakeFolder, isDirectory: true)
        .appendingPathComponent(shareId, isDirectory: true)
      defer {
        try? fm.removeItem(at: manifest)
        try? fm.removeItem(at: source)
      }
      guard
        let data = try? Data(contentsOf: manifest),
        let entries = (try? JSONSerialization.jsonObject(with: data)) as? [[String: String]]
      else { continue }
      for entry in entries {
        guard let name = entry["name"], !name.isEmpty else { continue }
        var item: [String: Any] = ["name": name, "path": ""]
        if let issue = entry["issue"] { item["issue"] = issue }
        if let relative = entry["path"], !relative.isEmpty {
          let file = inbox.appendingPathComponent(relative).standardizedFileURL
          // Only ever a file of this share's own folder.
          guard file.path.hasPrefix(source.standardizedFileURL.path + "/") else { continue }
          let destination = target.appendingPathComponent(file.lastPathComponent)
          do {
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.moveItem(at: file, to: destination)
            item["path"] = destination.path
            item["name"] = destination.lastPathComponent
          } catch {
            item["issue"] = "unreadable"
          }
        }
        out.append(item)
      }
    }
    pruneOrphans(in: inbox, listed: listed)
    return out
  }

  /// What an extension killed mid-share leaves behind, which nothing will
  /// ever claim: a share folder whose manifest was never written, and the
  /// temporary file of an interrupted atomic manifest write. A day's grace, so
  /// a share being written right now is never touched.
  private static func pruneOrphans(in inbox: URL, listed: [URL]) {
    let fm = FileManager.default
    let manifests = Set(
      listed.filter { $0.pathExtension == "json" }
        .map { $0.deletingPathExtension().lastPathComponent })
    let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
    for entry in listed where entry.pathExtension != "json" {
      guard !manifests.contains(entry.lastPathComponent),
        let values = try? entry.resourceValues(forKeys: [.contentModificationDateKey]),
        let modified = values.contentModificationDate,
        modified < cutoff
      else { continue }
      try? fm.removeItem(at: entry)
    }
  }
}
