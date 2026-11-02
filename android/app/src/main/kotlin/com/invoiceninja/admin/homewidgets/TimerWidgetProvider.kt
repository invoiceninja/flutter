package com.invoiceninja.admin.homewidgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.SystemClock
import android.text.format.DateFormat
import android.widget.RemoteViews
import com.invoiceninja.admin.R
import java.util.Date

/**
 * Running timer: up to three running tasks, each with a live clock and a
 * one-tap Stop (and, for a lone timer, today's total ticking under it); idle,
 * "Start a task", the two most recently worked tasks — each a one-tap Start —
 * and what was logged today.
 *
 * The clock is a `Chronometer`, ticking on the launcher with no updates from
 * us. Its base is in `elapsedRealtime` time, which restarts at boot — so it is
 * recomputed from `runningSince` (wall clock) on every render, never stored.
 */
class TimerWidgetProvider : BaseWidgetProvider() {
  override val kind = HomeWidgets.KIND_TIMER

  /**
   * How a running row is drawn, tallest first: everything; the "Stopped …
   * syncs" line cut to one line; or compact — the title and one value line,
   * no client — for a widget too short for anything more (it is allowed down
   * to 60dp, one launcher row).
   */
  internal enum class Fit { FULL, SHORT_STATUS, COMPACT }

  internal data class Plan(val rows: List<Fit>, val more: Boolean, val needDp: Float)

