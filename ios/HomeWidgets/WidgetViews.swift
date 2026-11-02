import SwiftUI
import WidgetKit

/// What every widget shares: links, the states it draws the same way, the
/// "Updated" footer, colours and masking.

let kWidgetMask = "••••"
/// A masked hero figure: `•` at 30 pt is a few dots that read as a glitch.
let kWidgetHeroMask = "●●●●"

/// Figures this old (or from a period that has ended) are flagged "Tap to
/// refresh". Neutral before that: a widget must not look broken every morning.
let kWidgetStaleAfter: TimeInterval = 72 * 60 * 60

/// A running timer from a snapshot this old shows "Running since 9:14", not a
/// ticking clock: it may have been stopped on another device since.
let kWidgetTimerStaleAfter: TimeInterval = 12 * 60 * 60

enum WidgetLink {
  /// `invoiceninja://app/<route>?company=<id>` — the app's deep link, which
  /// `DeepLinkRouter` validates, holds while locked, and switches company for.
  static func url(_ route: String, company: String) -> URL {
    // [route] may carry a list filter: "/invoices?filter=past_due".
    let parts = route.split(separator: "?", maxSplits: 1).map(String.init)
    var c = URLComponents()
    c.scheme = "invoiceninja"
    c.host = "app"
    c.path = parts.first ?? route
    var items: [URLQueryItem] = []
    if parts.count > 1, parts[1].hasPrefix("filter=") {
      items.append(URLQueryItem(name: "filter", value: String(parts[1].dropFirst(7))))
    }
    if !company.isEmpty { items.append(URLQueryItem(name: "company", value: company)) }
    if !items.isEmpty { c.queryItems = items }
    return c.url ?? URL(string: "invoiceninja://app/dashboard")!
  }

  /// A task's record, or the tasks list for one still on a local `tmp_` id
  /// (created offline, not yet synced): DeepLinkRouter refuses a record the
  /// server doesn't have.
  static func taskRoute(_ taskId: String) -> String {
    taskId.isEmpty || taskId.hasPrefix("tmp_") ? "/tasks" : "/tasks/\(taskId)"
  }

  /// Opens the app without a destination.
  static let app = URL(string: "invoiceninja://app/dashboard")!
}

/// The next moment a widget's text changes on its own — local midnight
/// ("12 days late", a period ending), a stale threshold — for the timeline.
func nextWidgetBoundary(_ snapshot: WidgetSnapshot?, now: Date) -> Date {
  let cal = Calendar.current
  let midnight =
    cal.date(byAdding: .minute, value: 1, to: cal.startOfDay(for: now.addingTimeInterval(86_400)))
    ?? now.addingTimeInterval(3600)
  var next = midnight
  for c in snapshot?.companies ?? [] {
    if let f = c.figures?.fetchedAt?.addingTimeInterval(kWidgetStaleAfter), f > now {
      next = min(next, f)
    }
    if !c.timers.isEmpty, let s = snapshot?.writtenAt.addingTimeInterval(kWidgetTimerStaleAfter),
      s > now
    {
      next = min(next, s)
    }
  }
  return next
}

/// The message a widget shows when it has nothing of its own to draw, or nil
/// when it can draw. `needsFigures` is false for the Timer widget, which works
/// without the dashboard permission.
func widgetStateMessage(
  _ snapshot: WidgetSnapshot?, companyId: String, needsFigures: Bool
) -> (text: String, url: URL, symbol: String)? {
  guard let s = snapshot else {
    // Before any snapshot: no app strings yet, so the device's language.
    return (String(localized: "Open Invoice Ninja to load your data"), WidgetLink.app, "arrow.down.circle")
  }
  if s.tooNew {
    return (
      s.string("widget_update_app", "Update Invoice Ninja to use this widget"), WidgetLink.app,
      "arrow.up.circle"
    )
  }
  if !s.signedIn {
    return (s.string("widget_sign_in", "Sign in to Invoice Ninja"), WidgetLink.app, "person.crop.circle")
  }
  guard let company = s.company(companyId) else {
    // Long-press → Edit Widget is how a company is chosen on iOS.
    return (s.string("widget_choose_company", "Choose a company"), WidgetLink.app, "building.2")
  }
  if needsFigures && !company.canViewDashboard {
    return (
      s.string("widget_no_dashboard_permission", "Your role can't view dashboard figures"),
      WidgetLink.app, "lock"
    )
  }
  return nil
}

