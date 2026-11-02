import AppIntents
import UIKit
import app_links

// Siri, Shortcuts and Spotlight actions (docs/home-screen-widgets.md). Each
// opens the app and hands it an `invoiceninja://app/…` link, so it takes the
// same path as every other link: DeepLinkRouter validates it, holds it while
// the app is locked, and switches company. None writes anything: Stop timer is
// the widget's (StopTimerIntent, extension-only), never Siri's.

/// Hands the link to app_links, which holds it as the initial link until Dart
/// listens — the app may be cold-starting under the intent
/// (`openAppWhenRun`).
@available(iOS 17.0, *)
private func openAppLink(_ route: String) async {
  guard let url = URL(string: "invoiceninja://app\(route)") else { return }
  await MainActor.run { AppLinks.shared.handleLink(url: url) }
}

@available(iOS 17.0, *)
struct NewInvoiceIntent: AppIntent {
  static var title: LocalizedStringResource = "New Invoice"
  static var description = IntentDescription("Opens a new invoice in Invoice Ninja.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    await openAppLink("/invoices/new")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NewTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "New Task"
  static var description = IntentDescription("Opens a new task in Invoice Ninja.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    await openAppLink("/tasks/new")
    return .result()
  }
}

@available(iOS 17.0, *)
struct NewExpenseIntent: AppIntent {
  static var title: LocalizedStringResource = "New Expense"
  static var description = IntentDescription("Opens a new expense in Invoice Ninja.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    await openAppLink("/expenses/new")
    return .result()
  }
}

@available(iOS 17.0, *)
struct ShowOutstandingIntent: AppIntent {
  static var title: LocalizedStringResource = "Show Unpaid Invoices"
  static var description = IntentDescription("Opens your unpaid invoices in Invoice Ninja.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult {
    await openAppLink("/invoices?filter=unpaid")
    return .result()
  }
}

@available(iOS 17.0, *)
struct InvoiceNinjaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: NewInvoiceIntent(),
      phrases: ["New invoice in \(.applicationName)", "Create an invoice in \(.applicationName)"],
      shortTitle: "New Invoice", systemImageName: "doc.badge.plus")
    AppShortcut(
      intent: NewTaskIntent(),
      phrases: ["New task in \(.applicationName)", "Start a task in \(.applicationName)"],
      shortTitle: "New Task", systemImageName: "timer")
    AppShortcut(
      intent: NewExpenseIntent(),
      phrases: ["New expense in \(.applicationName)", "Add an expense in \(.applicationName)"],
      shortTitle: "New Expense", systemImageName: "creditcard")
    AppShortcut(
      intent: ShowOutstandingIntent(),
      phrases: ["Show unpaid invoices in \(.applicationName)", "What's outstanding in \(.applicationName)"],
      shortTitle: "Unpaid Invoices", systemImageName: "doc.text.magnifyingglass")
  }
}
