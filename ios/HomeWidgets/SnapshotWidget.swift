import AppIntents
import SwiftUI
import WidgetKit

/// Business snapshot. Small: one figure (Outstanding by default) with its
/// caption. Medium: Outstanding as the hero, "4 unpaid · 2 past due", and one
/// period figure with its trend. Each region opens its own list.
@available(iOS 17.0, macOS 14.0, *)
struct SnapshotWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: WidgetFiles.kindSnapshot, intent: SnapshotConfigIntent.self,
      provider: SnapshotProvider()
    ) { entry in
      SnapshotWidgetView(entry: entry)
        .containerBackground(WidgetColor.background, for: .widget)
        .tint(WidgetColor.brand)
    }
    .configurationDisplayName("Business snapshot")
    .description("See what you're owed, what's past due, and this period's payments.")
    .supportedFamilies(Self.families)
  }

  /// The lock screen too: "what am I owed" is the glance Stripe built its
  /// whole iOS widget on. `privacySensitive` redacts the amounts while locked.
  static var families: [WidgetFamily] {
    #if os(iOS)
      [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
    #else
      [.systemSmall, .systemMedium]
    #endif
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct SnapshotEntry: TimelineEntry {
  var date: Date
  var snapshot: WidgetSnapshot?
  var config: SnapshotConfigIntent
  var relevance: TimelineEntryRelevance?
}

@available(iOS 17.0, macOS 14.0, *)
struct SnapshotProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SnapshotEntry {
    SnapshotEntry(date: .now, snapshot: SampleSnapshot.value, config: SnapshotConfigIntent())
  }

  func snapshot(for config: SnapshotConfigIntent, in context: Context) async -> SnapshotEntry {
    // The widget gallery shows sample figures, never "Sign in".
    // Sample figures for the gallery only — never in place of a real user's.
    let s = context.isPreview ? SampleSnapshot.value : WidgetSnapshot.load()
    return SnapshotEntry(date: .now, snapshot: s, config: config)
  }

  func timeline(for config: SnapshotConfigIntent, in context: Context) async -> Timeline<SnapshotEntry> {
    let now = Date()
    let s = WidgetSnapshot.load()
    // More past-due invoices: worth surfacing in a Smart Stack.
    let late = s?.company(config.company?.id ?? "")?.figures?.outstanding?.pastDueCount ?? 0
    let entry = SnapshotEntry(
      date: now, snapshot: s, config: config,
      relevance: late > 0 ? TimelineEntryRelevance(score: Float(min(late, 10))) : nil)
    return Timeline(entries: [entry], policy: .after(nextWidgetBoundary(s, now: now)))
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct SnapshotWidgetView: View {
  var entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let companyId = entry.config.company?.id ?? ""
    if let message = widgetStateMessage(entry.snapshot, companyId: companyId, needsFigures: true) {
      WidgetMessageView(text: message.text, symbol: message.symbol).widgetURL(message.url)
    } else if let s = entry.snapshot, let company = s.company(companyId) {
      if company.figures == nil {
        WidgetMessageView(text: notLoadedText(s, company))
          .widgetURL(WidgetLink.url("/dashboard", company: company.id))
      } else {
        familyContent(s, company)
          .widgetDirection(s)
          .foregroundStyle(.primary)
          .widgetURL(WidgetLink.url(tapRoute, company: company.id))
      }
    }
  }

  /// A small widget is one tap target (its `Link`s are ignored), so the whole
  /// widget goes where its one figure does; larger sizes open the dashboard
  /// from the background and each figure from its own region.
  private var tapRoute: String {
    guard family != .systemMedium else { return "/dashboard" }
    // No figures for the chosen period: the widget draws Outstanding, so it
    // goes where Outstanding does.
    let period = entry.snapshot?.company(entry.config.company?.id ?? "")?.figures?.periods[
      entry.config.period.rawValue]
    if period == nil { return "/invoices?filter=unpaid" }
    switch entry.config.figure {
    case .outstanding: return "/invoices?filter=unpaid"
    case .invoices: return "/invoices"
    case .payments: return "/payments"
    case .expenses: return "/expenses"
    }
  }

  private func masked(_ s: WidgetSnapshot) -> Bool { entry.config.hideAmounts.masks(appLock: s.appLock) }

  /// What VoiceOver reads for an amount: the full figure, or "Amount hidden"
  /// — never "bullet bullet bullet bullet".
  private func amountLabel(_ m: WidgetSnapshot.Money?, _ s: WidgetSnapshot) -> String {
    guard let m else { return "—" }
    return masked(s) ? s.string("widget_amount_hidden", "Amount hidden") : m.text
  }

  private func amount(_ m: WidgetSnapshot.Money?, compact: Bool, _ s: WidgetSnapshot) -> String {
    guard let m else { return "—" }
    if masked(s) { return kWidgetMask }
    return compact ? m.compact : m.text
  }

  @ViewBuilder
  private func familyContent(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    switch family {
    #if os(iOS)
      case .accessoryRectangular: rectangular(s, company)
      case .accessoryCircular: circular(s, company)
      case .accessoryInline: inline(s, company)
    #endif
    default: content(s, company)
    }
  }

  @ViewBuilder
  private func content(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    let figures = company.figures
    let period = figures?.periods[entry.config.period.rawValue]
    let small = family == .systemSmall
    VStack(alignment: .leading, spacing: 2) {
      if small, entry.config.figure != .outstanding, let period {
        periodHero(s, company, period)
      } else {
        outstandingHero(s, company, compact: small)
      }
      if !small, let period {
        periodRow(s, company, period).padding(.top, 6)
      }
      Spacer(minLength: 0)
      WidgetFooter(
        snapshot: s, company: company, fetchedAt: figures?.fetchedAt,
        periodEnded: period.map { WidgetText.periodEnded($0.endsOn, now: entry.date) } ?? false,
        now: entry.date)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The hero figure: never shrunk by the height (`fixedSize` vertically —
  /// the medium's content once squeezed it to the period row's size), only
  /// by a long amount's width. Masked, it is `●●●●`: four bullets at this
  /// size read as a rendering glitch.
  private func heroText(_ m: WidgetSnapshot.Money?, compact: Bool, size: CGFloat, _ s: WidgetSnapshot)
    -> some View
  {
    let hidden = masked(s) && m != nil
    // `●` at the hero's size is a row of black discs; at 15 pt it reads as a
    // password field: deliberate.
    return Text(hidden ? kWidgetHeroMask : amount(m, compact: compact, s))
      .font(.system(size: hidden ? 15 : size, weight: .bold, design: .rounded))
      .monospacedDigit()
      .minimumScaleFactor(0.5).lineLimit(1)
      .fixedSize(horizontal: false, vertical: true)
      .privacySensitive()
      .widgetAccentable()
      .accessibilityLabel(amountLabel(m, s))
  }

  /// "Outstanding", or "Outstanding · in USD" when several currencies were
  /// converted — on the label's line, not one of its own the medium lacks.
  private func outstandingLabel(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> String {
    let label = s.string("outstanding", "Outstanding")
    guard let currency = company.figures?.inCurrency, !currency.isEmpty else { return label }
    return "\(label) · \(WidgetText.fill(s.string("widget_in_currency", "in :currency"), ["currency": currency]))"
  }

  @ViewBuilder
  private func outstandingHero(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company, compact: Bool)
    -> some View
  {
    let o = company.figures?.outstanding
    VStack(alignment: .leading, spacing: 2) {
      Link(destination: WidgetLink.url("/invoices?filter=unpaid", company: company.id)) {
        VStack(alignment: .leading, spacing: 1) {
          Text(outstandingLabel(s, company))
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
          heroText(o?.amount, compact: compact, size: compact ? 28 : 32, s)
        }
      }
      .accessibilityElement(children: .combine)
      if let o {
        // Its own region, led by the past-due count: the past-due invoices,
        // as on Android (a small widget is one target either way).
        Link(
          destination: WidgetLink.url(
            (o.pastDueCount ?? 0) > 0 ? "/invoices?filter=past_due" : "/invoices?filter=unpaid",
            company: company.id)
        ) {
          VStack(alignment: .leading, spacing: 6) {
            caption(s, o)
            // Small has the room; medium's goes to the period figure.
            if compact, let share = o.pastDueShare {
              PastDueBar(share: share).padding(.top, 2)
            }
          }
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  @ViewBuilder
  private func caption(_ s: WidgetSnapshot, _ o: WidgetSnapshot.Outstanding) -> some View {
    let late = o.pastDueCount ?? 0
    let unpaid = WidgetText.fill(s.string("unpaid_count_label", ":count unpaid"), ["count": "\(o.unpaidCount)"])
    let bad = WidgetColor.bad(scheme)
    // Every piece is its own child, the "·" included, so a right-to-left
    // layout reverses whole pieces — a "· $3.1K" string put its dot on the
    // wrong side. One line, shrinking rather than wrapping: an HStack of
    // wrapping Texts split "4 unpaid" into columns ("4 un…"). Only the past
    // due part is red: "4 unpaid" is not an alarm.
    HStack(spacing: 4) {
      if family != .systemSmall || late == 0 {
        Text(unpaid).foregroundStyle(.secondary)
      }
      if late > 0 {
        if family != .systemSmall { Text("·").foregroundStyle(.secondary) }
        Group {
          // A glyph as well as the colour: tinted and StandBy modes drop colour.
          Image(systemName: "exclamationmark.circle.fill")
          Text(pastDueText(s, o))
          // Small has room for one fact: the count.
          if family != .systemSmall, let a = o.pastDueAmount {
            Text("·")
            Text(amount(a, compact: true, s)).privacySensitive()
          }
        }
        .foregroundStyle(bad)
      }
    }
    .font(.caption)
    .lineLimit(1)
    .minimumScaleFactor(0.75)
  }

  private func pastDueText(_ s: WidgetSnapshot, _ o: WidgetSnapshot.Outstanding) -> String {
    let late = o.pastDueCount ?? 0
    return WidgetText.fill(
      s.string("past_due_count_label", ":count past due"),
      ["count": o.pastDueExact ? "\(late)" : "\(late)+"])
  }

  /// "This Month", or the period's own name ("October") once it has ended —
  /// last month's figures never sit under "This Month".
  private func periodName(_ p: WidgetSnapshot.Period) -> String {
    WidgetText.periodEnded(p.endsOn, now: entry.date) ? p.name : p.label
  }

  private func periodLabel(_ s: WidgetSnapshot, _ key: String, _ fallback: String, _ p: WidgetSnapshot.Period)
    -> String
  {
    "\(s.string(key, fallback)) · \(periodName(p))"
  }

  private func chosenFigure(_ p: WidgetSnapshot.Period)
    -> (fig: WidgetSnapshot.Figure?, key: String, fallback: String, route: String)
  {
    switch entry.config.figure {
    case .invoices: (p.invoices, "invoices", "Invoices", "/invoices")
    case .expenses: (p.expenses, "expenses", "Expenses", "/expenses")
    default: (p.payments, "payments", "Payments", "/payments")
    }
  }

  @ViewBuilder
  private func periodHero(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company, _ p: WidgetSnapshot.Period)
    -> some View
  {
    let c = chosenFigure(p)
    Link(destination: WidgetLink.url(c.route, company: company.id)) {
      VStack(alignment: .leading, spacing: 1) {
        // Just the figure's name: "Payments · This Month" truncated here.
        Text(s.string(c.key, c.fallback)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        heroText(c.fig?.amount, compact: true, size: 28, s)
        // The period rides with the trend it qualifies: "↗ 8% · This Month".
        HStack(spacing: 4) {
          trend(c.fig, s)
          if c.fig?.deltaPct != nil { Text("·").foregroundStyle(.secondary) }
          Text(periodName(p)).foregroundStyle(.secondary)
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      }
    }
    .accessibilityElement(children: .combine)
  }

  /// Medium's second figure: one plain line, label leading and amount
  /// trailing — a filled card here read as a form field and competed with
  /// the hero.
  @ViewBuilder
  private func periodRow(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company, _ p: WidgetSnapshot.Period)
    -> some View
  {
    Link(destination: WidgetLink.url("/payments", company: company.id)) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(periodLabel(s, "payments", "Payments", p))
          .font(.caption).foregroundStyle(.secondary)
          .lineLimit(1)
        Spacer(minLength: 4)
        Text(amount(p.payments?.amount, compact: false, s))
          .font(.subheadline.weight(.semibold)).monospacedDigit()
          .lineLimit(1).minimumScaleFactor(0.7)
          .privacySensitive()
          .accessibilityLabel(amountLabel(p.payments?.amount, s))
        trend(p.payments, s)
      }
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func trend(_ f: WidgetSnapshot.Figure?, _ s: WidgetSnapshot) -> some View {
    if let pct = f?.deltaPct {
      let up = pct > 0
      let color: Color =
        f?.good == nil ? .secondary : (f?.good == true ? WidgetColor.good(scheme) : WidgetColor.bad(scheme))
      HStack(spacing: 2) {
        if pct != 0 { Image(systemName: up ? "arrow.up.right" : "arrow.down.right") }
        // Masked: the arrow says which way, the size would hint at the amount.
        if !masked(s) { Text("\(abs(pct))%") }
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(color)
      .accessibilityLabel(
        masked(s)
          ? ""
          : WidgetText.fill(
            up
              ? s.string("widget_trend_up", "Up :percent% versus the same days last period")
              : s.string("widget_trend_down", "Down :percent% versus the same days last period"),
            ["percent": "\(abs(pct))"]))
    }
  }

  // MARK: - Lock screen

  #if os(iOS)
    /// "Outstanding / $12.4K / ⚠ 2 past due", or the chosen period figure.
    @ViewBuilder
    private func rectangular(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
      let figures = company.figures
      VStack(alignment: .leading, spacing: 0) {
        if entry.config.figure != .outstanding, let p = figures?.periods[entry.config.period.rawValue] {
          let c = chosenFigure(p)
          Text(periodLabel(s, c.key, c.fallback, p)).font(.caption).lineLimit(1)
          Text(amount(c.fig?.amount, compact: true, s))
            .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.6)
            .privacySensitive()
            .widgetAccentable()
            .accessibilityLabel(amountLabel(c.fig?.amount, s))
          trend(c.fig, s)
        } else {
          let o = figures?.outstanding
          Text(s.string("outstanding", "Outstanding")).font(.caption).lineLimit(1)
          Text(amount(o?.amount, compact: true, s))
            .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.6)
            .privacySensitive()
            .widgetAccentable()
            .accessibilityLabel(amountLabel(o?.amount, s))
          if let o {
            HStack(spacing: 3) {
              if (o.pastDueCount ?? 0) > 0 {
                Image(systemName: "exclamationmark.circle.fill")
                Text(pastDueText(s, o))
              } else {
                Text(
                  WidgetText.fill(
                    s.string("unpaid_count_label", ":count unpaid"), ["count": "\(o.unpaidCount)"]))
              }
            }
            .font(.caption).lineLimit(1)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The past-due count in a ring — the number to act on — else unpaid.
    @ViewBuilder
    private func circular(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
      let o = company.figures?.outstanding
      let late = o?.pastDueCount ?? 0
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Image(systemName: late > 0 ? "exclamationmark.circle.fill" : "doc.text")
            .font(.system(size: 12, weight: .semibold))
          Text(late > 0 ? (o?.pastDueExact == false ? "\(late)+" : "\(late)") : "\(o?.unpaidCount ?? 0)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5).lineLimit(1)
            .widgetAccentable()
        }
        .padding(4)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        o.map { late > 0 ? pastDueText(s, $0) : WidgetText.fill(
          s.string("unpaid_count_label", ":count unpaid"), ["count": "\($0.unpaidCount)"]) } ?? "—")
    }

    /// "$12.4K · 2 past due"
    @ViewBuilder
    private func inline(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
      let o = company.figures?.outstanding
      let detail: String =
        o.map {
          ($0.pastDueCount ?? 0) > 0
            ? pastDueText(s, $0)
            : WidgetText.fill(s.string("unpaid_count_label", ":count unpaid"), ["count": "\($0.unpaidCount)"])
        } ?? ""
      Label {
        Text([amount(o?.amount, compact: true, s), detail].filter { !$0.isEmpty }.joined(separator: " · "))
          .privacySensitive()
      } icon: {
        Image(systemName: "doc.text")
      }
    }
  #endif
}
