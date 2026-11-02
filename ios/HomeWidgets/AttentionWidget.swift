import AppIntents
import SwiftUI
import WidgetKit

/// Needs attention: past-due invoices first, then those due within a week —
/// the in-app band at a glance. "Nothing past due" and the next invoice due
/// when there is nothing to chase. Each row opens its invoice.
@available(iOS 17.0, macOS 14.0, *)
struct AttentionWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: WidgetFiles.kindAttention, intent: AttentionConfigIntent.self,
      provider: AttentionProvider()
    ) { entry in
      AttentionWidgetView(entry: entry)
        .containerBackground(WidgetColor.background, for: .widget)
        .tint(WidgetColor.brand)
    }
    .configurationDisplayName("Needs attention")
    .description("Chase past-due invoices and see what's due this week. Tap one to open it.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct AttentionEntry: TimelineEntry {
  var date: Date
  var snapshot: WidgetSnapshot?
  var config: AttentionConfigIntent
  var relevance: TimelineEntryRelevance?
}

@available(iOS 17.0, macOS 14.0, *)
struct AttentionProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> AttentionEntry {
    AttentionEntry(date: .now, snapshot: SampleSnapshot.value, config: AttentionConfigIntent())
  }

  func snapshot(for config: AttentionConfigIntent, in context: Context) async -> AttentionEntry {
    let s = context.isPreview ? SampleSnapshot.value : WidgetSnapshot.load()
    return AttentionEntry(date: .now, snapshot: s, config: config)
  }

  func timeline(for config: AttentionConfigIntent, in context: Context) async -> Timeline<AttentionEntry> {
    let now = Date()
    let s = WidgetSnapshot.load()
    // The rows are a top few; the count is the whole of it.
    let late = s?.company(config.company?.id ?? "")?.figures?.outstanding?.pastDueCount ?? 0
    let entry = AttentionEntry(
      date: now, snapshot: s, config: config,
      relevance: late > 0 ? TimelineEntryRelevance(score: Float(min(late, 10))) : nil)
    return Timeline(entries: [entry], policy: .after(nextWidgetBoundary(s, now: now)))
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct AttentionWidgetView: View {
  var entry: AttentionEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let companyId = entry.config.company?.id ?? ""
    if let message = widgetStateMessage(entry.snapshot, companyId: companyId, needsFigures: true) {
      WidgetMessageView(text: message.text, symbol: message.symbol).widgetURL(message.url)
    } else if let s = entry.snapshot, let company = s.company(companyId) {
      if company.figures?.attention == nil {
        // Not loaded is not "nothing past due".
        WidgetMessageView(text: notLoadedText(s, company))
          .widgetURL(WidgetLink.url("/dashboard", company: company.id))
      } else {
        content(s, company)
          .widgetDirection(s)
          .foregroundStyle(.primary)
          .widgetURL(
            WidgetLink.url(
              (company.figures?.attention?.pastDue.isEmpty ?? true)
                ? "/invoices?filter=unpaid" : "/invoices?filter=past_due",
              company: company.id))
      }
    }
  }

  private var masked: Bool { entry.config.hideAmounts.masks(appLock: entry.snapshot?.appLock ?? false) }

  private func money(_ m: WidgetSnapshot.Money?, compact: Bool) -> String {
    guard let m else { return "—" }
    return masked ? kWidgetMask : (compact ? m.compact : m.text)
  }

  @ViewBuilder
  private func content(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    let attention = company.figures?.attention
    let late = attention?.pastDue ?? []
    let soon = attention?.dueSoon ?? []
    let large = family == .systemLarge
    // Measured: a medium widget's content area (~126 pt) holds the header,
    // two rows and the footer; three spilled past its edges. A large holds
    // six, or five and the "Due soon" heading that keeps a due-soon row from
    // sitting under "Past due".
    let split = large && !late.isEmpty && !soon.isEmpty
    let capacity = large ? (split ? 5 : 6) : 2
    let lateRows = Array(late.prefix(capacity))
    let soonRows = Array(soon.prefix(capacity - lateRows.count))
    VStack(alignment: .leading, spacing: 4) {
      header(s, company, late: late)
      if lateRows.isEmpty && soonRows.isEmpty {
        if let next = attention?.nextDue {
          // Nothing to chase: what falls due next, drawn as a row — with its
          // amount — not a run-on sentence.
          sectionLabel(s.string("next_due", "Next due"))
          invoiceRow(s, company, next)
        }
      } else {
        ForEach(lateRows, id: \.id) { row in invoiceRow(s, company, row) }
        if split && !soonRows.isEmpty { sectionLabel(s.string("widget_due_soon", "Due soon")) }
        ForEach(soonRows, id: \.id) { row in invoiceRow(s, company, row) }
      }
      // A large with room to spare is not a stretched medium: the spare
      // space carries the total the rows add up to — under the rows, so the
      // gap falls at the bottom rather than splitting the widget.
      if large && lateRows.count + soonRows.count <= 3 {
        outstandingBlock(s, company).padding(.top, 6)
      }
      Spacer(minLength: 0)
      WidgetFooter(snapshot: s, company: company, fetchedAt: company.figures?.fetchedAt, now: entry.date)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// "⚠ Past due · 2 · $3.1K", or a green "✓ Nothing past due" — the good
  /// state says so, rather than looking like an error.
  @ViewBuilder
  private func header(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company, late: [WidgetSnapshot.InvoiceRow])
    -> some View
  {
    HStack(spacing: 4) {
      if late.isEmpty {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(WidgetColor.good(scheme))
        Text(s.string("widget_nothing_past_due", "Nothing past due"))
      } else {
        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(WidgetColor.bad(scheme))
        Text("\(s.string("past_due", "Past Due")) · \(pastDueCount(company, fallback: late.count))")
        if let a = company.figures?.outstanding?.pastDueAmount {
          // Two children, so right-to-left keeps the dot between the pieces.
          Text("·").foregroundStyle(.secondary)
          Text(money(a, compact: true)).foregroundStyle(.secondary).privacySensitive()
        }
      }
    }
    .font(.subheadline.weight(.semibold))
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .widgetAccentable()
    .accessibilityElement(children: .combine)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.top, 2)
  }

  /// The real past-due count ("12", or "50+"), not the rows shown.
  private func pastDueCount(_ company: WidgetSnapshot.Company, fallback: Int) -> String {
    guard let o = company.figures?.outstanding, let n = o.pastDueCount else { return "\(fallback)" }
    return o.pastDueExact ? "\(n)" : "\(n)+"
  }

  @ViewBuilder
  private func outstandingBlock(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    if let o = company.figures?.outstanding {
      Link(destination: WidgetLink.url("/invoices?filter=unpaid", company: company.id)) {
        VStack(alignment: .leading, spacing: 1) {
          Divider().padding(.bottom, 6)
          Text(s.string("outstanding", "Outstanding")).font(.caption).foregroundStyle(.secondary)
          Text(masked ? kWidgetHeroMask : o.amount.text)
            .font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.5)
            .privacySensitive()
            .widgetAccentable()
            .accessibilityLabel(masked ? s.string("widget_amount_hidden", "Amount hidden") : o.amount.text)
          if let share = o.pastDueShare {
            PastDueBar(share: share).padding(.vertical, 4)
          }
          Text(WidgetText.fill(s.string("unpaid_count_label", ":count unpaid"), ["count": "\(o.unpaidCount)"]))
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// Who owes it and how much on the first line; which invoice and how late
  /// on the second. The full amount: a per-invoice `$1.2K` hid the cents a
  /// user chasing it wants.
  @ViewBuilder
  private func invoiceRow(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company, _ row: WidgetSnapshot.InvoiceRow)
    -> some View
  {
    let lateText = WidgetText.daysLate(s, row.lateSince, now: entry.date)
    let status = lateText ?? WidgetText.dueIn(s, row.dueOn, now: entry.date) ?? ""
    HStack(spacing: 0) {
      Link(destination: WidgetLink.url("/invoices/\(row.id)", company: company.id)) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(row.client.isEmpty ? row.number : row.client)
              .font(.footnote.weight(.medium)).lineLimit(1)
              .privacySensitive()
            Spacer(minLength: 6)
            Text(money(row.amount, compact: false))
              .font(.footnote.weight(.semibold)).monospacedDigit()
              .lineLimit(1).minimumScaleFactor(0.7)
              // Shrunk only by a long amount's width, never by the medium's
              // height: there it came out a size smaller than the client.
              .fixedSize(horizontal: false, vertical: true)
              .privacySensitive()
              .accessibilityLabel(masked ? s.string("widget_amount_hidden", "Amount hidden") : row.amount.text)
          }
          HStack(spacing: 3) {
            if lateText != nil { Image(systemName: "exclamationmark.circle.fill") }
            Text(
              [row.client.isEmpty ? "" : row.number, status].filter { !$0.isEmpty }.joined(separator: " · "))
          }
          .font(.caption2)
          .lineLimit(1)
          .foregroundStyle(lateText != nil ? AnyShapeStyle(WidgetColor.bad(scheme)) : AnyShapeStyle(.secondary))
        }
        .padding(.leading, 8).padding(.trailing, lateText != nil ? 4 : 8).padding(.vertical, 4)
      }
      .accessibilityElement(children: .combine)
      // Remind: a past-due invoice's email screen, one tap from the row that
      // says how late it is. A link only — sending stays in the app.
      if lateText != nil {
        Link(destination: WidgetLink.url("/invoices/\(row.id)/email", company: company.id)) {
          Image(systemName: "envelope")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: 34, height: 28)
            .contentShape(Rectangle())
            .widgetAccentable()
        }
        .accessibilityLabel(
          "\(s.string("email_invoice", "Email Invoice")) \(row.number)")
      }
    }
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}
