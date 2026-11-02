package com.invoiceninja.admin.homewidgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Typeface
import android.widget.RemoteViews
import com.invoiceninja.admin.R

/**
 * Needs attention: past-due invoices first, then those due within a week —
 * the in-app band, at a glance. With nothing to chase, a green "Nothing past
 * due" and the next invoice due. A tall widget with room to spare closes on
 * Outstanding. Each row opens its invoice.
 */
class AttentionWidgetProvider : BaseWidgetProvider() {
  override val kind = HomeWidgets.KIND_ATTENTION

  /**
   * What fits, in dp — pure, so [plan] is unit-tested without a device.
   * [header] is the header (or the check line in its place) and [footer] the
   * footer; [row] an invoice row with the gap above it, [section] a small
   * section label with its gap, [block] the Outstanding block with its gap.
   */
  internal data class Heights(
      val header: Float,
      val footer: Float,
      val row: Float,
      val section: Float,
      val block: Float,
  )

  /** How many rows of each kind to draw, which labels go above them, and the height that takes. */
  internal data class Plan(
      val late: Int,
      val soon: Int,
      /** A "Due soon" label above the first due-soon row, under past-due rows. */
      val soonSection: Boolean,
      val nextDue: Boolean,
      val nextDueSection: Boolean,
      val outstanding: Boolean,
      val needDp: Float,
  )

