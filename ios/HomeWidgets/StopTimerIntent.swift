import AppIntents
import Foundation
import SwiftUI
import WidgetKit

// Compiled into the widget extension ONLY. Were it in the Runner too, the app
// would register the intent as well, and iOS could run a Stop tap in the
// app's process — launching Flutter for a widget, which the one-engine rule
// forbids (docs/home-screen-widgets.md). tools/add_home_widgets_target.rb
// keeps it out of the Runner.

/// The Timer widget's Stop (docs/home-screen-widgets.md § The only write is a
/// queued command).
///
/// Runs in the widget extension, never in the app and never as Dart: it
/// writes a command into the App Group — which only this app's own code can
/// reach, unlike a URL anything can open — and reloads the Timer widget, which
/// shows the timer as stopped while the command waits. The app applies it at
/// the tap time (`at`) the next time it runs.
@available(iOS 17.0, macOS 14.0, *)
struct StopTimerIntent: AppIntent {
  static var title: LocalizedStringResource = "Stop timer"
  static var description = IntentDescription("Stops the running timer.")
  /// Not from the lock screen or StandBy without an unlock.
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  static var isDiscoverable = false

  @Parameter(title: "Task") var taskId: String
  @Parameter(title: "Company") var companyId: String
  @Parameter(title: "User") var userId: String
  /// The running entry's start, epoch milliseconds.
  @Parameter(title: "Running since") var runningSince: Int

  init() {}

  init(taskId: String, companyId: String, userId: String, runningSince: Date) {
    self.taskId = taskId
    self.companyId = companyId
    self.userId = userId
    self.runningSince = Int((runningSince.timeIntervalSince1970 * 1000).rounded())
  }

  func perform() async throws -> some IntentResult {
    guard !taskId.isEmpty, !companyId.isEmpty, !userId.isEmpty, runningSince > 0 else {
      return .result()
    }
    try WidgetFiles.queueCommand([
      "v": 1,
      "id": UUID().uuidString,
      "kind": "stop",
      "userId": userId,
      "companyId": companyId,
      "taskId": taskId,
      "runningSince": runningSince,
      "at": Int(Date().timeIntervalSince1970 * 1000),
    ])
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetFiles.kindTimer)
    #if os(macOS)
      // A Mac app is usually running: tell it to apply the stop now.
      CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFNotificationName(WidgetFiles.commandsQueuedNotification as CFString),
        nil, nil, true)
    #endif
    return .result()
  }
}

#if os(iOS)
  /// The Control Center / lock-screen / Action-button Stop (iOS 18): stops
  /// the newest timer the Timer widget would show for the app's current
  /// company — the same queued command as the widget's own Stop, so the same
  /// rules hold (extension-only, applied by the app at the tap time).
  ///
  /// With nothing running it does nothing; New Task is its own control.
  @available(iOS 18.0, *)
  struct StopRunningTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop timer"
    static var description = IntentDescription("Stops the running timer.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
      guard
        let s = WidgetSnapshot.load(), s.signedIn, !s.tooNew,
        let company = s.company("")
      else { return .result() }
      let pending = WidgetFiles.pendingStops()
      guard
        let t = company.timers.first(where: {
          $0.canStop && pending[WidgetFiles.stopKey($0.taskId, $0.runningSince)] == nil
        })
      else { return .result() }
      _ = try await StopTimerIntent(
        taskId: t.taskId, companyId: company.id, userId: s.userId, runningSince: t.runningSince
      ).perform()
      return .result()
    }
  }

  @available(iOS 18.0, *)
  struct StopTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
      StaticControlConfiguration(kind: "com.invoiceninja.admin.control.stopTimer") {
        ControlWidgetButton(action: StopRunningTimerIntent()) {
          Label("Stop timer", systemImage: "stop.circle")
        }
      }
      .displayName("Stop timer")
      .description("Stops the running timer.")
    }
  }
#endif