  companion object {
    private val ROWS =
        listOf(
            Row(R.id.timer1, R.id.timer1_title, R.id.timer1_client, R.id.timer1_clock, R.id.timer1_frozen, R.id.timer1_status, R.id.timer1_stop),
            Row(R.id.timer2, R.id.timer2_title, R.id.timer2_client, R.id.timer2_clock, R.id.timer2_frozen, R.id.timer2_status, R.id.timer2_stop),
            Row(R.id.timer3, R.id.timer3_title, R.id.timer3_client, R.id.timer3_clock, R.id.timer3_frozen, R.id.timer3_status, R.id.timer3_stop),
        )

    private data class Row(
        val root: Int,
        val title: Int,
        val client: Int,
        val clock: Int,
        val frozen: Int,
        val status: Int,
        val stop: Int,
    )

    private data class Recent(val root: Int, val glyph: Int, val title: Int, val client: Int)

    private val RECENT =
        listOf(
            Recent(R.id.recent1, R.id.recent1_glyph, R.id.recent1_title, R.id.recent1_client),
            Recent(R.id.recent2, R.id.recent2_glyph, R.id.recent2_title, R.id.recent2_client),
        )

    /**
     * The running rows that fit [roomDp], the content height at the usual
     * padding. [heights] holds each timer's row height per [Fit], in order;
     * [gap] is the space between rows. The first row is always drawn — in
     * its compact form when even its shortest full form doesn't fit, with
     * the padding squeezed to make room ([fitPadding]) — later rows only in
     * a full form that fits. "+N running" counts every running timer the
     * widget isn't showing ([runningCount] is all of them; the snapshot
     * carries at most three), and gets its line only when that fits too.
     */
    internal fun plan(
        heights: List<FloatArray>,
        runningCount: Int,
        gap: Float,
        moreDp: Float,
        roomDp: Float,
    ): Plan {
      val rows = mutableListOf<Fit>()
      var used = 0f
      for ((i, h) in heights.take(ROWS_MAX).withIndex()) {
        val g = if (i == 0) 0f else gap
        val fullForms = listOf(Fit.FULL, Fit.SHORT_STATUS)
        val pick =
            fullForms.firstOrNull { used + g + h[it.ordinal] <= roomDp }
                ?: if (i == 0) Fit.COMPACT else break
        rows += pick
        used += g + h[pick.ordinal]
      }
      // A timer the widget doesn't show must at least be counted: when the
      // "+N running" line doesn't fit, the last row gives up its client line
      // (goes compact) to make room — at the default 2×2 size, a second
      // running timer was otherwise invisible.
      val hidden = runningCount - rows.size > 0
      if (hidden && rows.isNotEmpty() && used + moreDp > roomDp) {
        val last = rows.lastIndex
        val h = heights[last]
        val saved = h[rows[last].ordinal] - h[Fit.COMPACT.ordinal]
        if (used - saved + moreDp <= roomDp) {
          rows[last] = Fit.COMPACT
          used -= saved
        }
      }
      val more = hidden && used + moreDp <= roomDp
      if (more) used += moreDp
      return Plan(rows, more, used)
    }

    private const val ROWS_MAX = 3

    fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
      val snapshot = WidgetStore.readSnapshot(context)
      val pending = WidgetStore.pendingStops(context)
      for (id in ids) {
        val settings = WidgetSettings.load(context, id)
        val views =
            message(context, snapshot, settings, id, needsFigures = false)
                ?: build(context, manager, snapshot!!, settings, id, pending)
        manager.updateAppWidget(id, views)
      }
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        snapshot: WidgetSnapshot,
        settings: WidgetSettings,
        id: Int,
        pending: Map<String, Long>,
    ): RemoteViews {
      val company = snapshot.company(settings.companyId)!!
      val views = RemoteViews(context.packageName, R.layout.widget_timer)
      applyDirection(views, snapshot)
      val (width, height) = sizeDp(context, manager, id)
      val pad = paddingDp(context)
      val room = height - 2 * pad
      val timers = company.timers
      val stale = System.currentTimeMillis() - snapshot.writtenAt > HomeWidgets.TIMER_STALE_AFTER_MS
      val timeFormat = DateFormat.getTimeFormat(context)

      val titleDp = lineDp(context, 13f)
      val smallDp = lineDp(context, 12f)
      val clockDp = lineDp(context, 20f, fontPadding = false, typeface = Typeface.DEFAULT_BOLD)
      // The row is as tall as its text column (4dp padding top and bottom),
      // never under the 48dp Stop.
      fun rowDp(column: Float) = maxOf(48f, 8 + column)
      // The text column sits between the row's 10dp start padding and the
      // 48dp Stop with its 4dp margin.
      val statusWidth = width - 2 * pad - 10 - 52

      fun stopStatus(stoppedAt: Long) =
          HomeWidgets.fill(
              snapshot.string("widget_stopped_syncs", context.getString(R.string.widget_stopped_syncs)),
              mapOf("time" to timeFormat.format(Date(stoppedAt))),
          )

      val shownTimers = timers.take(ROWS_MAX)
      val heights =
          shownTimers.map { timer ->
            val client = if (timer.client.isNotEmpty()) smallDp else 0f
            val stoppedAt = pending[WidgetStore.stopKey(timer.taskId, timer.runningSince)]
            when {
              stoppedAt != null -> {
                val lines = lineCount(context, stopStatus(stoppedAt), 12f, statusWidth).coerceIn(1, 2)
                floatArrayOf(
                    rowDp(titleDp + client + clockDp + lines * smallDp),
                    rowDp(titleDp + client + clockDp + smallDp),
                    rowDp(titleDp + smallDp),
                )
              }
              stale ->
                  floatArrayOf(
                      rowDp(titleDp + client + smallDp),
                      rowDp(titleDp + client + smallDp),
                      rowDp(titleDp + smallDp),
                  )
              else ->
                  floatArrayOf(
                      rowDp(titleDp + client + clockDp),
                      rowDp(titleDp + client + clockDp),
                      rowDp(titleDp + clockDp),
                  )
            }
          }
      val plan = plan(heights, company.runningCount, gap = 4f, moreDp = 4 + smallDp, roomDp = room)

      // Today's total, under the clock: only with exactly one timer running
      // and ticking (a stopped or stale one has no live share to add), and
      // only where the row's full form has room for one more line.
      val today = company.today?.takeIf { HomeWidgets.parseDate(it.date) == HomeWidgets.today() }
      val todayLabel = snapshot.string("today", "Today")
      val single = shownTimers.singleOrNull()
      val singleRunning =
          single != null &&
              company.runningCount == 1 &&
              !stale &&
              pending[WidgetStore.stopKey(single.taskId, single.runningSince)] == null
      var need = plan.needDp
      val todayRow =
          if (today != null && singleRunning && plan.rows.singleOrNull() == Fit.FULL) {
            val client = if (single!!.client.isNotEmpty()) smallDp else 0f
            val grown = rowDp(titleDp + client + clockDp + 2 + smallDp)
            (need - heights[0][Fit.FULL.ordinal] + grown).takeIf { it <= room }
          } else null
      show(views, R.id.timer1_today, todayRow != null)
      if (todayRow != null && today != null && single != null) {
        need = todayRow
        val now = System.currentTimeMillis()
        val runningShare = now - maxOf(single.runningSince, HomeWidgets.localMidnight())
        val totalMs = today.doneSeconds * 1000 + runningShare.coerceAtLeast(0)
        // The Chronometer's format is a format string: a `%` in a
        // translation would be read as a conversion.
        views.setChronometer(
            R.id.timer1_today,
            SystemClock.elapsedRealtime() - totalMs,
            "${todayLabel.replace("%", "%%")} · %s",
            true,
        )
      }

      ROWS.forEachIndexed { i, slot ->
        val timer = shownTimers.getOrNull(i)
        val fit = plan.rows.getOrNull(i)
        show(views, slot.root, timer != null && fit != null)
        if (timer == null || fit == null) return@forEachIndexed
        val compact = fit == Fit.COMPACT
        views.setTextViewText(slot.title, timer.description.ifEmpty { "—" })
        views.setTextViewText(slot.client, timer.client)
        show(views, slot.client, timer.client.isNotEmpty() && !compact)
        views.setOnClickPendingIntent(
            slot.root,
            HomeWidgets.link(context, HomeWidgets.taskRoute(timer.taskId), company.id, id * 100 + 10 + i),
        )

        val stoppedAt = pending[WidgetStore.stopKey(timer.taskId, timer.runningSince)]
        when {
          // Stopped from this widget; the app has not run since to apply it.
          // The time it reached stays where the clock was, muted and still,
          // with the "syncs when you open" line under it.
          stoppedAt != null -> {
            show(views, slot.clock, false)
            show(views, slot.stop, false)
            show(views, slot.frozen, !compact)
            views.setTextViewText(
                slot.frozen,
                HomeWidgets.elapsedText(
                    (stoppedAt - (timer.runningSince - timer.priorSeconds * 1000)) / 1000,
                ),
            )
            show(views, slot.status, true)
            views.setInt(slot.status, "setMaxLines", if (fit == Fit.FULL) 2 else 1)
            views.setTextViewText(slot.status, stopStatus(stoppedAt))
          }
          // Too old to trust as still running: say since when, don't tick.
          stale -> {
            show(views, slot.clock, false)
            show(views, slot.frozen, false)
            show(views, slot.status, true)
            views.setInt(slot.status, "setMaxLines", 1)
            views.setTextViewText(
                slot.status,
                HomeWidgets.fill(
                    snapshot.string(
                        "widget_running_since",
                        context.getString(R.string.widget_running_since),
                    ),
                    mapOf("time" to timeFormat.format(Date(timer.runningSince))),
                ),
            )
            showStop(context, views, slot, timer, company, snapshot, id, i)
          }
          else -> {
            show(views, slot.status, false)
            show(views, slot.frozen, false)
            show(views, slot.clock, true)
            val elapsed = System.currentTimeMillis() - timer.runningSince
            val base = SystemClock.elapsedRealtime() - elapsed - timer.priorSeconds * 1000
            views.setChronometer(slot.clock, base, null, true)
            showStop(context, views, slot, timer, company, snapshot, id, i)
          }
        }
      }

      // Every running timer not drawn, not just the capped list's remainder:
      // the snapshot carries three, and a fourth was invisible.
      show(views, R.id.more, plan.more)
      if (plan.more) {
        views.setTextViewText(
            R.id.more,
            HomeWidgets.fill(
                snapshot.string(
                    "widget_running_count",
                    context.getString(R.string.widget_running_count),
                ),
                mapOf("count" to "${company.runningCount - plan.rows.size}"),
            ),
        )
      }

      // Idle: start something new, or start something recent again.
      val idle = timers.isEmpty()
      show(views, R.id.idle, idle)
      if (idle) {
        views.setTextViewText(
            R.id.start,
            snapshot.string("widget_start_a_task", context.getString(R.string.widget_start_a_task)),
        )
        views.setOnClickPendingIntent(
            R.id.start,
            HomeWidgets.link(context, "/tasks/new", company.id, id * 100 + 1),
        )
        need = maxOf(44f, lineDp(context, 14f, typeface = Typeface.DEFAULT_BOLD))
        RECENT.forEachIndexed { i, slot ->
          val task = company.recentTasks.getOrNull(i)
          val title = task?.description?.ifEmpty { task.client }.orEmpty()
          val client = if (task != null && task.description.isNotEmpty()) task.client else ""
          val rowDp = 4 + maxOf(44f, 8 + titleDp + (if (client.isNotEmpty()) smallDp else 0f))
          // The first recent task may squeeze the padding ([fitPadding]) to
          // fit: at 110dp — a 2×2 widget's landscape height on many phones —
          // the Start button leaves no room for a row otherwise, and the
          // one-tap Start is what the idle widget is for.
          val limit = if (i == 0) height - 8f else room
          val fits = task != null && need + rowDp <= limit
          show(views, slot.root, fits)
          if (!fits || task == null) return@forEachIndexed
          need += rowDp
          views.setTextViewText(slot.title, title.ifEmpty { "—" })
          views.setTextViewText(slot.client, client)
          show(views, slot.client, client.isNotEmpty())
          // A task on a local `tmp_` id can't be named in a command the app
          // resolves on the server: that row opens the task list, under the
          // history mark, as before. Every other row starts its task.
          val startable = !task.taskId.startsWith("tmp_") && task.taskId.isNotEmpty()
          views.setImageViewResource(
              slot.glyph,
              if (startable) R.drawable.widget_play else R.drawable.widget_history,
          )
          if (startable) {
            views.setContentDescription(
                slot.root,
                HomeWidgets.fill(
                    snapshot.string("widget_start_task", "Start :task"),
                    mapOf("task" to title),
                ),
            )
            views.setOnClickPendingIntent(slot.root, startIntent(context, snapshot, company, task, id, i))
          } else {
            views.setContentDescription(slot.root, null)
            views.setOnClickPendingIntent(
                slot.root,
                HomeWidgets.link(context, HomeWidgets.taskRoute(task.taskId), company.id, id * 100 + 20 + i),
            )
          }
        }
        // What was logged today, last: the Start button and the recent
        // tasks are what the idle widget is for.
        val idleToday =
            today?.takeIf { it.doneSeconds > 0 && need + 6 + smallDp <= room }
        show(views, R.id.today_idle, idleToday != null)
        if (idleToday != null) {
          need += 6 + smallDp
          views.setTextViewText(
              R.id.today_idle,
              "$todayLabel · ${HomeWidgets.hoursMinutes(idleToday.doneSeconds)}",
          )
        }
      }
      fitPadding(context, views, height, need)
      // The widget's background opens the tasks list, as on iOS.
      views.setOnClickPendingIntent(
          android.R.id.background,
          HomeWidgets.link(context, "/tasks", company.id, id * 100 + 2),
      )
      return views
    }

