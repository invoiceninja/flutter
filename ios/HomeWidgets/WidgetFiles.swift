import Foundation

/// Where the home-screen widgets' files live, in the App Group container both
/// the app and the widget extension can reach: the snapshot the app writes,
/// and the commands a widget queues for the app (docs/home-screen-widgets.md).
///
/// Compiled into BOTH the Runner (the channel that writes) and the
/// HomeWidgets extension (which reads, and queues a Stop) — one copy of the
/// paths and the file rules.
enum WidgetFiles {
  /// iOS shares the Share Extension's group. macOS needs its own,
  /// team-prefixed (a sandboxed Mac App Store app below macOS 15).
  #if os(macOS)
    static let appGroup = "NPC44Y2C98.com.invoiceninja.admin.widgets"
  #else
    static let appGroup = "group.com.invoiceninja.admin"
  #endif

  private static let folder = "HomeWidgets"
  private static let snapshotName = "snapshot.json"
  private static let commandsFolder = "commands"

  /// The Darwin notification a widget posts after queueing a command, so a
  /// running Mac app applies it at once (`HomeWidgetsBridge`).
  static let commandsQueuedNotification = "com.invoiceninja.admin.widgetCommandsQueued"

  /// The widget `kind` strings — the same as Dart's `WidgetKind.wire`.
  static let kindSnapshot = "snapshot"
  static let kindAttention = "attention"
  static let kindTimer = "timer"

  static var root: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent(folder, isDirectory: true)
  }

  static var snapshotURL: URL? { root?.appendingPathComponent(snapshotName) }

  static var commandsURL: URL? {
    root?.appendingPathComponent(commandsFolder, isDirectory: true)
  }

  /// Replaces the snapshot atomically. `.completeUntilFirstUserAuthentication`
  /// so a widget can read it while the phone is locked (after the first unlock
  /// since boot).
  static func writeSnapshot(_ data: Data) throws {
    guard let root, let url = snapshotURL else { throw CocoaError(.fileNoSuchFile) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    // Not in device backups: a copy of the user's figures and task names must
    // not travel to another device in an iCloud / Finder backup.
    var folder = root
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? folder.setResourceValues(values)
    #if os(iOS)
      try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
      try data.write(to: url, options: [.atomic])
    #endif
  }

  static func readSnapshot() -> Data? {
    guard let url = snapshotURL else { return nil }
    return try? Data(contentsOf: url)
  }

  /// A command file name: a UUID and `.json`, nothing that can path out.
  static func isCommandName(_ name: String) -> Bool {
    name.range(of: "^[A-Za-z0-9-]{1,64}\\.json$", options: .regularExpression) != nil
  }

  /// Queues a command for the app (written by the extension's Stop intent).
  static func queueCommand(_ command: [String: Any]) throws {
    guard let dir = commandsURL else { throw CocoaError(.fileNoSuchFile) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let id = (command["id"] as? String) ?? UUID().uuidString
    let data = try JSONSerialization.data(withJSONObject: command)
    try data.write(to: dir.appendingPathComponent("\(id).json"), options: [.atomic])
  }

  /// Every queued command as `{fileId, json}`, oldest tap first.
  ///
  /// Ordered by the command's own `at`, not the file's creation date: a file
  /// timestamp is a "required reason" API (it would need a privacy manifest),
  /// and the tap time is the order that matters anyway.
  static func commands() -> [[String: String]] {
    guard
      let dir = commandsURL,
      let files = try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil)
    else { return [] }
    let entries: [(at: Int64, entry: [String: String])] = files
      .filter { isCommandName($0.lastPathComponent) }
      .compactMap { url in
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let json =
          (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        let at = (json?["at"] as? NSNumber)?.int64Value ?? 0
        return (at, ["fileId": url.lastPathComponent, "json": text])
      }
    return entries.sorted { $0.at < $1.at }.map(\.entry)
  }

  /// `taskId|runningSince` → tap time (epoch ms) for every queued Stop — the
  /// widget shows that session as stopped already. Keyed by the session, not
  /// the task: a stop still waiting (deferred for another company) must not
  /// mark a later, restarted session of the same task as stopped.
  static func pendingStops() -> [String: Int64] {
    var out: [String: Int64] = [:]
    for entry in commands() {
      guard
        let data = entry["json"]?.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        json["kind"] as? String == "stop",
        let task = json["taskId"] as? String
      else { continue }
      let since = (json["runningSince"] as? NSNumber)?.int64Value ?? 0
      out[stopKey(task, since)] = (json["at"] as? NSNumber)?.int64Value ?? 0
    }
    return out
  }

  static func stopKey(_ taskId: String, _ runningSinceMs: Int64) -> String {
    "\(taskId)|\(runningSinceMs)"
  }

  static func stopKey(_ taskId: String, _ runningSince: Date) -> String {
    stopKey(taskId, Int64((runningSince.timeIntervalSince1970 * 1000).rounded()))
  }

  static func deleteCommand(_ fileId: String) {
    guard isCommandName(fileId), let dir = commandsURL else { return }
    try? FileManager.default.removeItem(at: dir.appendingPathComponent(fileId))
  }

  static func deleteAllCommands() {
    guard let dir = commandsURL else { return }
    try? FileManager.default.removeItem(at: dir)
  }
}
