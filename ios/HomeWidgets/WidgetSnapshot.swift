import Foundation

/// The snapshot the app writes — the Swift twin of
/// `lib/domain/home_widgets/widget_snapshot.dart` (and of Android's
/// `WidgetSnapshot.kt`).
///
/// Lenient by design: decoded from plain dictionaries, every field optional,
/// nothing force-unwrapped, so a missing or mistyped value degrades to "—"
/// rather than a crash (the old admin-portal widget force-unwrapped and
/// crashed). A snapshot newer than `version` is `tooNew`: the widget asks for
/// an app update instead of guessing. `tools/widget_snapshot_contract.sh` decodes the shared
/// golden files in `test/fixtures/home_widgets/`.
struct WidgetSnapshot {
  static let version = 1

  struct Money { var text: String; var compact: String }
  struct Figure { var amount: Money; var deltaPct: Int?; var good: Bool? }
  struct Outstanding {
    var amount: Money
    var unpaidCount: Int
    var pastDueCount: Int?
    var pastDueExact: Bool
    var pastDueAmount: Money?
    /// `pastDueAmount` over `amount`, 0–1; nil unless proven, one currency.
    var pastDueShare: Double?
  }
  struct Period {
    var label: String
    var name: String
    var endsOn: String
    var fetchedAt: Date?
    var invoices: Figure?
    var payments: Figure?
    var expenses: Figure?
  }
  struct InvoiceRow {
    var id: String
    var number: String
    var client: String
    var amount: Money
    var lateSince: String?
    var dueOn: String?
  }
  struct Attention { var pastDue: [InvoiceRow]; var dueSoon: [InvoiceRow]; var nextDue: InvoiceRow? }
  struct Figures {
    var fetchedAt: Date?
    var outstanding: Outstanding?
    var periods: [String: Period]
    var attention: Attention?
    var inCurrency: String
  }
  struct Timer {
    var taskId: String
    var description: String
    var client: String
    var runningSince: Date
    var priorSeconds: Int
    var canStop: Bool
  }
  struct Task { var taskId: String; var description: String; var client: String }
  /// Time worked today: `doneSeconds` of finished entries on the local day
  /// `date` (yyyy-MM-dd); running timers are added by the widget.
  struct Today { var date: String; var doneSeconds: Int }
  struct Company {
    var id: String
    var name: String
    var accent: String
    var canViewDashboard: Bool
    var figures: Figures?
    var timers: [Timer]
    /// All the user's running timers; `timers` is the newest few.
    var runningCount: Int
    var recentTasks: [Task]
    var today: Today?
  }

  var v: Int
  var tooNew: Bool
  var writtenAt: Date
  var signedIn: Bool
  var userId: String
  var appLock: Bool
  var rtl: Bool
  var activeCompanyId: String
  var strings: [String: String]
  var companies: [Company]

  /// The company a widget set to `companyId` shows; empty means the active one.
  func company(_ companyId: String) -> Company? {
    let id = companyId.isEmpty ? activeCompanyId : companyId
    return companies.first { $0.id == id }
  }

  /// `key` in the app's language, else `fallback` (the bundled English).
  func string(_ key: String, _ fallback: String) -> String {
    if let s = strings[key], !s.trimmingCharacters(in: .whitespaces).isEmpty { return s }
    return fallback
  }

  /// The snapshot on disk, or nil when the app has never written one or it
  /// won't parse.
  static func load() -> WidgetSnapshot? {
    guard let data = WidgetFiles.readSnapshot() else { return nil }
    return parse(data)
  }

