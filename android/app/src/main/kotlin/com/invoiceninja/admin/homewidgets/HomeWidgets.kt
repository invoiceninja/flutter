package com.invoiceninja.admin.homewidgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.format.DateUtils
import com.invoiceninja.admin.DeepLinkReceiverActivity
import java.util.Calendar
import java.util.concurrent.Executors

/** What every provider shares: kinds, updates, links, the rollover alarm, text helpers. */
object HomeWidgets {
  const val KIND_SNAPSHOT = "snapshot"
  const val KIND_ATTENTION = "attention"
  const val KIND_TIMER = "timer"

  /** Figures this old (or from a period that has ended) are flagged "Tap to refresh". */
  const val STALE_AFTER_MS = 72L * 60 * 60 * 1000

  /**
   * A running timer from a snapshot this old shows "Running since 9:14", not a
   * clock: it may well have been stopped on another device since.
   */
  const val TIMER_STALE_AFTER_MS = 12L * 60 * 60 * 1000

  private fun providerFor(kind: String): Class<*>? =
      when (kind) {
        KIND_SNAPSHOT -> SnapshotWidgetProvider::class.java
        KIND_ATTENTION -> AttentionWidgetProvider::class.java
        KIND_TIMER -> TimerWidgetProvider::class.java
        else -> null
      }

  private val ALL = listOf(KIND_SNAPSHOT, KIND_ATTENTION, KIND_TIMER)

  fun ids(context: Context, kind: String): IntArray {
    val provider = providerFor(kind) ?: return IntArray(0)
    return AppWidgetManager.getInstance(context)
        .getAppWidgetIds(ComponentName(context, provider))
  }

  /**
   * The one thread every widget read, write and redraw runs on — the channel's
   * file work, the providers, the Stop receiver, the rollover alarm. In order,
   * so a redraw holding the old snapshot can never land after a sign-out's
   * stub; off the main thread, so a parse never costs a frame.
   */
  val worker = Executors.newSingleThreadExecutor()

  /**
   * Redraws [kinds] on [worker] — for a provider or receiver, whose
   * `goAsync()` is finished in [done].
   */
  fun updateAsync(context: Context, kinds: Set<String>?, done: () -> Unit) {
    val app = context.applicationContext
    worker.execute {
      try {
        update(app, kinds)
      } catch (e: Throwable) {
        // Never let a widget take the app down: an exception escaping an
        // executor task reaches the default handler, which kills the process
        // — a foreground Flutter app included.
        android.util.Log.w("HomeWidgets", "Widget redraw failed", e)
      } finally {
        done()
      }
    }
  }

  /** Redraws the widgets of [kinds] (every kind when null). Call on [worker]. */
  fun update(context: Context, kinds: Set<String>? = null) {
    val manager = AppWidgetManager.getInstance(context)
    for (kind in kinds ?: ALL.toSet()) {
      val ids = ids(context, kind)
      if (ids.isEmpty()) continue
      when (kind) {
        KIND_SNAPSHOT -> SnapshotWidgetProvider.render(context, manager, ids)
        KIND_ATTENTION -> AttentionWidgetProvider.render(context, manager, ids)
        KIND_TIMER -> TimerWidgetProvider.render(context, manager, ids)
      }
    }
    scheduleRollover(context)
  }

  /**
   * Asks the launcher to place a [kind] widget (Device Settings → Home-screen
   * widgets). False where it can't: before Android 8, or a launcher that
   * doesn't take requests — the user adds it from the home screen then.
   */
  fun pin(context: Context, kind: String): Boolean {
    if (android.os.Build.VERSION.SDK_INT < 26) return false
    val provider = providerFor(kind) ?: return false
    val manager = AppWidgetManager.getInstance(context)
    if (!manager.isRequestPinAppWidgetSupported) return false
    return manager.requestPinAppWidget(ComponentName(context, provider), null, null)
  }

  /** What `HomeWidgetBridge.installed()` reads: the kinds placed, and their settings. */
  fun installed(context: Context): Map<String, List<String>> {
    val kinds = mutableListOf<String>()
    val companies = mutableSetOf<String>()
    val periods = mutableSetOf<String>()
    for (kind in ALL) {
      val ids = ids(context, kind)
      if (ids.isEmpty()) continue
      kinds.add(kind)
      for (id in ids) {
        val s = WidgetSettings.load(context, id)
        if (s.companyId.isNotEmpty()) companies.add(s.companyId)
        if (kind == KIND_SNAPSHOT) periods.add(s.period)
      }
    }
    return mapOf(
        "kinds" to kinds,
        "companyIds" to companies.toList(),
        "periods" to periods.toList(),
    )
  }