  companion object {
    private val ROWS =
        listOf(
            Row(R.id.section1, R.id.row1, R.id.row1_title, R.id.row1_amount, R.id.row1_detail, R.id.row1_gap, R.id.row1_remind),
            Row(R.id.section2, R.id.row2, R.id.row2_title, R.id.row2_amount, R.id.row2_detail, R.id.row2_gap, R.id.row2_remind),
            Row(R.id.section3, R.id.row3, R.id.row3_title, R.id.row3_amount, R.id.row3_detail, R.id.row3_gap, R.id.row3_remind),
            Row(R.id.section4, R.id.row4, R.id.row4_title, R.id.row4_amount, R.id.row4_detail, R.id.row4_gap, R.id.row4_remind),
            Row(R.id.section5, R.id.row5, R.id.row5_title, R.id.row5_amount, R.id.row5_detail, R.id.row5_gap, R.id.row5_remind),
        )

    private data class Row(
        val section: Int,
        val root: Int,
        val title: Int,
        val amount: Int,
        val detail: Int,
        val gap: Int,
        val remind: Int,
    )

    private const val MAX_ROWS = 5

    /** The past-due bar with its gaps (4dp above, 2dp below), and its resolution. */
    private const val BAR_DP = 10f
    private const val BAR_MAX = 1000

    /**
     * The rows that fit [roomDp], the content height at the usual padding.
     * The header and footer come first (the footer is where "Tap to refresh"
     * lives, so it must never be the line that is cut). One row is drawn even
     * when it only fits [tightDp], the height with the padding squeezed
     * ([fitPadding]): a widget at its smallest still shows its first invoice.
     *
     * A due-soon row never sits under "Past due": past due first, then the
     * due-soon rows only under their own label, and only when the label and
     * at least one row fit. The Outstanding block closes a widget whose rows
     * left room for all of it.
     */
    internal fun plan(
        h: Heights,
        roomDp: Float,
        tightDp: Float,
        lateCount: Int,
        soonCount: Int,
        hasNextDue: Boolean,
        hasOutstanding: Boolean,
    ): Plan {
      var used = h.header + h.footer
      fun fits(extra: Float) = used + extra <= roomDp
      var late = 0
      var soon = 0
      var soonSection = false
      var nextDue = false
      var nextDueSection = false
      when {
        lateCount > 0 -> {
          late = 1
          used += h.row
          while (late < minOf(lateCount, MAX_ROWS) && fits(h.row)) {
            late++
            used += h.row
          }
          if (soonCount > 0 && late < MAX_ROWS && fits(h.section + h.row)) {
            soonSection = true
            used += h.section
            while (soon < soonCount && late + soon < MAX_ROWS && fits(h.row)) {
              soon++
              used += h.row
            }
          }
        }
        soonCount > 0 -> {
          soon = 1
          used += h.row
          while (soon < minOf(soonCount, MAX_ROWS) && fits(h.row)) {
            soon++
            used += h.row
          }
        }
        hasNextDue ->
            when {
              fits(h.section + h.row) -> {
                nextDue = true
                nextDueSection = true
                used += h.section + h.row
              }
              used + h.row <= tightDp -> {
                nextDue = true
                used += h.row
              }
            }
      }
      val outstanding = hasOutstanding && fits(h.block)
      if (outstanding) used += h.block
      return Plan(late, soon, soonSection, nextDue, nextDueSection, outstanding, used)
    }

    fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
      val snapshot = WidgetStore.readSnapshot(context)
      for (id in ids) {
        val settings = WidgetSettings.load(context, id)
        val views =
            message(context, snapshot, settings, id, needsFigures = true)
                ?: build(context, manager, snapshot!!, settings, id)
        manager.updateAppWidget(id, views)
      }
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        snapshot: WidgetSnapshot,
        settings: WidgetSettings,
        id: Int,
    ): RemoteViews {
      val company = snapshot.company(settings.companyId)!!
      val attention =
          company.figures?.attention ?: return notLoaded(context, snapshot, company, id)
      val views = RemoteViews(context.packageName, R.layout.widget_attention)
      applyDirection(views, snapshot)
      val masked = settings.masks(snapshot.appLock)
      val late = attention.pastDue
      val soon = attention.dueSoon
      val outstanding = company.figures?.outstanding
      val (width, height) = sizeDp(context, manager, id)
      val pad = paddingDp(context)
      // Row text runs between the row's 10dp start padding and its end: a
      // 10dp gap, or on a past-due row the 44dp remind button.
      val rowTextWidth = width - 2 * pad - 20
      val remindTextWidth = width - 2 * pad - 10 - 44
      val heights =
          Heights(
              header = lineDp(context, 14f, typeface = Typeface.DEFAULT_BOLD),
              footer = lineDp(context, 11f),
              // Two lines in 5dp padding, never under the 44dp tap target.
              row = 4 + maxOf(44f, 10 + lineDp(context, 13f) + lineDp(context, 12f)),
              section = 6 + lineDp(context, 12f, typeface = MEDIUM),
              block =
                  8 + 2 * lineDp(context, 12f) +
                      lineDp(context, 26f, fontPadding = false, typeface = Typeface.DEFAULT_BOLD) +
                      (if (outstanding?.pastDueShare != null) BAR_DP else 0f),
          )
      val plan =
          plan(
              heights,
              roomDp = height - 2 * pad,
              tightDp = height - 8f,
              lateCount = late.size,
              soonCount = soon.size,
              hasNextDue = attention.nextDue != null,
              hasOutstanding = outstanding != null,
          )
      val pastDueRoute = if (late.isNotEmpty()) "/invoices?filter=past_due" else "/invoices?filter=unpaid"

      // The header: "Past Due · 2 · $3.1K" (the rows are a top few; the count
      // and the sum are the whole of it), "Due soon", or — nothing at all to
      // chase — the green check line in its place.
      val quiet = late.isEmpty() && soon.isEmpty()
      show(views, R.id.header, !quiet)
      show(views, R.id.quiet, quiet)
      if (quiet) {
        views.setTextViewText(
            R.id.quiet,
            snapshot.string(
                "widget_nothing_past_due",
                context.getString(R.string.widget_nothing_past_due),
            ),
        )
      } else {
        val header =
            if (late.isNotEmpty()) {
              val lateCount =
                  outstanding?.pastDueCount?.let { if (outstanding.pastDueExact) "$it" else "$it+" }
                      ?: "${late.size}"
              val sum =
                  outstanding?.pastDueAmount?.let { " · ${if (masked) MASK else it.compact}" } ?: ""
              "${snapshot.string("past_due", context.getString(R.string.widget_past_due))} · $lateCount$sum"
            } else {
              snapshot.string("widget_due_soon", context.getString(R.string.widget_due_soon))
            }
        views.setTextViewText(R.id.header, header)
        views.setOnClickPendingIntent(
            R.id.header,
            HomeWidgets.link(context, pastDueRoute, company.id, id * 100 + 1),
        )
      }

      val rows =
          late.take(plan.late) +
              soon.take(plan.soon) +
              listOfNotNull(attention.nextDue.takeIf { plan.nextDue })
      val dueSoonLabel = snapshot.string("widget_due_soon", context.getString(R.string.widget_due_soon))
      val nextDueLabel = snapshot.string("next_due", context.getString(R.string.widget_next_due))
      ROWS.forEachIndexed { i, slot ->
        val row = rows.getOrNull(i)
        val section =
            when {
              plan.soonSection && i == plan.late -> dueSoonLabel
              plan.nextDueSection && i == 0 -> nextDueLabel
              else -> null
            }
        show(views, slot.section, row != null && section != null)
        if (row != null && section != null) views.setTextViewText(slot.section, section)
        show(views, slot.root, row != null)
        if (row == null) return@forEachIndexed
        // The client says whose it is at a glance; the number moves to the
        // second line, ahead of how late it is.
        val title = row.client.ifEmpty { row.number }
        views.setTextViewText(slot.title, title)
        // The full amount — unless, on a narrow widget, it would leave the
        // client no room, when the compact form stands in.
        // A past-due row ends on its remind button: the invoice's email
        // screen, one tap from the widget. 40dp, inside the 44dp row.
        val pastDue = i < plan.late
        show(views, slot.remind, pastDue)
        show(views, slot.gap, !pastDue)
        if (pastDue) {
          views.setContentDescription(slot.remind, snapshot.string("email_invoice", "Email Invoice"))
          views.setOnClickPendingIntent(
              slot.remind,
              HomeWidgets.link(context, "/invoices/${row.id}/email", company.id, id * 100 + 70 + i),
          )
        }
        val full = row.amount.text.ifEmpty { row.amount.compact }
        val amount =
            when {
              masked -> MASK
              textWidthDp(context, full, 13f, MEDIUM) >
                  (if (pastDue) remindTextWidth else rowTextWidth) / 2 -> row.amount.compact
              else -> full
            }
        views.setTextViewText(slot.amount, amount)
        describeAmount(views, slot.amount, snapshot, masked)
        val lateText = HomeWidgets.daysLate(snapshot, row.lateSince, context)
        val status = lateText ?: HomeWidgets.dueIn(snapshot, row.dueOn, context)
        val detail =
            listOfNotNull(row.number.takeIf { it.isNotEmpty() && row.client.isNotEmpty() }, status)
                .joinToString(" · ")
        views.setTextViewText(
            slot.detail,
            if (lateText != null) HomeWidgets.PAST_DUE_GLYPH + detail else detail,
        )
        HomeWidgets.textColor(context, views, slot.detail, (if (lateText != null) R.color.widget_bad else R.color.widget_ink_muted),
        )
        views.setOnClickPendingIntent(
            slot.root,
            HomeWidgets.link(context, "/invoices/${row.id}", company.id, id * 100 + 10 + i),
        )
      }

      // Room left over: Outstanding, so a tall widget isn't half empty.
      show(views, R.id.outstanding_block, plan.outstanding)
      if (plan.outstanding && outstanding != null) {
        views.setTextViewText(
            R.id.outstanding_label,
            snapshot.string("outstanding", context.getString(R.string.widget_outstanding)),
        )
        val full = outstanding.amount.text.ifEmpty { outstanding.amount.compact }
        views.setTextViewText(
            R.id.outstanding_amount,
            when {
              masked -> HERO_MASK
              textWidthDp(context, full, 26f, Typeface.DEFAULT_BOLD) > width - 2 * pad ->
                  outstanding.amount.compact
              else -> full
            },
        )
        describeAmount(views, R.id.outstanding_amount, snapshot, masked)
        val share = outstanding.pastDueShare
        show(views, R.id.outstanding_bar, share != null)
        if (share != null) {
          views.setProgressBar(
              R.id.outstanding_bar,
              BAR_MAX,
              SnapshotWidgetProvider.barProgress(share),
              false,
          )
        }
        views.setTextViewText(
            R.id.outstanding_caption,
            HomeWidgets.fill(
                snapshot.string("unpaid_count_label", context.getString(R.string.widget_unpaid_count)),
                mapOf("count" to "${outstanding.unpaidCount}"),
            ),
        )
        views.setOnClickPendingIntent(
            R.id.outstanding_block,
            HomeWidgets.link(context, "/invoices?filter=unpaid", company.id, id * 100 + 3),
        )
      }

      val fetchedAt = company.figures?.fetchedAt
      val stale =
          fetchedAt == null || System.currentTimeMillis() - fetchedAt > HomeWidgets.STALE_AFTER_MS
      val footer = buildList {
        if (snapshot.companies.size > 1) add(company.name)
        if (fetchedAt != null) add(HomeWidgets.updated(snapshot, fetchedAt, context))
        if (stale) add(HomeWidgets.staleHint(snapshot, company, context))
      }
      views.setTextViewText(R.id.footer, footer.joinToString(" · "))
      HomeWidgets.textColor(context, views, R.id.footer, (if (stale) R.color.widget_warning else R.color.widget_ink_muted),
      )
      fitPadding(context, views, height, plan.needDp)
      // As the header, and as iOS: past-due invoices when there are any.
      views.setOnClickPendingIntent(
          android.R.id.background,
          HomeWidgets.link(context, pastDueRoute, company.id, id * 100 + 2),
      )
      return views
    }
  }
}