  static func parse(_ data: Data) -> WidgetSnapshot? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return parse(json)
  }

  static func parse(_ j: [String: Any]) -> WidgetSnapshot {
    let v = int(j["v"]) ?? 0
    var strings: [String: String] = [:]
    for (k, value) in (j["strings"] as? [String: Any]) ?? [:] {
      if let s = value as? String { strings[k] = s }
    }
    return WidgetSnapshot(
      v: v,
      tooNew: v > version,
      writtenAt: date(j["writtenAt"]) ?? .distantPast,
      signedIn: j["signedIn"] as? Bool ?? false,
      userId: j["userId"] as? String ?? "",
      appLock: j["appLock"] as? Bool ?? false,
      rtl: j["rtl"] as? Bool ?? false,
      activeCompanyId: j["activeCompanyId"] as? String ?? "",
      strings: strings,
      companies: objects(j["companies"]).map(company))
  }

  private static func company(_ c: [String: Any]) -> Company {
    let timers: [Timer] = objects(c["timers"]).compactMap { t in
      guard let since = date(t["runningSince"]) else { return nil }
      return Timer(
        taskId: t["taskId"] as? String ?? "",
        description: t["description"] as? String ?? "",
        client: t["client"] as? String ?? "",
        runningSince: since,
        priorSeconds: int(t["priorSeconds"]) ?? 0,
        canStop: t["canStop"] as? Bool ?? false)
    }
    return Company(
      id: c["id"] as? String ?? "",
      name: c["name"] as? String ?? "",
      accent: c["accent"] as? String ?? "",
      canViewDashboard: c["canViewDashboard"] as? Bool ?? false,
      figures: (c["figures"] as? [String: Any]).map(figures),
      timers: timers,
      // Absent from a snapshot written before the field: what is listed.
      runningCount: max(int(c["runningCount"]) ?? timers.count, timers.count),
      recentTasks: objects(c["recentTasks"]).map { t in
        Task(
          taskId: t["taskId"] as? String ?? "",
          description: t["description"] as? String ?? "",
          client: t["client"] as? String ?? "")
      },
      today: (c["today"] as? [String: Any]).flatMap { t in
        guard let date = t["date"] as? String, !date.isEmpty else { return nil }
        return Today(date: date, doneSeconds: int(t["doneSeconds"]) ?? 0)
      })
  }

  private static func figures(_ f: [String: Any]) -> Figures {
    var periods: [String: Period] = [:]
    for (key, value) in (f["periods"] as? [String: Any]) ?? [:] {
      guard let p = value as? [String: Any] else { continue }
      periods[key] = Period(
        label: p["label"] as? String ?? "",
        name: p["name"] as? String ?? "",
        endsOn: p["endsOn"] as? String ?? "",
        fetchedAt: date(p["fetchedAt"]),
        invoices: (p["invoices"] as? [String: Any]).map(figure),
        payments: (p["payments"] as? [String: Any]).map(figure),
        expenses: (p["expenses"] as? [String: Any]).map(figure))
    }
    var outstanding: Outstanding?
    if let o = f["outstanding"] as? [String: Any], let amount = o["amount"] as? [String: Any] {
      outstanding = Outstanding(
        amount: money(amount),
        unpaidCount: int(o["unpaidCount"]) ?? 0,
        pastDueCount: int(o["pastDueCount"]),
        pastDueExact: o["pastDueExact"] as? Bool ?? true,
        pastDueAmount: (o["pastDueAmount"] as? [String: Any]).map(money),
        pastDueShare: (o["pastDueShare"] as? NSNumber).map { min(1, max(0, $0.doubleValue)) })
    }
    var attention: Attention?
    if let a = f["attention"] as? [String: Any] {
      attention = Attention(
        pastDue: objects(a["pastDue"]).compactMap(invoiceRow),
        dueSoon: objects(a["dueSoon"]).compactMap(invoiceRow),
        nextDue: (a["nextDue"] as? [String: Any]).flatMap(invoiceRow))
    }
    return Figures(
      fetchedAt: date(f["fetchedAt"]),
      outstanding: outstanding,
      periods: periods,
      attention: attention,
      inCurrency: f["inCurrency"] as? String ?? "")
  }

  private static func figure(_ f: [String: Any]) -> Figure {
    Figure(amount: money(f), deltaPct: int(f["deltaPct"]), good: f["good"] as? Bool)
  }

  private static func money(_ m: [String: Any]) -> Money {
    let text = m["text"] as? String ?? ""
    let compact = m["compact"] as? String ?? ""
    return Money(text: text, compact: compact.isEmpty ? text : compact)
  }

  private static func invoiceRow(_ r: [String: Any]) -> InvoiceRow? {
    guard let id = r["id"] as? String, !id.isEmpty else { return nil }
    return InvoiceRow(
      id: id,
      number: r["number"] as? String ?? "",
      client: r["client"] as? String ?? "",
      amount: (r["amount"] as? [String: Any]).map(money) ?? Money(text: "", compact: ""),
      lateSince: nonEmpty(r["lateSince"]),
      dueOn: nonEmpty(r["dueOn"]))
  }

  private static func objects(_ v: Any?) -> [[String: Any]] {
    (v as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
  }

  private static func int(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }

  private static func date(_ v: Any?) -> Date? {
    guard let ms = (v as? NSNumber)?.doubleValue else { return nil }
    return Date(timeIntervalSince1970: ms / 1000)
  }

  private static func nonEmpty(_ v: Any?) -> String? {
    guard let s = v as? String, !s.isEmpty else { return nil }
    return s
  }
}

// MARK: - Text

/// Text helpers every widget shares — the Swift twin of `HomeWidgets` text
/// functions on Android.
enum WidgetText {
  /// Fills `:name` placeholders, longest name first (as `Localization.lookup`).
  static func fill(_ template: String, _ params: [String: String]) -> String {
    var out = template
    for (k, v) in params.sorted(by: { $0.key.count > $1.key.count }) {
      out = out.replacingOccurrences(of: ":\(k)", with: v)
    }
    return out
  }

  /// A `yyyy-MM-dd` date (anything after ignored), in the device's calendar.
  static func day(_ iso: String?) -> Date? {
    guard let iso, iso.count >= 10 else { return nil }
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: String(iso.prefix(10)))
  }

  /// `date` as `yyyy-MM-dd` in the device's calendar — the form the
  /// snapshot's `today.date` takes.
  static func iso(_ date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
  }

  /// Whole days from `from` to `to`, by the calendar (not 24 h blocks).
  static func days(from: Date, to: Date) -> Int {
    let cal = Calendar.current
    return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to))
      .day ?? 0
  }

  static func daysLate(_ s: WidgetSnapshot, _ lateSince: String?, now: Date) -> String? {
    guard let since = day(lateSince) else { return nil }
    let n = max(1, days(from: since, to: now))
    let template =
      n == 1
      ? s.string("days_late_count_singular", ":count day late")
      : s.string("days_late_count_plural", ":count days late")
    return fill(template, ["count": "\(n)"])
  }

  static func dueIn(_ s: WidgetSnapshot, _ dueOn: String?, now: Date) -> String? {
    guard let due = day(dueOn) else { return nil }
    let n = days(from: now, to: due)
    if n <= 0 { return s.string("widget_due_today", "due today") }
    return fill(s.string("widget_due_in_days", "due in :count days"), ["count": "\(n)"])
  }

  /// Whether a period's figures are for a period that has ended since.
  static func periodEnded(_ endsOn: String, now: Date) -> Bool {
    guard let end = day(endsOn) else { return false }
    return days(from: end, to: now) > 0
  }
}