    /**
     * A recent row's tap: [WidgetStartActivity], which queues the Start and
     * opens the app. An activity PendingIntent, so the app may come forward;
     * its own request code per widget and row.
     */
    private fun startIntent(
        context: Context,
        snapshot: WidgetSnapshot,
        company: WidgetSnapshot.Company,
        task: WidgetSnapshot.Task,
        id: Int,
        index: Int,
    ): PendingIntent {
      val intent =
          Intent(context, WidgetStartActivity::class.java).apply {
            putExtra(WidgetStartActivity.EXTRA_TASK, task.taskId)
            putExtra(WidgetStartActivity.EXTRA_COMPANY, company.id)
            putExtra(WidgetStartActivity.EXTRA_USER, snapshot.userId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          }
      return PendingIntent.getActivity(
          context,
          id * 100 + 60 + index,
          intent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }

    private fun showStop(
        context: Context,
        views: RemoteViews,
        slot: Row,
        timer: WidgetSnapshot.Timer,
        company: WidgetSnapshot.Company,
        snapshot: WidgetSnapshot,
        id: Int,
        index: Int,
    ) {
      // A teammate's timer: the server would refuse the save.
      show(views, slot.stop, timer.canStop)
      if (!timer.canStop) return
      // A glyph with no label, so the description is all a screen reader has —
      // and with several Stops on one widget, it says which task each stops.
      views.setContentDescription(
          slot.stop,
          HomeWidgets.fill(
              snapshot.string("widget_stop_task", "Stop :task"),
              mapOf("task" to timer.description),
          ),
      )
      val intent =
          Intent(context, WidgetCommandReceiver::class.java).apply {
            action = WidgetCommandReceiver.ACTION_STOP
            putExtra(WidgetCommandReceiver.EXTRA_TASK, timer.taskId)
            putExtra(WidgetCommandReceiver.EXTRA_COMPANY, company.id)
            putExtra(WidgetCommandReceiver.EXTRA_USER, snapshot.userId)
            putExtra(WidgetCommandReceiver.EXTRA_RUNNING_SINCE, timer.runningSince)
          }
      views.setOnClickPendingIntent(
          slot.stop,
          PendingIntent.getBroadcast(
              context,
              id * 100 + 50 + index,
              intent,
              PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
          ),
      )
    }
  }
}
