import AppIntents
import Foundation
import WidgetKit

// The widgets' configuration.
//
// Compiled into the extension AND the Runner: the Runner reads a placed
// widget's configuration back (`HomeWidgetsBridge.installed`, through
// `widgetConfigurationIntent(of:)`), which needs the same types. The one
// action, `StopTimerIntent`, is NOT here — see StopTimerIntent.swift.

// MARK: - Company

@available(iOS 17.0, macOS 14.0, *)
struct CompanyEntity: AppEntity {
  /// Empty: follow the app's active company.
  var id: String
  var name: String

  static let current = CompanyEntity(id: "", name: String(localized: "Current company"))

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Company"
  static var defaultQuery = CompanyQuery()

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

@available(iOS 17.0, macOS 14.0, *)
struct CompanyQuery: EntityQuery {
  private func all() -> [CompanyEntity] {
    let companies = WidgetSnapshot.load()?.companies ?? []
    return [CompanyEntity.current] + companies.map { CompanyEntity(id: $0.id, name: $0.name) }
  }

  func entities(for identifiers: [CompanyEntity.ID]) async throws -> [CompanyEntity] {
    let known = all()
    // A company no longer in the snapshot keeps its id, so the widget can say
    // "Choose a company" rather than silently switch to another one.
    return identifiers.map { id in
      known.first { $0.id == id }
        ?? CompanyEntity(id: id, name: String(localized: "Company"))
    }
  }

  func suggestedEntities() async throws -> [CompanyEntity] { all() }

  func defaultResult() async -> CompanyEntity? { .current }
}

// MARK: - Options

@available(iOS 17.0, macOS 14.0, *)
enum PeriodOption: String, AppEnum {
  case thisMonth = "this_month"
  case last30Days = "last30_days"
  case thisYear = "this_year"

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
  static var caseDisplayRepresentations: [PeriodOption: DisplayRepresentation] = [
    .thisMonth: "This Month",
    .last30Days: "Last 30 Days",
    .thisYear: "This Year",
  ]
}

@available(iOS 17.0, macOS 14.0, *)
enum FigureOption: String, AppEnum {
  case outstanding, invoices, payments, expenses

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Figure"
  static var caseDisplayRepresentations: [FigureOption: DisplayRepresentation] = [
    .outstanding: "Outstanding",
    .invoices: "Invoices",
    .payments: "Payments",
    .expenses: "Expenses",
  ]
}

@available(iOS 17.0, macOS 14.0, *)
enum HideAmountsOption: String, AppEnum {
  case automatic, on, off

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Hide amounts"
  static var caseDisplayRepresentations: [HideAmountsOption: DisplayRepresentation] = [
    .automatic: DisplayRepresentation(
      title: "Automatic", subtitle: "Hidden while App Lock is on"),
    .on: "On",
    .off: "Off",
  ]

  /// Whether money is masked, given whether App Lock is on.
  func masks(appLock: Bool) -> Bool {
    switch self {
    case .automatic: return appLock
    case .on: return true
    case .off: return false
    }
  }
}

// MARK: - Configuration intents

@available(iOS 17.0, macOS 14.0, *)
struct SnapshotConfigIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Business snapshot"
  static var description = IntentDescription("Choose what the widget shows.")

  @Parameter(title: "Company") var company: CompanyEntity?
  @Parameter(title: "Period", default: .thisMonth) var period: PeriodOption
  @Parameter(title: "Figure (small widget)", default: .outstanding) var figure: FigureOption
  @Parameter(title: "Hide amounts", default: .automatic) var hideAmounts: HideAmountsOption
}

@available(iOS 17.0, macOS 14.0, *)
struct AttentionConfigIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Needs attention"
  static var description = IntentDescription("Choose the company.")

  @Parameter(title: "Company") var company: CompanyEntity?
  @Parameter(title: "Hide amounts", default: .automatic) var hideAmounts: HideAmountsOption
}

@available(iOS 17.0, macOS 14.0, *)
struct TimerConfigIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Running timer"
  static var description = IntentDescription("Choose the company.")

  @Parameter(title: "Company") var company: CompanyEntity?
}

/// The Timer widget's Start on a recent task (docs/home-screen-widgets.md
/// § The only write is a queued command).
///
/// Compiled into the app as well as the extension, because it opens the app
/// (`openAppWhenRun`): a start can need a booking question only the app can
/// ask, so the app — not this intent — starts the timer. This only queues the
/// command, in the App Group only this app's own code can reach (never a URL
/// any app or web page could fire), and says it is there. Starting Flutter for
/// it is fine: unlike Stop, the user is opening the app.
@available(iOS 17.0, macOS 14.0, *)
struct StartTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "Start timer"
  static var description = IntentDescription("Opens the task in Invoice Ninja and starts its timer.")
  static var openAppWhenRun = true
  static var isDiscoverable = false

  @Parameter(title: "Task") var taskId: String
  @Parameter(title: "Company") var companyId: String
  @Parameter(title: "User") var userId: String

  init() {}

  init(taskId: String, companyId: String, userId: String) {
    self.taskId = taskId
    self.companyId = companyId
    self.userId = userId
  }

  func perform() async throws -> some IntentResult {
    guard !taskId.isEmpty, !taskId.hasPrefix("tmp_"), !companyId.isEmpty, !userId.isEmpty else {
      return .result()
    }
    try WidgetFiles.queueCommand([
      "v": 1,
      "id": UUID().uuidString,
      "kind": "start",
      "userId": userId,
      "companyId": companyId,
      "taskId": taskId,
      "at": Int(Date().timeIntervalSince1970 * 1000),
    ])
    // The app may already be up and past its resume pass: tell it.
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(WidgetFiles.commandsQueuedNotification as CFString),
      nil, nil, true)
    return .result()
  }
}
