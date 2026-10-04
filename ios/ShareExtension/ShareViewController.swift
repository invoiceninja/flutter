import ImageIO
import UIKit
import UniformTypeIdentifiers

/// The app's iOS share target: "Share → Invoice Ninja" from Mail, Photos or
/// Files opens New Expense with the files attached (invoiceninja/flutter#173).
///
/// An extension runs in its own process and can't reach the app's sandbox, so
/// it hands the files over through the App Group container: each share's
/// copies go in `SharedIntake/<uuid>/`, then one `SharedIntake/<uuid>.json`
/// lists them — written atomically and last, so the app never reads a share
/// that is still being written. The Runner moves them into its own
/// `Application Support/shared_intake/` (`AppDelegate.swift`, `ShareIntake`)
/// when Dart pulls `takeShares`.
///
/// Images the server's upload rule won't take (HEIC, HEIF, TIFF…: `mimes:` in
/// the server's `Request::$file_validation`) are re-encoded as JPEG on the way,
/// through ImageIO's thumbnail path: it decodes straight to the target size
/// instead of the full bitmap (a share extension gets ~120 MB), bakes the
/// orientation into the pixels, and copies no metadata — so no location either.
///
/// Then it opens `invoiceninja://share` to bring the app forward. That can
/// fail (opening the containing app is not an API extensions are promised), so
/// the app also pulls on every resume, and the user is told to open it.
///
/// See docs/sharing-files-into-the-app.md.
class ShareViewController: UIViewController {

  /// Also in `ShareExtension.entitlements`, `Runner.entitlements` and
  /// `AppDelegate.swift` — `test/lint/share_target_wiring_test.dart`
  /// keeps the four in step.
  static let appGroup = "group.com.invoiceninja.admin"

  private static let intakeFolder = "SharedIntake"

  /// The document cap (`kDocumentMaxBytes`).
  private static let maxBytes = 25 * 1024 * 1024

  /// More than anyone attaches to one expense; bounds the copy work.
  private static let maxFiles = 20

  /// Long edge of a converted image. A receipt needs nothing larger, and the
  /// decode stays well inside the extension's memory limit.
  private static let maxEdge = 3072

  /// A file name's base, in UTF-8 bytes — well inside the 255-byte limit.
  private static let maxBaseBytes = 150

  /// How long `open()` may take to answer before the user is told what to do.
  private static let openTimeout: TimeInterval = 3

  /// Image types the server takes as they are.
  private static let serverImageTypes: [UTType] = [.jpeg, .png, .gif, .webP]

  /// The item providers call back on queues of their own, concurrently. Every
  /// copy runs here, one at a time: names are made unique without a race, and
  /// only one image is ever decoded at once.
  private static let workQueue = DispatchQueue(label: "com.invoiceninja.admin.share.copy")

  private var started = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(spinner)
    NSLayoutConstraint.activate([
      spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    spinner.startAnimating()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    handleShare()
  }

  private func handleShare() {
    // Filter first, then cap: a share of 30 items with 5 receipts at the end
    // keeps the receipts.
    let candidates = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
      .compactMap { provider in Self.acceptedType(of: provider).map { (provider, $0) } }
    let accepted = Array(candidates.prefix(Self.maxFiles))
    let fm = FileManager.default
    guard
      let container = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
    else {
      showFailure()
      return
    }
    let shareId = UUID().uuidString
    let inbox = container.appendingPathComponent(Self.intakeFolder, isDirectory: true)
    let folder = inbox.appendingPathComponent(shareId, isDirectory: true)
    // Before anything else: a share whose every file is rejected still writes
    // a manifest (so the app can say why), and on a fresh install nothing has
    // created this folder yet.
    guard (try? fm.createDirectory(at: inbox, withIntermediateDirectories: true)) != nil else {
      showFailure()
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var entries = [[String: String]?](repeating: nil, count: accepted.count)
    for (index, (provider, type)) in accepted.enumerated() {
      group.enter()
      // What a handler hands over is only valid inside it, so the copy happens
      // there — synchronously, on the one work queue, in a pool of its own so
      // twenty conversions in a row don't pile up autoreleased image buffers.
      let record: (Payload) -> Void = { payload in
        let entry = Self.workQueue.sync {
          autoreleasepool {
            Self.copy(
              payload, suggestedName: provider.suggestedName, type: type, index: index,
              into: folder, shareId: shareId)
          }
        }
        lock.lock()
        entries[index] = entry
        lock.unlock()
        group.leave()
      }
      provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
        if let url = url {
          record(.file(url))
          return
        }
        // Not every sender has a file to give: the screenshot editor and apps
        // sharing a `UIImage` hand over an object, or raw data, instead.
        provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
          record(Self.payload(of: item))
        }
      }
    }
    group.notify(queue: .main) {
      let files = entries.compactMap { $0 }
      guard !files.isEmpty else {
        self.finish()
        return
      }
      let manifest = inbox.appendingPathComponent("\(shareId).json")
      guard
        let data = try? JSONSerialization.data(withJSONObject: files),
        (try? data.write(to: manifest, options: .atomic)) != nil
      else {
        try? fm.removeItem(at: folder)
        self.showFailure()
        return
      }
      self.openHostApp()
    }
  }

