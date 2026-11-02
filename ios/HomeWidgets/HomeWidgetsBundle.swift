import SwiftUI
import WidgetKit

/// The home-screen widgets (docs/home-screen-widgets.md). They read only the
/// snapshot the app writes into the App Group — no token, no network, no Dart.
@main
struct HomeWidgetsBundle: WidgetBundle {
  var body: some Widget {
    SnapshotWidget()
    AttentionWidget()
    TimerWidget()
    #if os(iOS)
      if #available(iOS 18.0, *) {
        NewInvoiceControl()
        NewTaskControl()
        StopTimerControl()
      }
    #endif
  }
}

/// Realistic sample data for the widget gallery and placeholders — never the
/// "Sign in" state, which would sell the widget as broken.
enum SampleSnapshot {
  static var value: WidgetSnapshot {
    let now = Date()
    let money = { (text: String, compact: String) in WidgetSnapshot.Money(text: text, compact: compact) }
    let iso = { (days: Int) -> String in
      let d = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      f.locale = Locale(identifier: "en_US_POSIX")
      return f.string(from: d)
    }
    let figures = WidgetSnapshot.Figures(
      fetchedAt: now.addingTimeInterval(-600),
      outstanding: WidgetSnapshot.Outstanding(
        amount: money("$12,431.50", "$12.4K"), unpaidCount: 4, pastDueCount: 2, pastDueExact: true,
        pastDueAmount: money("$3,120.00", "$3.1K"), pastDueShare: 0.25),
      periods: [
        "this_month": WidgetSnapshot.Period(
          label: "This Month", name: "October", endsOn: iso(20), fetchedAt: now,
          invoices: WidgetSnapshot.Figure(amount: money("$9,800.00", "$9.8K"), deltaPct: 12, good: true),
          payments: WidgetSnapshot.Figure(amount: money("$7,250.00", "$7.3K"), deltaPct: 8, good: true),
          expenses: WidgetSnapshot.Figure(amount: money("$1,140.00", "$1.1K"), deltaPct: -5, good: true))
      ],
      attention: WidgetSnapshot.Attention(
        pastDue: [
          WidgetSnapshot.InvoiceRow(
            id: "s1", number: "0042", client: "Acme Studio", amount: money("$1,200.00", "$1.2K"),
            lateSince: iso(-12), dueOn: nil),
          WidgetSnapshot.InvoiceRow(
            id: "s2", number: "0039", client: "Northwind", amount: money("$1,920.00", "$1.9K"),
            lateSince: iso(-3), dueOn: nil),
        ],
        dueSoon: [
          WidgetSnapshot.InvoiceRow(
            id: "s3", number: "0045", client: "Globex", amount: money("$640.00", "$640"),
            lateSince: nil, dueOn: iso(3))
        ],
        nextDue: nil),
      inCurrency: "")
    return WidgetSnapshot(
      v: 1, tooNew: false, writtenAt: now, signedIn: true, userId: "", appLock: false, rtl: false,
      activeCompanyId: "sample", strings: [:],
      companies: [
        WidgetSnapshot.Company(
          id: "sample", name: "Acme", accent: "", canViewDashboard: true, figures: figures,
          timers: [
            WidgetSnapshot.Timer(
              taskId: "t", description: "Website redesign", client: "Acme Studio",
              runningSince: now.addingTimeInterval(-4_980), priorSeconds: 0, canStop: true)
          ],
          runningCount: 1,
          recentTasks: [],
          today: WidgetSnapshot.Today(date: iso(0), doneSeconds: 7_200))
      ])
  }
}
