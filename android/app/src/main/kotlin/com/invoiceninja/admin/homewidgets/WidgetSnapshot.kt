package com.invoiceninja.admin.homewidgets

import org.json.JSONArray
import org.json.JSONObject

/**
 * The snapshot the app writes for the widgets — the Kotlin twin of
 * `lib/domain/home_widgets/widget_snapshot.dart`.
 *
 * Lenient by design: every field is optional, and nothing here throws on a
 * missing or mistyped value. A snapshot newer than [VERSION] is read as
 * [tooNew], and the widget asks for an app update instead of guessing.
 * `test/fixtures/home_widgets/` are the shared golden files
 * (`WidgetSnapshotTest`).
 */
data class WidgetSnapshot(
    val version: Int,
    val tooNew: Boolean,
    /** When the app wrote this, epoch ms. */
    val writtenAt: Long,
    val signedIn: Boolean,
    val userId: String,
    val appLock: Boolean,
    val rtl: Boolean,
    val activeCompanyId: String,
    val strings: Map<String, String>,
    val companies: List<Company>,
) {
  data class Money(val text: String, val compact: String)

  data class Figure(val amount: Money, val deltaPct: Int?, val good: Boolean?)

  data class Outstanding(
      val amount: Money,
      val unpaidCount: Int,
      val pastDueCount: Int?,
      val pastDueExact: Boolean,
      val pastDueAmount: Money?,
      /**
       * The past-due part of Outstanding, 0–1 — the bar under it. Sent only
       * with [pastDueAmount] (proven) and a non-zero Outstanding.
       */
      val pastDueShare: Double?,
  )

  data class Period(
      val label: String,
      val name: String,
      val endsOn: String,
      val fetchedAt: Long?,
      val invoices: Figure?,
      val payments: Figure?,
      val expenses: Figure?,
  )

  data class InvoiceRow(
      val id: String,
      val number: String,
      val client: String,
      val amount: Money,
      val lateSince: String?,
      val dueOn: String?,
  )

  data class Attention(
      val pastDue: List<InvoiceRow>,
      val dueSoon: List<InvoiceRow>,
      val nextDue: InvoiceRow?,
  )

  data class Figures(
      val fetchedAt: Long?,
      val outstanding: Outstanding?,
      val periods: Map<String, Period>,
      val attention: Attention?,
      val inCurrency: String,
  )

  data class Timer(
      val taskId: String,
      val description: String,
      val client: String,
      val runningSince: Long,
      val priorSeconds: Long,
      val canStop: Boolean,
  )

  data class Task(val taskId: String, val description: String, val client: String)

  /**
   * Time the user logged on [date] (`yyyy-MM-dd`, the device's day when the
   * app wrote it), from completed entries only: the widget adds a running
   * timer's share itself, so the figure ticks. Stale once [date] isn't today.
   */
  data class Today(val date: String, val doneSeconds: Long)

  data class Company(
      val id: String,
      val name: String,
      val accent: String,
      val canViewDashboard: Boolean,
      val figures: Figures?,
      val timers: List<Timer>,
      /**
       * All of the user's running timers. [timers] holds at most three, so
       * "+N running" counts from this; an older snapshot without it counts
       * [timers].
       */
      val runningCount: Int,
      val recentTasks: List<Task>,
      /** Sent only with the Timer widget's task rows. */
      val today: Today?,
  )

  /** The company a widget set to [companyId] shows; "" means the active one. */
  fun company(companyId: String): Company? {
    val id = companyId.ifEmpty { activeCompanyId }
    return companies.firstOrNull { it.id == id }
  }

  /** [key] in the app's language, else [fallback] (the bundled English). */
  fun string(key: String, fallback: String): String =
      strings[key]?.takeIf { it.isNotBlank() } ?: fallback

  companion object {
    /** The newest snapshot version this widget understands. */
    const val VERSION = 1

    fun parse(json: JSONObject): WidgetSnapshot {
      val version = json.optInt("v", 0)
      val strings = mutableMapOf<String, String>()
      json.optJSONObject("strings")?.let { s ->
        for (key in s.keys()) {
          val v = s.opt(key)
          if (v is String) strings[key] = v
        }
      }
      return WidgetSnapshot(
          version = version,
          tooNew = version > VERSION,
          writtenAt = json.optLong("writtenAt", 0),
          signedIn = json.optBoolean("signedIn", false),
          userId = json.optString("userId", ""),
          appLock = json.optBoolean("appLock", false),
          rtl = json.optBoolean("rtl", false),
          activeCompanyId = json.optString("activeCompanyId", ""),
          strings = strings,
          companies = json.optJSONArray("companies").objects().map(::company),
      )
    }

    private fun company(c: JSONObject): Company {
      val timers =
          c.optJSONArray("timers").objects().mapNotNull { t ->
            val since = t.optLongOrNull("runningSince") ?: return@mapNotNull null
            Timer(
                taskId = t.optString("taskId", ""),
                description = t.optString("description", ""),
                client = t.optString("client", ""),
                runningSince = since,
                priorSeconds = t.optLong("priorSeconds", 0),
                canStop = t.optBoolean("canStop", false),
            )
          }
      return Company(
          id = c.optString("id", ""),
          name = c.optString("name", ""),
          accent = c.optString("accent", ""),
          canViewDashboard = c.optBoolean("canViewDashboard", false),
          figures = c.optJSONObject("figures")?.let(::figures),
          timers = timers,
          // Never fewer than the rows it carries: a count below them would
          // make "+N running" negative.
          runningCount = c.optInt("runningCount", timers.size).coerceAtLeast(timers.size),
          recentTasks =
              c.optJSONArray("recentTasks").objects().map { t ->
                Task(
                    taskId = t.optString("taskId", ""),
                    description = t.optString("description", ""),
                    client = t.optString("client", ""),
                )
              },
          today =
              c.optJSONObject("today")?.let { t ->
                val date = t.optString("date", "")
                if (date.isEmpty()) null
                else Today(date = date, doneSeconds = t.optLong("doneSeconds", 0).coerceAtLeast(0))
              },
      )
    }

    private fun figures(f: JSONObject): Figures {
      val periods = mutableMapOf<String, Period>()
      f.optJSONObject("periods")?.let { p ->
        for (key in p.keys()) {
          val v = p.optJSONObject(key) ?: continue
          periods[key] =
              Period(
                  label = v.optString("label", ""),
                  name = v.optString("name", ""),
                  endsOn = v.optString("endsOn", ""),
                  fetchedAt = v.optLongOrNull("fetchedAt"),
                  invoices = v.optJSONObject("invoices")?.let(::figure),
                  payments = v.optJSONObject("payments")?.let(::figure),
                  expenses = v.optJSONObject("expenses")?.let(::figure),
              )
        }
      }
      return Figures(
          fetchedAt = f.optLongOrNull("fetchedAt"),
          outstanding =
              f.optJSONObject("outstanding")?.let { o ->
                val amount = o.optJSONObject("amount")?.let(::money) ?: return@let null
                Outstanding(
                    amount = amount,
                    unpaidCount = o.optInt("unpaidCount", 0),
                    pastDueCount = if (o.has("pastDueCount")) o.optInt("pastDueCount") else null,
                    pastDueExact = o.optBoolean("pastDueExact", true),
                    pastDueAmount = o.optJSONObject("pastDueAmount")?.let(::money),
                    pastDueShare =
                        o.optDouble("pastDueShare", Double.NaN)
                            .takeIf { !it.isNaN() }
                            ?.coerceIn(0.0, 1.0),
                )
              },
          periods = periods,
          attention =
              f.optJSONObject("attention")?.let { a ->
                Attention(
                    pastDue = a.optJSONArray("pastDue").objects().mapNotNull(::invoiceRow),
                    dueSoon = a.optJSONArray("dueSoon").objects().mapNotNull(::invoiceRow),
                    nextDue = a.optJSONObject("nextDue")?.let(::invoiceRow),
                )
              },
          inCurrency = f.optString("inCurrency", ""),
      )
    }

    private fun figure(f: JSONObject) =
        Figure(
            amount = money(f),
            deltaPct = if (f.has("deltaPct")) f.optInt("deltaPct") else null,
            good = if (f.has("good")) f.optBoolean("good") else null,
        )

    private fun money(m: JSONObject): Money {
      val text = m.optString("text", "")
      return Money(text = text, compact = m.optString("compact", "").ifEmpty { text })
    }

    private fun invoiceRow(r: JSONObject): InvoiceRow? {
      val id = r.optString("id", "")
      if (id.isEmpty()) return null
      return InvoiceRow(
          id = id,
          number = r.optString("number", ""),
          client = r.optString("client", ""),
          amount = r.optJSONObject("amount")?.let(::money) ?: Money("", ""),
          lateSince = r.optStringOrNull("lateSince"),
          dueOn = r.optStringOrNull("dueOn"),
      )
    }

    private fun JSONArray?.objects(): List<JSONObject> =
        if (this == null) emptyList() else (0 until length()).mapNotNull { optJSONObject(it) }

    private fun JSONObject.optLongOrNull(key: String): Long? =
        if (has(key) && !isNull(key)) optLong(key) else null

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (has(key) && !isNull(key)) optString(key).takeIf { it.isNotEmpty() } else null
  }
}