  /// The representation to ask for: one the server takes as-is if the
  /// provider has it (Photos often offers JPEG beside HEIC), else a PDF, else
  /// any image (converted below).
  private static func acceptedType(of provider: NSItemProvider) -> UTType? {
    let types = provider.registeredTypeIdentifiers.compactMap { UTType($0) }
    return types.first { type in serverImageTypes.contains { type.conforms(to: $0) } }
      ?? types.first { $0.conforms(to: .pdf) }
      ?? types.first { $0.conforms(to: .image) }
  }

  /// What an item provider handed over.
  private enum Payload {
    case file(URL)
    case data(Data)
    case image(UIImage)
    case nothing
  }

  private static func payload(of item: NSSecureCoding?) -> Payload {
    switch item {
    case let url as URL where url.isFileURL: return .file(url)
    case let data as Data: return .data(data)
    case let image as UIImage: return .image(image)
    default: return .nothing
    }
  }

  /// One `{path, name, issue?}` entry — what Dart's `SharedFile` reads — with
  /// `path` relative to `SharedIntake/`, since the container's absolute path
  /// is the extension's business.
  private static func copy(
    _ payload: Payload, suggestedName: String?, type: UTType, index: Int,
    into folder: URL, shareId: String
  ) -> [String: String] {
    var sourceURL: URL?
    if case .file(let url) = payload { sourceURL = url }
    let (base, ext) = fileName(suggested: suggestedName, url: sourceURL, type: type, index: index)
    var entry = ["name": ext.isEmpty ? base : "\(base).\(ext)"]
    let fm = FileManager.default
    var scratch: URL?
    defer { if let scratch = scratch { try? fm.removeItem(at: scratch) } }
    do {
      try fm.createDirectory(at: folder, withIntermediateDirectories: true)
      let source: URL
      switch payload {
      case .nothing:
        entry["issue"] = "unreadable"
        return entry
      case .file(let url):
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > maxBytes {
          entry["issue"] = "tooLarge"
          return entry
        }
        source = url
      case .data(let data):
        if data.count > maxBytes {
          entry["issue"] = "tooLarge"
          return entry
        }
        let url = folder.appendingPathComponent(".\(UUID().uuidString)")
        try data.write(to: url)
        scratch = url
        source = url
      case .image(let image):
        // An object, not a file: there is nothing to keep but the pixels, and
        // JPEG is what the server takes (re-encoded, so no metadata either).
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
          entry["issue"] = "unsupported"
          return entry
        }
        if jpeg.count > maxBytes {
          entry["issue"] = "tooLarge"
          return entry
        }
        let target = unique(folder.appendingPathComponent("\(base).jpg"))
        try jpeg.write(to: target)
        return written(target, into: entry, shareId: shareId)
      }
      let isServerImage = serverImageTypes.contains { type.conforms(to: $0) }
      let target: URL
      if type.conforms(to: .image) && !isServerImage {
        target = unique(folder.appendingPathComponent("\(base).jpg"))
        guard convertToJPEG(from: source, to: target) else {
          entry["issue"] = "unsupported"
          return entry
        }
      } else {
        target = unique(folder.appendingPathComponent(entry["name"]!))
        try fm.copyItem(at: source, to: target)
      }
      return written(target, into: entry, shareId: shareId)
    } catch {
      entry["issue"] = "unreadable"
      return entry
    }
  }

  private static func written(
    _ target: URL, into entry: [String: String], shareId: String
  ) -> [String: String] {
    var entry = entry
    entry["name"] = target.lastPathComponent
    entry["path"] = "\(shareId)/\(target.lastPathComponent)"
    return entry
  }

  /// The sender's name for the file, made safe, as a base and an extension
  /// that names what the file IS — Dart's validation and the server read the
  /// type from it. A dot is not an extension: "Scan 03.10.2026" for a PDF keeps
  /// its whole name and gains `.pdf`. An extension that names a different
  /// known type is dropped rather than kept in the name ("IMG_1.HEIC" taken
  /// as JPEG is "IMG_1.jpeg", not "IMG_1.HEIC.jpeg"). The base is truncated,
  /// never the extension.
  private static func fileName(
    suggested: String?, url: URL?, type: UTType, index: Int
  ) -> (base: String, ext: String) {
    let cleaned = sanitize(suggested ?? url?.lastPathComponent)
    let tail = (cleaned as NSString).pathExtension
    let tailType = tail.isEmpty ? nil : UTType(filenameExtension: tail)
    let keepTail = tailType?.conforms(to: type) ?? false
    let dropTail = !keepTail && (tailType?.isDeclared ?? false)
    var base = keepTail || dropTail ? (cleaned as NSString).deletingPathExtension : cleaned
    let ext =
      keepTail ? tail : (type.preferredFilenameExtension ?? url?.pathExtension ?? "")
    base = truncateUTF8(base.trimmingCharacters(in: .whitespaces), maxBytes: maxBaseBytes)
    if base.isEmpty { base = "shared_\(index + 1)" }
    return (base, ext)
  }

  private static func convertToJPEG(from source: URL, to target: URL) -> Bool {
    guard
      let input = CGImageSourceCreateWithURL(
        source as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    else { return false }
    let thumbnail: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxEdge,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(input, 0, thumbnail as CFDictionary),
      let output = CGImageDestinationCreateWithURL(
        target as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(
      output, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    let ok = CGImageDestinationFinalize(output)
    if !ok { try? FileManager.default.removeItem(at: target) }
    return ok
  }

  private static func sanitize(_ raw: String?) -> String {
    let banned = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
    let cleaned = (raw ?? "").components(separatedBy: banned).joined(separator: "_")
    var name = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    while name.hasPrefix(".") { name.removeFirst() }
    return name
  }

  /// The longest prefix of [s] that fits [maxBytes] of UTF-8, whole characters only.
  private static func truncateUTF8(_ s: String, maxBytes: Int) -> String {
    var out = ""
    var bytes = 0
    for character in s {
      let length = String(character).utf8.count
      if bytes + length > maxBytes { break }
      out.append(character)
      bytes += length
    }
    return out
  }

  /// [url], or `name (2).ext`… when a multi-share repeats a name. Only ever
  /// called on [workQueue], so the check and the write that follows don't race.
  private static func unique(_ url: URL) -> URL {
    var candidate = url
    var n = 2
    let base = url.deletingPathExtension().lastPathComponent
    let ext = url.pathExtension
    while FileManager.default.fileExists(atPath: candidate.path) {
      let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
      candidate = url.deletingLastPathComponent().appendingPathComponent(name)
      n += 1
    }
    return candidate
  }

  /// Opening the containing app from an extension: walk the responder chain to
  /// the process's `UIApplication` (`UIApplication.shared` is unavailable to
  /// extensions; `open(_:options:completionHandler:)` is not). The app coming
  /// forward sends the host app (Photos, Mail…) to the background, which
  /// settles it even when the completion is late — a slow cold start, or this
  /// process suspended before the answer. If neither has happened within
  /// [openTimeout], or the answer is no, the user is told to open the app — the
  /// files are already waiting, and it pulls them on its next resume.
  private func openHostApp() {
    guard let url = URL(string: "invoiceninja://share") else {
      showOpenAppHint()
      return
    }
    var settled = false
    var hostLeft: NSObjectProtocol?
    let settle: (Bool) -> Void = { [weak self] opened in
      guard !settled else { return }
      settled = true
      if let observer = hostLeft { NotificationCenter.default.removeObserver(observer) }
      if opened {
        self?.finish()
      } else {
        self?.showOpenAppHint()
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.openTimeout) { settle(false) }
    var responder: UIResponder? = self
    while let current = responder {
      if let application = current as? UIApplication {
        hostLeft = NotificationCenter.default.addObserver(
          forName: .NSExtensionHostDidEnterBackground, object: nil, queue: .main
        ) { _ in settle(true) }
        application.open(url, options: [:]) { opened in
          DispatchQueue.main.async { settle(opened) }
        }
        return
      }
      responder = current.next
    }
    settle(false)
  }

  /// The home-screen name of the app this extension ships in, which is what
  /// the user has to find — not necessarily the name the share sheet shows.
  private static var containingAppName: String {
    let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    let info = Bundle(url: appURL)?.infoDictionary
    return info?["CFBundleDisplayName"] as? String
      ?? info?["CFBundleName"] as? String
      ?? "Invoice Ninja"
  }

  private func showOpenAppHint() {
    showAlert(
      String(
        format: NSLocalizedString(
          "Open %@ to finish the expense.", comment: "Share extension fallback: the app's name"),
        Self.containingAppName))
  }

  /// The App Group container is unreachable or the hand-off couldn't be
  /// written — nothing will reach the app, so say so rather than just closing.
  private func showFailure() {
    showAlert(
      NSLocalizedString(
        "Invoice Ninja couldn't receive these files. Please try again.",
        comment: "Share extension failure"))
  }

  private func showAlert(_ message: String) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(
      UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) {
        [weak self] _ in
        self?.finish()
      })
    present(alert, animated: true)
  }

  private func finish() {
    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
  }
}