/// A company whose figures aren't loaded yet — never fetched, a pinned
/// company the app hasn't opened, a failed fetch. Not zero, not "nothing".
func notLoadedText(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> String {
  company.id != s.activeCompanyId
    ? WidgetText.fill(
      s.string("widget_open_company_to_update", "Open :company to update"),
      ["company": company.name])
    : String(localized: "Open Invoice Ninja to load your data")
}

/// A widget with nothing of its own to draw: a glyph and one line that says
/// what a tap does — a call to action, so primary ink, not an error's grey.
struct WidgetMessageView: View {
  @Environment(\.widgetFamily) private var family
  var text: String
  var symbol: String = "arrow.clockwise.circle"

  var body: some View {
    let glyph = Image(systemName: symbol)
      .font(.title2.weight(.semibold))
      .foregroundStyle(.tint)
      .widgetAccentable()
      .accessibilityHidden(true)
    let line = Text(text)
      .font(.subheadline.weight(.medium))
      .foregroundStyle(.primary)
      .minimumScaleFactor(0.8)
    Group {
      if isAccessory {
        // Lock screen: the system tints it; a glyph would crowd one line.
        Text(text).font(.caption).multilineTextAlignment(.center).minimumScaleFactor(0.8)
      } else if family == .systemMedium {
        HStack(spacing: 10) {
          glyph
          line.multilineTextAlignment(.leading)
        }
      } else {
        VStack(spacing: 8) {
          glyph
          line.multilineTextAlignment(.center)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var isAccessory: Bool {
    #if os(iOS)
      [.accessoryInline, .accessoryRectangular, .accessoryCircular].contains(family)
    #else
      false
    #endif
  }
}

/// The app's status colours (design tokens), never carrying meaning alone.
enum WidgetColor {
  /// The app's accent (`InTheme.accent` #2F7DC3), lifted in dark mode to keep
  /// its contrast on the dark widget. The extension has no asset catalog, so
  /// without this `.tint` is the system blue.
  static let brand = dynamic(light: (0.184, 0.490, 0.765), dark: (0.478, 0.706, 0.910))

  /// White, and the dark grey Apple's own widgets sit on — never the
  /// translucent `.fill.tertiary`, against which a `.quaternary` row card
  /// all but disappears. Tinted and clear modes remove it themselves.
  static let background = dynamic(light: (1, 1, 1), dark: (0.110, 0.110, 0.118))

  private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    #if os(iOS)
      Color(
        UIColor { traits in
          let c = traits.userInterfaceStyle == .dark ? dark : light
          return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    #else
      Color(
        NSColor(name: nil) { appearance in
          let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
          return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    #endif
  }

  static func good(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0.25, green: 0.73, blue: 0.50) : Color(red: 0.12, green: 0.54, blue: 0.36)
  }
  static func bad(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0.90, green: 0.38, blue: 0.33) : Color(red: 0.75, green: 0.22, blue: 0.17)
  }
  static func warning(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(red: 0.89, green: 0.60, blue: 0.30) : Color(red: 0.71, green: 0.33, blue: 0.04)
  }
}

/// "Company · Updated 3 hours ago", amber with "Tap to refresh" once stale.
struct WidgetFooter: View {
  @Environment(\.colorScheme) private var scheme
  var snapshot: WidgetSnapshot
  var company: WidgetSnapshot.Company
  var fetchedAt: Date?
  var periodEnded: Bool = false
  var now: Date

  var body: some View {
    let stale =
      fetchedAt == nil || now.timeIntervalSince(fetchedAt!) > kWidgetStaleAfter || periodEnded
    HStack(spacing: 4) {
      if snapshot.companies.count > 1 {
        Text(company.name).lineLimit(1)
        Text("·")
      }
      if let fetchedAt {
        // Absolute, never "2 min ago": a widget redraws only at its next
        // timeline entry, and a relative stamp frozen at render time would go
        // on claiming freshness all day.
        Text("\(snapshot.string("updated", "Updated")) \(updatedStamp(fetchedAt, now: now))")
      }
      if stale {
        Text("·")
        Text(
          company.id != snapshot.activeCompanyId
            ? WidgetText.fill(
              snapshot.string("widget_open_company_to_update", "Open :company to update"),
              ["company": company.name])
            : snapshot.string("widget_tap_to_refresh", "Tap to refresh"))
      }
    }
    .font(.caption2)
    .lineLimit(1)
    .foregroundStyle(stale ? WidgetColor.warning(scheme) : .secondary)
  }
}

/// "9:41" today, "Oct 30" before — the moment the figures were fetched.
func updatedStamp(_ at: Date, now: Date) -> String {
  Calendar.current.isDate(at, inSameDayAs: now)
    ? at.formatted(date: .omitted, time: .shortened)
    : at.formatted(.dateTime.month(.abbreviated).day())
}

extension View {
  /// The app's language decides the layout direction, not the device's.
  /// Text size is capped: a widget's frame is fixed, and past this the
  /// figures stop fitting at all.
  func widgetDirection(_ snapshot: WidgetSnapshot?) -> some View {
    environment(\.layoutDirection, snapshot?.rtl == true ? .rightToLeft : .leftToRight)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

/// How much of Outstanding is past due: a thin track with the past-due share
/// in red — the one figure a glance can't get from two amounts. A rounded
/// rectangle, never a pill; hidden from VoiceOver, which the caption beside
/// it already tells.
struct PastDueBar: View {
  @Environment(\.colorScheme) private var scheme
  var share: Double

  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2, style: .continuous).fill(.quaternary)
        // A sliver stays visible: 1% past due is not "none".
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(WidgetColor.bad(scheme))
          .frame(width: share > 0 ? max(4, g.size.width * share) : 0)
          .widgetAccentable()
      }
    }
    .frame(height: 4)
    .accessibilityHidden(true)
  }
}
