import Flutter
import ImageIO
import UIKit
import Vision

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReceiptOcr") {
      ReceiptOcr.register(messenger: registrar.messenger())
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

/// The iOS half of `invoice_ninja/receipt_ocr` (`ReceiptTextRecognizer`,
/// docs/receipt-ocr.md): Apple Vision reads a receipt photo or a rasterised
/// PDF page on the device. Off the main thread; replies on it.
enum ReceiptOcr {
  /// Held so the handler outlives the registration call.
  private static var channel: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "invoice_ninja/receipt_ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in handle(call, result) }
    self.channel = channel
  }

  private static let queue = DispatchQueue(label: "receipt_ocr", qos: .userInitiated)

  /// The longest side Vision is handed. A 48 MP photo decoded whole is
  /// ~190 MB; a receipt reads fine at this size.
  private static let maxPixelSize = 3000

  /// `[{text, x, y, w, h}]` in normalised top-left coordinates, or a
  /// `FlutterError` whose code says why (`unsupported_image`, `failed`).
  /// Never the recognised text in an error: a receipt is personal data.
  static func recognize(path: String?, bytes: Data?) -> Any {
    let source: CGImageSource?
    if let path = path {
      source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
    } else if let bytes = bytes {
      source = CGImageSourceCreateWithData(bytes as CFData, nil)
    } else {
      source = nil
    }
    // The thumbnail path applies the photo's EXIF orientation and downsamples
    // in one step — a portrait receipt is read upright.
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    // The primary image, not index 0: a HEIC's first image can be a
    // thumbnail or a depth map.
    guard let source = source,
          let image = CGImageSourceCreateThumbnailAtIndex(
            source, CGImageSourceGetPrimaryImageIndex(source), options as CFDictionary)
    else {
      return FlutterError(code: "unsupported_image", message: nil, details: nil)
    }
    func read(languages: [String]?) -> VNRecognizeTextRequest? {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      if let languages = languages {
        request.recognitionLanguages = languages
      } else if #available(iOS 16.0, macOS 13.0, *) {
        request.automaticallyDetectsLanguage = true
      }
      do {
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return request
      } catch {
        return nil
      }
    }
    var languages: [String]? = nil
    if #unavailable(iOS 16.0, macOS 13.0) {
      languages = visionLanguages()
    }
    // A language list Vision turns down after all fails the whole request:
    // once more in English before giving up.
    guard let request = read(languages: languages)
            ?? (languages == nil ? nil : read(languages: ["en-US"]))
    else {
      return FlutterError(code: "failed", message: nil, details: nil)
    }
    return (request.results ?? []).compactMap { observation -> [String: Any]? in
      guard let top = observation.topCandidates(1).first else { return nil }
      let box = observation.boundingBox  // normalised, bottom-left origin
      return [
        "text": top.string,
        "x": Double(box.minX), "y": Double(1 - box.maxY),
        "w": Double(box.width), "h": Double(box.height),
      ]
    }
  }

  /// The user's languages as Vision names them, for an OS that can't
  /// detect the language itself. Matched by language, not by exact tag — a
  /// French-Canadian device prefers `fr-CA`, Vision has `fr-FR` — and for
  /// Chinese by script. English last, always.
  private static func visionLanguages() -> [String] {
    let supported =
      (try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? ["en-US"]
    func match(_ preferred: String) -> String? {
      if supported.contains(preferred) { return preferred }
      let parts = preferred.split(separator: "-").map(String.init)
      guard let language = parts.first else { return nil }
      if language == "zh" {
        let traditional = parts.contains("Hant") || parts.contains("TW")
          || parts.contains("HK") || parts.contains("MO")
        let tag = traditional ? "zh-Hant" : "zh-Hans"
        return supported.contains(tag) ? tag : nil
      }
      return supported.first { $0.split(separator: "-").first.map(String.init) == language }
    }
    var out: [String] = []
    for tag in Locale.preferredLanguages.compactMap(match) + ["en-US"]
    where !out.contains(tag) && supported.contains(tag) {
      out.append(tag)
    }
    return out.isEmpty ? ["en-US"] : out
  }

  fileprivate static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "recognize":
      let args = call.arguments as? [String: Any]
      let path = args?["path"] as? String
      let bytes = (args?["bytes"] as? FlutterStandardTypedData)?.data
      queue.async {
        // Each read's decoded image and Vision buffers go when it does, not
        // when the queue's thread next drains.
        let outcome = autoreleasepool { recognize(path: path, bytes: bytes) }
        DispatchQueue.main.async { result(outcome) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
