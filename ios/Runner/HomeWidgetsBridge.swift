#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif
import Foundation
import WidgetKit

/// The Apple half of `invoice_ninja/home_widgets` (`HomeWidgetBridge` in Dart),
/// one file for iOS and macOS (the macOS Runner compiles it from here):
/// writes the snapshot the widgets read, reports which widgets are placed,
/// and hands Dart the commands a widget queued (docs/home-screen-widgets.md).
///
/// The file rules live in `WidgetFiles` (ios/HomeWidgets/), compiled into
/// this target too.
enum HomeWidgetsBridge {
  /// Same name as `HomeWidgetBridge.kChannelName`. Held so the handler
  /// outlives `register`.
  private static var channel: FlutterMethodChannel?

  /// Every write in arrival order: a sign-out's stub written after a
  /// rebuild's figures must also land after them, or the previous user's
  /// figures stay on screen.
  private static let queue = DispatchQueue(label: "com.invoiceninja.admin.homewidgets")

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "invoice_ninja/home_widgets", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "write":
        guard let json = args["json"] as? String, let data = json.data(using: .utf8) else {
          result(FlutterError(code: "home_widgets", message: "no json", details: nil))
          return
        }
        queue.async {
          do {
            try WidgetFiles.writeSnapshot(data)
            reload(args["reload"] as? [String])
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "home_widgets", message: "\(error)", details: nil))
            }
          }
        }
      case "installed":
        installed { result($0) }
      case "takeCommands":
        queue.async {
          let commands = WidgetFiles.commands()
          DispatchQueue.main.async { result(commands) }
        }
      case "deleteCommand":
        queue.async {
          WidgetFiles.deleteCommand(args["fileId"] as? String ?? "")
          // A "Stopped · syncs…" label goes with its command.
          WidgetCenter.shared.reloadTimelines(ofKind: WidgetFiles.kindTimer)
          DispatchQueue.main.async { result(nil) }
        }
      case "deleteAllCommands":
        queue.async {
          WidgetFiles.deleteAllCommands()
          DispatchQueue.main.async { result(nil) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    observeQueuedCommands()
  }

  /// A widget's Stop or Start posts a Darwin notification once its command is
  /// written, and the app applies it at once instead of at its next
  /// activation: a Mac app is usually running when Stop is tapped, and a
  /// Start opens the app — which may already be past its resume pass when
  /// the intent's file lands.
  private static var observing = false

  private static func observeQueuedCommands() {
    guard !observing else { return }
    observing = true
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(), nil,
      { _, _, _, _, _ in
        DispatchQueue.main.async {
          HomeWidgetsBridge.channel?.invokeMethod("commandsQueued", arguments: nil)
        }
      },
      WidgetFiles.commandsQueuedNotification as CFString, nil, .deliverImmediately)
  }

  /// Reloads the widgets of [kinds] — all of them when nil; none for an empty
  /// list (iOS budgets reloads; the widget reads the file at its next one).
  private static func reload(_ kinds: [String]?) {
    guard let kinds else {
      WidgetCenter.shared.reloadAllTimelines()
      return
    }
    for kind in kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
  }

  /// `{kinds, companyIds, periods}` of the placed widgets.
  private static func installed(_ done: @escaping ([String: [String]]) -> Void) {
    WidgetCenter.shared.getCurrentConfigurations { outcome in
      var kinds = Set<String>()
      var companies = Set<String>()
      var periods = Set<String>()
      if case .success(let infos) = outcome {
        for info in infos {
          kinds.insert(info.kind)
          if #available(iOS 17.0, macOS 14.0, *) {
            if let c = info.widgetConfigurationIntent(of: SnapshotConfigIntent.self) {
              if let id = c.company?.id, !id.isEmpty { companies.insert(id) }
              periods.insert(c.period.rawValue)
            }
            if let c = info.widgetConfigurationIntent(of: AttentionConfigIntent.self),
              let id = c.company?.id, !id.isEmpty
            {
              companies.insert(id)
            }
            if let c = info.widgetConfigurationIntent(of: TimerConfigIntent.self),
              let id = c.company?.id, !id.isEmpty
            {
              companies.insert(id)
            }
          }
        }
      }
      DispatchQueue.main.async {
        done([
          "kinds": Array(kinds), "companyIds": Array(companies), "periods": Array(periods),
        ])
      }
    }
  }
}