  /**
   * A tap: `invoiceninja://app/<route>?company=<id>`, started on the
   * engine-free trampoline — never MainActivity (docs/deep-links.md). Each
   * [requestCode] must be distinct per widget and region, or Android hands back
   * one PendingIntent for all of them.
   */
  fun link(context: Context, route: String, companyId: String, requestCode: Int): PendingIntent {
    // [route] may carry a list filter: "/invoices?filter=past_due".
    val path = route.substringBefore('?')
    val filter = route.substringAfter('?', "").removePrefix("filter=")
    val uri =
        Uri.Builder()
            .scheme("invoiceninja")
            .authority("app")
            .path(path)
            .apply {
              if (filter.isNotEmpty()) appendQueryParameter("filter", filter)
              if (companyId.isNotEmpty()) appendQueryParameter("company", companyId)
            }
            .build()
    val intent =
        Intent(context, DeepLinkReceiverActivity::class.java).apply {
          action = Intent.ACTION_VIEW
          data = uri
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    return PendingIntent.getActivity(
        context,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  /** Opens the app on whatever it last showed (no route). */
  fun openApp(context: Context, requestCode: Int): PendingIntent {
    val intent =
        Intent(context, DeepLinkReceiverActivity::class.java).apply {
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    return PendingIntent.getActivity(
        context,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  /** Opens this widget's configuration again. */
  fun configure(context: Context, appWidgetId: Int): PendingIntent {
    val intent =
        Intent(context, WidgetConfigureActivity::class.java).apply {
          putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    return PendingIntent.getActivity(
        context,
        appWidgetId * 100 + 99,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  /**
   * Redraws at the next moment a widget's text changes on its own — local
   * midnight ("12 days late", a period ending) or a stale threshold. Inexact:
   * a few minutes late is fine, and it needs no exact-alarm permission. No
   * `updatePeriodMillis` polling.
   */
  private fun scheduleRollover(context: Context) {
    val alarm = context.getSystemService(AlarmManager::class.java) ?: return
    val intent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, WidgetRolloverReceiver::class.java).setAction(
                WidgetRolloverReceiver.ACTION_ROLLOVER,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    // No widget placed: no alarm — else every install wakes at midnight to
    // draw nothing.
    if (ALL.all { ids(context, it).isEmpty() }) {
      alarm.cancel(intent)
      return
    }
    val midnight =
        Calendar.getInstance()
            .apply {
              add(Calendar.DAY_OF_YEAR, 1)
              set(Calendar.HOUR_OF_DAY, 0)
              set(Calendar.MINUTE, 1)
              set(Calendar.SECOND, 0)
              set(Calendar.MILLISECOND, 0)
            }
            .timeInMillis
    val snapshot = WidgetStore.readSnapshot(context)
    val writtenAt = snapshot?.writtenAt ?: 0L
    val now = System.currentTimeMillis()
    val thresholds =
        snapshot
            ?.companies
            .orEmpty()
            .flatMap { c ->
              listOfNotNull(
                  c.figures?.fetchedAt?.plus(STALE_AFTER_MS),
                  if (c.timers.isEmpty()) null else writtenAt + TIMER_STALE_AFTER_MS,
              )
            }
            .filter { it > now }
    val next = (thresholds + midnight).min()
    // A window, not `set`: before Android 12 an inexact alarm may slip by up
    // to three quarters of its delay — set at 9:00 for midnight, it could fire
    // mid-morning, with "due today" wrong until then. A 15-minute window needs
    // no exact-alarm permission.
    alarm.setWindow(AlarmManager.RTC, next, 15 * 60_000L, intent)
  }

  /**
   * Sets a text colour that follows a light/dark (and, on Android 12+, a
   * wallpaper) change by itself. `setTextColor(getColor(…))` would freeze the
   * colour resolved at render time until the next redraw.
   */
  fun textColor(context: Context, views: android.widget.RemoteViews, viewId: Int, colorRes: Int) {
    if (android.os.Build.VERSION.SDK_INT >= 31) {
      views.setColorStateList(viewId, "setTextColor", colorRes)
    } else {
      views.setTextColor(viewId, context.getColor(colorRes))
    }
  }

  // ─── Text ────────────────────────────────────────────────────────────────

  /** Fills `:name` placeholders, longest name first (as `Localization.lookup`). */
  fun fill(template: String, params: Map<String, String>): String {
    var out = template
    for ((k, v) in params.entries.sortedByDescending { it.key.length }) {
      out = out.replace(":$k", v)
    }
    return out
  }

  // Day arithmetic on plain day numbers: `java.time` needs API 26 (minSdk is
  // 24) and desugaring would add a dependency for three subtractions.

  /** Days since 1970-01-01 for a civil date (Howard Hinnant's days_from_civil). */
  internal fun epochDay(year: Int, month: Int, day: Int): Long {
    val y = (if (month <= 2) year - 1 else year).toLong()
    val era = Math.floorDiv(y, 400L)
    val yoe = y - era * 400
    val mp = (month + 9) % 12
    val doy = (153 * mp + 2) / 5 + day - 1
    val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
  }

  /** `yyyy-MM-dd` (anything after ignored) as a day number, or null. */
  internal fun parseDate(iso: String?): Long? {
    val m = Regex("^(\\d{4})-(\\d{2})-(\\d{2})").find(iso ?: return null) ?: return null
    val (y, mo, d) = m.destructured
    val month = mo.toInt()
    val day = d.toInt()
    if (month !in 1..12 || day !in 1..31) return null
    return epochDay(y.toInt(), month, day)
  }

  /** Today, in the device's time zone, as a day number. */
  internal fun today(): Long {
    val c = Calendar.getInstance()
    return epochDay(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
  }

  /** "12 days late", or null for a row that isn't late. Worked out today, not when written. */
  fun daysLate(snapshot: WidgetSnapshot, lateSince: String?, context: Context): String? {
    val since = parseDate(lateSince) ?: return null
    val days = (today() - since).coerceAtLeast(1)
    val key = if (days == 1L) "days_late_count_singular" else "days_late_count_plural"
    val fallback =
        context.getString(
            if (days == 1L) com.invoiceninja.admin.R.string.widget_day_late
            else com.invoiceninja.admin.R.string.widget_days_late,
        )
    return fill(snapshot.string(key, fallback), mapOf("count" to "$days"))
  }

  /** "due today" / "due in 3 days". */
  fun dueIn(snapshot: WidgetSnapshot, dueOn: String?, context: Context): String? {
    val due = parseDate(dueOn) ?: return null
    val days = due - today()
    if (days <= 0) {
      return snapshot.string(
          "widget_due_today",
          context.getString(com.invoiceninja.admin.R.string.widget_due_today),
      )
    }
    return fill(
        snapshot.string(
            "widget_due_in_days",
            context.getString(com.invoiceninja.admin.R.string.widget_due_in_days),
        ),
        mapOf("count" to "$days"),
    )
  }

  /**
   * "Updated 9:41" today, "Updated Oct 30" before — absolute, never "2 min
   * ago": a widget redraws only on a new snapshot or a threshold, and a
   * relative stamp frozen at render time would claim freshness for hours.
   * The same rule as iOS (`updatedStamp`).
   */
  fun updated(snapshot: WidgetSnapshot, at: Long, context: Context): String {
    val label = snapshot.string("updated", context.getString(com.invoiceninja.admin.R.string.widget_updated))
    val stamp =
        if (DateUtils.isToday(at)) {
          android.text.format.DateFormat.getTimeFormat(context).format(java.util.Date(at))
        } else {
          DateUtils.formatDateTime(
              context,
              at,
              DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_NO_YEAR,
          )
        }
    return "$label $stamp"
  }

  /**
   * The route for a task: its record, or the tasks list for one still on a
   * local `tmp_` id (created offline, not yet synced) — a link can't name a
   * record the server doesn't have, and DeepLinkRouter refuses it.
   */
  fun taskRoute(taskId: String): String =
      if (taskId.startsWith("tmp_") || taskId.isEmpty()) "/tasks" else "/tasks/$taskId"

  /**
   * A stopped timer's total, "1:02:05" — always H:MM:SS, in the locale's
   * digits. Never negative: a stop stamped before the snapshot's start (a
   * clock change) reads 0:00:00, not "-1:59:59".
   */
  fun elapsedText(seconds: Long, locale: java.util.Locale = java.util.Locale.getDefault()): String {
    val s = seconds.coerceAtLeast(0)
    return String.format(locale, "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
  }

  /** Today's logged time, "3:05" — H:MM, in the locale's digits. */
  fun hoursMinutes(seconds: Long, locale: java.util.Locale = java.util.Locale.getDefault()): String {
    val s = seconds.coerceAtLeast(0)
    return String.format(locale, "%d:%02d", s / 3600, s / 60 % 60)
  }

  /** The start of today in the device's time zone, epoch ms — where today's total begins. */
  fun localMidnight(): Long =
      Calendar.getInstance()
          .apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
          }
          .timeInMillis

  /** A glyph beside past-due text — the colour alone can't carry it. */
  const val PAST_DUE_GLYPH = "⚠\uFE0E "

  /**
   * The footer's warning once figures are stale: "Open <Company> to update"
   * for a pinned company that isn't the app's active one (opening the app
   * doesn't refresh it), "Tap to refresh" otherwise. As iOS `WidgetFooter`.
   */
  fun staleHint(snapshot: WidgetSnapshot, company: WidgetSnapshot.Company, context: Context): String =
      if (company.id != snapshot.activeCompanyId) {
        fill(
            snapshot.string(
                "widget_open_company_to_update",
                context.getString(com.invoiceninja.admin.R.string.widget_open_company_to_update),
            ),
            mapOf("company" to company.name),
        )
      } else {
        snapshot.string(
            "widget_tap_to_refresh",
            context.getString(com.invoiceninja.admin.R.string.widget_tap_to_refresh),
        )
      }

  /** Whether a period's figures are for a period that has ended since. */
  fun periodEnded(endsOn: String): Boolean {
    val end = parseDate(endsOn) ?: return false
    return today() > end
  }
}
