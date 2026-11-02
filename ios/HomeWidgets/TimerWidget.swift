import AppIntents
import SwiftUI
import WidgetKit

/// Running timer: the newest running task with a live clock and a one-tap
/// Stop (up to three in medium); idle, "Start a task" and the two most
/// recently worked tasks. Lock screen: rectangular and inline.
///
/// The clock is `Text(timerInterval:)`, which ticks on its own — no timeline
/// reloads. It starts at `runningSince − priorSeconds`, so it shows the task's
/// whole worked time, not just this session.
@available(iOS 17.0, macOS 14.0, *)
struct TimerWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: WidgetFiles.kindTimer, intent: TimerConfigIntent.self, provider: TimerProvider()
    ) { entry in
      TimerWidgetView(entry: entry)
        .containerBackground(WidgetColor.background, for: .widget)
        .tint(WidgetColor.brand)
    }
    .configurationDisplayName("Running timer")
    .description("A live clock for your running timer. Stop it, or start a recent task, in one tap.")
    .supportedFamilies(Self.families)
  }

  static var families: [WidgetFamily] {
    #if os(iOS)
      [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
    #else
      [.systemSmall, .systemMedium]
    #endif
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct TimerEntry: TimelineEntry {
  var date: Date
  var snapshot: WidgetSnapshot?
  var config: TimerConfigIntent
  /// Session (`WidgetFiles.stopKey`) → tap time of a Stop queued here and not
  /// yet applied by the app.
  var pendingStops: [String: Int64]
  var relevance: TimelineEntryRelevance?
}

@available(iOS 17.0, macOS 14.0, *)
struct TimerProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> TimerEntry {
    TimerEntry(date: .now, snapshot: SampleSnapshot.value, config: TimerConfigIntent(), pendingStops: [:])
  }

  func snapshot(for config: TimerConfigIntent, in context: Context) async -> TimerEntry {
    let s = context.isPreview ? SampleSnapshot.value : WidgetSnapshot.load()
    return TimerEntry(date: .now, snapshot: s, config: config, pendingStops: [:])
  }

  func timeline(for config: TimerConfigIntent, in context: Context) async -> Timeline<TimerEntry> {
    let now = Date()
    let s = WidgetSnapshot.load()
    let running = !(s?.company(config.company?.id ?? "")?.timers.isEmpty ?? true)
    let entry = TimerEntry(
      date: now, snapshot: s, config: config, pendingStops: WidgetFiles.pendingStops(),
      // A running timer leads the Smart Stack.
      relevance: running ? TimelineEntryRelevance(score: 100) : nil)
    return Timeline(entries: [entry], policy: .after(nextWidgetBoundary(s, now: now)))
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct TimerWidgetView: View {
  var entry: TimerEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let companyId = entry.config.company?.id ?? ""
    if let message = widgetStateMessage(entry.snapshot, companyId: companyId, needsFigures: false) {
      WidgetMessageView(text: message.text, symbol: message.symbol).widgetURL(message.url)
    } else if let s = entry.snapshot, let company = s.company(companyId) {
      Group {
        switch family {
        #if os(iOS)
          case .accessoryInline: inline(s, company)
          case .accessoryRectangular: rectangular(s, company)
        #endif
        default: home(s, company)
        }
      }
      .widgetDirection(s)
      .foregroundStyle(.primary)
      .widgetURL(WidgetLink.url(tapRoute(company), company: company.id))
    }
  }

  /// Small and lock-screen widgets are one tap target (their `Link`s are
  /// ignored): the whole widget goes where its one visible action does — the
  /// running task, or a new task when idle. Medium opens the tasks list from
  /// the background and each row from its own region.
  private func tapRoute(_ company: WidgetSnapshot.Company) -> String {
    if family == .systemMedium { return "/tasks" }
    if let t = company.timers.first { return WidgetLink.taskRoute(t.taskId) }
    return "/tasks/new"
  }

  private var stale: Bool {
    guard let s = entry.snapshot else { return false }
    return entry.date.timeIntervalSince(s.writtenAt) > kWidgetTimerStaleAfter
  }

  private func clockStart(_ t: WidgetSnapshot.Timer) -> Date {
    t.runningSince.addingTimeInterval(-TimeInterval(t.priorSeconds))
  }

  /// Whether `t`'s clock ticks: not stopped from this widget, not too old to trust.
  private func ticking(_ t: WidgetSnapshot.Timer) -> Bool {
    entry.pendingStops[WidgetFiles.stopKey(t.taskId, t.runningSince)] == nil && !stale
  }

  @ViewBuilder
  private func clock(_ s: WidgetSnapshot, _ t: WidgetSnapshot.Timer, font: Font, frozen: Bool = true)
    -> some View
  {
    if let at = entry.pendingStops[WidgetFiles.stopKey(t.taskId, t.runningSince)] {
      // Stopped from this widget; the app has not run since to apply it. The
      // time worked stays where the clock was, frozen and grey — the widget
      // turned into a paragraph of prose without it.
      let stoppedAt = Date(timeIntervalSince1970: TimeInterval(at) / 1000)
      VStack(alignment: .leading, spacing: 1) {
        if frozen {
          Text(
            Duration.seconds(max(0, stoppedAt.timeIntervalSince(clockStart(t))))
              .formatted(.time(pattern: .hourMinuteSecond))
          )
          .font(font).monospacedDigit().foregroundStyle(.secondary)
          .lineLimit(1).minimumScaleFactor(0.6)
        }
        Text(
          WidgetText.fill(
            s.string("widget_stopped_syncs", "Stopped :time · syncs when you open Invoice Ninja"),
            ["time": stoppedAt.formatted(date: .omitted, time: .shortened)])
        )
        .font(.caption2).foregroundStyle(.secondary).lineLimit(frozen ? 3 : 1)
      }
    } else if stale {
      Text(
        WidgetText.fill(
          s.string("widget_running_since", "Running since :time"),
          ["time": t.runningSince.formatted(date: .omitted, time: .shortened)])
      )
      .font(.caption).foregroundStyle(.secondary).lineLimit(2)
    } else {
      Text(timerInterval: clockStart(t)...Date.distantFuture, countsDown: false)
        .font(font).monospacedDigit()
        .lineLimit(1).minimumScaleFactor(0.6)
        .widgetAccentable()
    }
  }

  /// Stop, sized by the caller: `wide` fills the row (small), else a square
  /// of `side`, `labelled` with "Stop" under the glyph when there is room.
  /// Red, like every stop control users know (Clock, Timery), as a glyph on
  /// a quiet fill: a filled tint loses its glyph in iOS 18's tinted mode.
  @ViewBuilder
  private func stopButton(
    _ s: WidgetSnapshot, _ company: WidgetSnapshot.Company, _ t: WidgetSnapshot.Timer,
    wide: Bool = false, side: CGFloat = 44, labelled: Bool = false
  ) -> some View {
    // A teammate's timer gets no Stop: the server would refuse the save.
    if t.canStop, entry.pendingStops[WidgetFiles.stopKey(t.taskId, t.runningSince)] == nil {
      let red = WidgetColor.bad(scheme)
      Button(
        intent: StopTimerIntent(
          taskId: t.taskId, companyId: company.id, userId: s.userId, runningSince: t.runningSince)
      ) {
        Group {
          if wide {
            Label(s.string("stop", "Stop"), systemImage: "stop.fill")
              .font(.footnote.weight(.semibold))
              .frame(maxWidth: .infinity, minHeight: 36)
          } else if labelled {
            VStack(spacing: 3) {
              Image(systemName: "stop.fill").font(.system(size: 18, weight: .semibold))
              Text(s.string("stop", "Stop")).font(.caption.weight(.semibold)).lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(width: side, height: side)
          } else {
            Image(systemName: "stop.fill")
              .font(.system(size: side * 0.38, weight: .semibold))
              .frame(width: side, height: side)
          }
        }
        .foregroundStyle(red)
        .background(red.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .widgetAccentable()
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        WidgetText.fill(s.string("widget_stop_task", "Stop :task"), ["task": t.description]))
    }
  }

  @ViewBuilder
  private func home(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    // Medium holds three one-line rows (34 pt each in a 126 pt box), or two
    // and the "+N running" line once there are more than three.
    let capacity = family == .systemMedium ? (company.runningCount > 3 ? 2 : 3) : 1
    let timers = Array(company.timers.prefix(capacity))
    if timers.isEmpty {
      idle(s, company)
    } else if family == .systemSmall, let t = timers.first {
      // Small: one column, Stop across the bottom — beside the text it left
      // the task name two letters wide.
      VStack(alignment: .leading, spacing: 2) {
        timerText(s, t, clockSize: 26)
        Spacer(minLength: 4)
        stopButton(s, company, t, wide: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if timers.count == 1, let t = timers.first {
      HStack(alignment: .center, spacing: 8) {
        Link(destination: WidgetLink.url(WidgetLink.taskRoute(t.taskId), company: company.id)) {
          VStack(alignment: .leading, spacing: 2) {
            timerText(s, t, clockSize: 32)
            todayLine(s, company)
          }
        }
        Spacer(minLength: 0)
        stopButton(s, company, t, side: 64, labelled: true)
      }
      .frame(maxHeight: .infinity)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(timers, id: \.taskId) { t in
          HStack(alignment: .center, spacing: 8) {
            Link(destination: WidgetLink.url(WidgetLink.taskRoute(t.taskId), company: company.id)) {
              compactRow(s, t)
            }
            stopButton(s, company, t, side: 34)
          }
        }
        let more = company.runningCount - timers.count
        if more > 0 {
          Text(WidgetText.fill(s.string("widget_running_count", "+:count running"), ["count": "\(more)"]))
            .font(.caption2).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func timerText(_ s: WidgetSnapshot, _ t: WidgetSnapshot.Timer, clockSize: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(t.description.isEmpty ? "—" : t.description)
        .font(.footnote.weight(.semibold)).lineLimit(1)
        .privacySensitive()
      if !t.client.isEmpty {
        Text(t.client).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          .privacySensitive()
      }
      clock(s, t, font: .system(size: clockSize, weight: .bold, design: .rounded))
    }
  }

  /// One line of a multi-timer medium: task over client, the clock trailing.
  /// A stopped or stale timer says so in the client's place.
  @ViewBuilder
  private func compactRow(_ s: WidgetSnapshot, _ t: WidgetSnapshot.Timer) -> some View {
    HStack(alignment: .center, spacing: 6) {
      VStack(alignment: .leading, spacing: 1) {
        Text(t.description.isEmpty ? "—" : t.description)
          .font(.footnote.weight(.semibold)).lineLimit(1)
          .privacySensitive()
        if ticking(t) {
          if !t.client.isEmpty {
            Text(t.client).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
              .privacySensitive()
          }
        } else {
          clock(s, t, font: .caption, frozen: false).lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if ticking(t) {
        // A timer Text claims all the width it is offered; pin it.
        clock(s, t, font: .system(size: 17, weight: .bold, design: .rounded))
          .multilineTextAlignment(.trailing)
          .frame(width: 70, alignment: .trailing)
      }
    }
  }

  @ViewBuilder
  private func idle(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        // A new task opens the app: there is nothing to start yet.
        Link(destination: WidgetLink.url("/tasks/new", company: company.id)) {
          // Tinted text on a quiet fill, never white on the tint: iOS 18's
          // tinted mode drops colour, and white-on-tint becomes invisible.
          Label(s.string("widget_start_a_task", "Start a task"), systemImage: "plus")
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 40)
            .foregroundStyle(.tint)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .widgetAccentable()
        }
        if family != .systemSmall, let done = doneToday(company), done > 0 {
          VStack(alignment: .trailing, spacing: 0) {
            Text(s.string("today", "Today")).font(.caption2).foregroundStyle(.secondary)
            Text(Duration.seconds(done).formatted(.time(pattern: .hourMinute)))
              .font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
          }
          .lineLimit(1)
          .accessibilityElement(children: .combine)
        }
      }
      // Recent work, one tap each to start again. The tap queues a start and
      // opens the app on the task, which starts it there — a start can need a
      // booking question only the app can ask, and no URL may write
      // (docs/home-screen-widgets.md § The only write is a queued command).
      ForEach(Array(company.recentTasks.prefix(family == .systemSmall ? 1 : 2)), id: \.taskId) { t in
        if t.taskId.isEmpty || t.taskId.hasPrefix("tmp_") {
          // Not on the server yet: nothing to start; the list explains.
          Link(destination: WidgetLink.url(WidgetLink.taskRoute(t.taskId), company: company.id)) {
            recentRow(t, symbol: "clock.arrow.circlepath")
          }
        } else {
          Button(intent: StartTaskIntent(taskId: t.taskId, companyId: company.id, userId: s.userId)) {
            recentRow(t, symbol: "play.circle.fill")
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            WidgetText.fill(s.string("widget_start_task", "Start :task"), ["task": t.description]))
        }
      }
      Spacer(minLength: 0)
      // The small size has no room beside the button, so today's total is a
      // footer there — what was logged, under what to log next.
      if family == .systemSmall, let done = doneToday(company), done > 0 {
        HStack(spacing: 4) {
          Text(s.string("today", "Today")).foregroundStyle(.secondary)
          Text(Duration.seconds(done).formatted(.time(pattern: .hourMinute))).monospacedDigit()
        }
        .font(.caption2.weight(.medium))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
      }
    }
  }

  private func recentRow(_ t: WidgetSnapshot.Task, symbol: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 20))
        .foregroundStyle(.tint)
        .widgetAccentable()
      VStack(alignment: .leading, spacing: 0) {
        Text(t.description.isEmpty ? "—" : t.description)
          .font(.caption.weight(.medium)).lineLimit(1).privacySensitive()
        // On every size: the client is what tells two tasks apart, and the
        // small size has the room below its one row.
        if !t.client.isEmpty {
          Text(t.client).font(.caption2).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
    .contentShape(Rectangle())
  }

  /// Finished time worked today, or nil when the snapshot is from another
  /// day (the timeline redraws at midnight) or carries none.
  private func doneToday(_ company: WidgetSnapshot.Company) -> Int? {
    guard let today = company.today, today.date == WidgetText.iso(entry.date) else { return nil }
    return today.doneSeconds
  }

  /// "Today · 3:45:10", ticking — for the one-timer medium. Only with exactly
  /// one timer running: two would have to tick at twice the rate.
  @ViewBuilder
  private func todayLine(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
    if company.runningCount == 1, let t = company.timers.first, ticking(t),
      let done = doneToday(company)
    {
      let midnight = Calendar.current.startOfDay(for: entry.date)
      let since = max(t.runningSince, midnight)
      let start = since.addingTimeInterval(-TimeInterval(done))
      HStack(spacing: 4) {
        Text(s.string("today", "Today"))
        Text("·")
        Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    }
  }

  #if os(iOS)
    @ViewBuilder
    private func rectangular(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
      if let t = company.timers.first {
        VStack(alignment: .leading) {
          Text(t.description.isEmpty ? "—" : t.description).font(.headline).lineLimit(1)
            .privacySensitive()
          clock(s, t, font: .system(size: 22, weight: .semibold, design: .rounded), frozen: false)
          if !t.client.isEmpty { Text(t.client).font(.caption).lineLimit(1).privacySensitive() }
        }
      } else {
        Label(s.string("widget_start_a_task", "Start a task"), systemImage: "timer")
      }
    }

    @ViewBuilder
    private func inline(_ s: WidgetSnapshot, _ company: WidgetSnapshot.Company) -> some View {
      if let t = company.timers.first {
        // An SF Symbol, not the ⏱ emoji: the lock screen tints a symbol.
        Label {
          if entry.pendingStops[WidgetFiles.stopKey(t.taskId, t.runningSince)] != nil || stale {
            // Stopped here and waiting for the app, or too old to trust as
            // still running: name it, don't tick — never "Start a task".
            Text(t.description.isEmpty ? t.client : t.description)
          } else {
            // "1:23 · Acme"
            Text("\(Text(timerInterval: clockStart(t)...Date.distantFuture, countsDown: false))\(t.client.isEmpty ? "" : " · \(t.client)")")
          }
        } icon: {
          Image(systemName: "timer")
        }
      } else {
        Label(s.string("widget_start_a_task", "Start a task"), systemImage: "timer")
      }
    }
  #endif
}
