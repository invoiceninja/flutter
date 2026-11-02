package com.invoiceninja.admin.homewidgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import com.invoiceninja.admin.R

/**
 * Business snapshot. Small: one figure (Outstanding by default) with its
 * caption. Medium and up: Outstanding as the hero, its "4 unpaid · 2 past due"
 * line, and one plain period line with its trend. Each region opens its own
 * list.
 */
class SnapshotWidgetProvider : BaseWidgetProvider() {
  override val kind = HomeWidgets.KIND_SNAPSHOT

  companion object {
    /** At or above this width the widget shows the period row as well, when it is tall enough. */
    private const val MEDIUM_WIDTH_DP = 220

    /**
     * The hero's size range. Medium's floor keeps Outstanding half again the
     * size of the 16sp period amount, so it always reads as the figure; small
     * has nothing to compete with and may go lower on a short widget.
     */
    private const val HERO_MAX_SP = 30
    private const val HERO_MIN_MEDIUM_SP = 24
    private const val HERO_MIN_SMALL_SP = 20

    /** The past-due bar with its gap above (4dp + 4dp), and its resolution. */
    private const val BAR_DP = 8f
    private const val BAR_MAX = 1000

    /**
     * [share] of the bar, never rounded down to nothing: a sliver past due is
     * still past due, and an empty bar would say none is.
     */
    internal fun barProgress(share: Double): Int {
      val p = Math.round(share.coerceIn(0.0, 1.0) * BAR_MAX).toInt()
      return if (share > 0 && p == 0) 1 else p
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
      val figures = company.figures ?: return notLoaded(context, snapshot, company, id)
      val views = RemoteViews(context.packageName, R.layout.widget_snapshot)
      applyDirection(views, snapshot)
      val masked = settings.masks(snapshot.appLock)
      val period = figures.periods[settings.period]
      val (width, height) = sizeDp(context, manager, id)
      val contentWidth = width - 2 * paddingDp(context)
      val contentHeight = height - 2 * paddingDp(context)

      fun money(m: WidgetSnapshot.Money?, compact: Boolean): String =
          when {
            m == null -> "—"
            masked -> MASK
            compact -> m.compact
            else -> m.text
          }

      fun periodName(p: WidgetSnapshot.Period): String =
          if (HomeWidgets.periodEnded(p.endsOn)) p.name else p.label

      fun trend(f: WidgetSnapshot.Figure?): String {
        val pct = f?.deltaPct ?: return ""
        // Masked: the arrow says which way, the size would hint at the amount
        // (and a flat 0 says nothing) — as iOS.
        if (masked) return if (pct > 0) "▲" else if (pct < 0) "▼" else ""
        return when {
          pct > 0 -> "▲ $pct%"
          pct < 0 -> "▼ ${-pct}%"
          else -> "0%"
        }
      }

      fun trendColor(f: WidgetSnapshot.Figure?): Int =
          when (f?.good) {
            true -> R.color.widget_good
            false -> R.color.widget_bad
            null -> R.color.widget_ink_muted
          }

      // Spans carry their colour as a value, resolved now: unlike
      // HomeWidgets.textColor they don't follow a light/dark switch until the
      // next redraw. Only the coloured part is a span; the rest takes the
      // TextView's own muted colour, which does follow.
      fun SpannableStringBuilder.appendColored(text: String, colorRes: Int) {
        val start = length
        append(text)
        setSpan(
            ForegroundColorSpan(context.getColor(colorRes)),
            start,
            length,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }

      // The period row, Payments by default: one line when it holds the label,
      // the amount and the trend; else the label on top, the rest under it.
      val periodFigure = period?.payments
      val periodLabel =
          period?.let {
            "${snapshot.string("payments", context.getString(R.string.widget_payments))} · ${periodName(it)}"
          }
      val periodAmount = money(periodFigure?.amount, compact = false)
      val periodTrend = trend(periodFigure)
      val periodOneLine =
          periodLabel != null &&
              textWidthDp(context, periodLabel, 13f) + 8 +
                  textWidthDp(context, periodAmount, 16f, MEDIUM) +
                  (if (periodTrend.isEmpty()) 0f else 6 + textWidthDp(context, periodTrend, 13f)) <=
                  contentWidth
      val periodRowDp =
          if (period == null) 0f
          else
              4 + 8 +
                  (if (periodOneLine) maxOf(lineDp(context, 13f), lineDp(context, 16f, typeface = MEDIUM))
                  else lineDp(context, 13f) + lineDp(context, 16f, typeface = MEDIUM))

      val labelDp = lineDp(context, 13f)
      val captionLineDp = lineDp(context, 13f)
      val footerDp = lineDp(context, 11f)
      fun heroDp(sp: Int) = lineDp(context, sp.toFloat(), fontPadding = false, typeface = Typeface.DEFAULT_BOLD)
      // Medium: the period row joins, and the hero keeps at least its medium
      // floor — narrower or shorter than that, the widget stays small.
      val medium =
          width >= MEDIUM_WIDTH_DP &&
              labelDp + 2 + heroDp(HERO_MIN_MEDIUM_SP) + captionLineDp + periodRowDp + footerDp <=
                  contentHeight

      // Small, a period figure chosen: the hero is that figure.
      val heroFigure =
          if (!medium && settings.figure != WidgetSettings.FIGURE_OUTSTANDING && period != null) {
            when (settings.figure) {
              WidgetSettings.FIGURE_INVOICES -> period.invoices to "invoices"
              WidgetSettings.FIGURE_EXPENSES -> period.expenses to "expenses"
              else -> period.payments to "payments"
            }
          } else null

      // One launcher row (the widget resizes down to 40dp): too short for the
      // small layout even with its padding squeezed, so the whole widget is
      // one line — label, amount, and the one thing that matters next.
      val smallNeedDp = labelDp + 2 + heroDp(HERO_MIN_SMALL_SP) + captionLineDp + footerDp
      val oneLine = !medium && smallNeedDp > height - 8

      val outstanding = figures.outstanding
      // The past-due bar: small, Outstanding hero, and only where it fits
      // without pushing the hero under its floor.
      val barShare =
          outstanding?.pastDueShare?.takeIf {
            !medium && !oneLine && heroFigure == null && smallNeedDp + BAR_DP <= height - 8
          }
      show(views, R.id.past_due_bar, barShare != null)
      if (barShare != null) {
        views.setProgressBar(R.id.past_due_bar, BAR_MAX, barProgress(barShare), false)
      }
      val caption = SpannableStringBuilder()
      var heroFull: String
      var heroCompact: String
      // The one-line form's parts: "Outstanding", "$12.4K", "⚠ 2 past due".
      var lineLabel: String
      val lineTail = SpannableStringBuilder()
      var lineRoute: String

      if (heroFigure != null) {
        val (fig, key) = heroFigure
        val fallback =
            when (key) {
              "invoices" -> R.string.widget_invoices
              "expenses" -> R.string.widget_expenses
              else -> R.string.widget_payments
            }
        // Just the figure's name, so it never truncates; the period goes in
        // the caption, after the trend: "▲ 8% · This Month".
        lineLabel = snapshot.string(key, context.getString(fallback))
        views.setTextViewText(R.id.label, lineLabel)
        heroFull = money(fig?.amount, compact = true)
        heroCompact = heroFull
        val trendText = trend(fig)
        if (trendText.isNotEmpty()) {
          if (fig?.good == null) caption.append(trendText) else caption.appendColored(trendText, trendColor(fig))
          caption.append(" · ")
        }
        caption.append(periodName(period!!))
        if (trendText.isNotEmpty()) {
          lineTail.appendColored("$trendText · ", if (fig?.good == null) R.color.widget_ink_muted else trendColor(fig))
        }
        lineTail.appendColored(periodName(period), R.color.widget_ink_muted)
        lineRoute = "/$key"
        views.setOnClickPendingIntent(
            R.id.hero,
            HomeWidgets.link(context, "/$key", company.id, id * 100 + 1),
        )
      } else {
        // Converted from several currencies: say into which ("in USD").
        val inCurrency = figures.inCurrency
        val outstandingLabel =
            snapshot.string("outstanding", context.getString(R.string.widget_outstanding))
        views.setTextViewText(
            R.id.label,
            if (inCurrency.isEmpty()) outstandingLabel
            else
                "$outstandingLabel · " +
                    HomeWidgets.fill(
                        snapshot.string("widget_in_currency", "in :currency"),
                        mapOf("currency" to inCurrency),
                    ),
        )
        heroFull = money(outstanding?.amount, compact = !medium)
        heroCompact = money(outstanding?.amount, compact = true)
        lineLabel = outstandingLabel
        lineRoute = "/invoices?filter=unpaid"
        // "4 unpaid" muted; only the past-due part, "⚠ 2 past due · $3.1K",
        // in the past-due colour — the count of what is merely unpaid is not
        // an alarm.
        outstanding?.let {
          caption.append(
              HomeWidgets.fill(
                  snapshot.string(
                      "unpaid_count_label",
                      context.getString(R.string.widget_unpaid_count),
                  ),
                  mapOf("count" to "${it.unpaidCount}"),
              ),
          )
          val late = it.pastDueCount
          if (late != null && late > 0) {
            val count = if (it.pastDueExact) "$late" else "$late+"
            var text =
                HomeWidgets.PAST_DUE_GLYPH +
                    HomeWidgets.fill(
                        snapshot.string(
                            "past_due_count_label",
                            context.getString(R.string.widget_past_due_count),
                        ),
                        mapOf("count" to count),
                    )
            // One line has room for the count only: "⚠ 2 past due".
            lineTail.appendColored(text, R.color.widget_bad)
            lineRoute = "/invoices?filter=past_due"
            it.pastDueAmount?.let { a -> text += " · ${money(a, true)}" }
            caption.append(" · ")
            caption.appendColored(text, R.color.widget_bad)
          }
        }
        if (lineTail.isEmpty() && caption.isNotEmpty()) {
          lineTail.appendColored(caption.toString(), R.color.widget_ink_muted)
        }
        // Outstanding opens the unpaid invoices; its caption, led by the
        // past-due count, the past-due ones — what the dashboard opens.
        views.setOnClickPendingIntent(
            R.id.hero,
            HomeWidgets.link(context, "/invoices?filter=unpaid", company.id, id * 100 + 1),
        )
        views.setOnClickPendingIntent(
            R.id.caption,
            HomeWidgets.link(
                context,
                if ((outstanding?.pastDueCount ?: 0) > 0) "/invoices?filter=past_due"
                else "/invoices?filter=unpaid",
                company.id,
                id * 100 + 2,
            ),
        )
      }
      views.setTextViewText(R.id.caption, caption)
      HomeWidgets.textColor(context, views, R.id.caption, R.color.widget_ink_muted)

      // The hero takes what the other lines leave, up to 30sp, and never below
      // its floor. A caption that wraps gets its second line only when the
      // hero can spare it.
      val minSp = if (medium) HERO_MIN_MEDIUM_SP else HERO_MIN_SMALL_SP
      val fixed =
          labelDp + 2 + footerDp + (if (medium) periodRowDp else 0f) + (if (barShare != null) BAR_DP else 0f)
      val captionLines =
          if (caption.isEmpty()) 0
          else {
            val wraps = lineCount(context, caption, 13f, contentWidth) > 1
            if (wraps && contentHeight - fixed - 2 * captionLineDp >= heroDp(minSp)) 2 else 1
          }
      views.setInt(R.id.caption, "setMaxLines", captionLines.coerceAtLeast(1))
      show(views, R.id.caption, captionLines > 0)
      val heroRoom = contentHeight - fixed - captionLines * captionLineDp
      var heroSp = (minSp..HERO_MAX_SP).lastOrNull { heroDp(it) <= heroRoom } ?: minSp
      if (masked) {
        heroFull = HERO_MASK
        heroCompact = HERO_MASK
      }
      fun fitsWidth(text: String, sp: Int) =
          textWidthDp(context, text, sp.toFloat(), Typeface.DEFAULT_BOLD) <= contentWidth
      // A full amount too wide even at the floor falls back to its compact
      // form rather than shrinking the hero past it.
      val heroText = if (fitsWidth(heroFull, minSp)) heroFull else heroCompact
      while (heroSp > minSp && !fitsWidth(heroText, heroSp)) heroSp--
      views.setTextViewText(R.id.hero, heroText)
      setTextSizeSp(views, R.id.hero, heroSp.toFloat())
      describeAmount(views, R.id.hero, snapshot, masked)

      show(views, R.id.period_row, medium && period != null)
      if (medium && period != null) {
        show(views, R.id.period_label_top, !periodOneLine)
        show(views, R.id.period_label, periodOneLine)
        views.setTextViewText(if (periodOneLine) R.id.period_label else R.id.period_label_top, periodLabel)
        views.setTextViewText(R.id.period_amount, periodAmount)
        describeAmount(views, R.id.period_amount, snapshot, masked)
        views.setTextViewText(R.id.period_trend, periodTrend)
        show(views, R.id.period_trend, periodTrend.isNotEmpty())
        HomeWidgets.textColor(context, views, R.id.period_trend, trendColor(periodFigure))
        views.setOnClickPendingIntent(
            R.id.period_row,
            HomeWidgets.link(context, "/payments", company.id, id * 100 + 3),
        )
      }

      // Footer: whose figures (only when there is a choice) and how old.
      val fetchedAt = figures.fetchedAt
      val stale =
          fetchedAt == null ||
              System.currentTimeMillis() - fetchedAt > HomeWidgets.STALE_AFTER_MS ||
              (period != null && HomeWidgets.periodEnded(period.endsOn))
      val parts = buildList {
        if (snapshot.companies.size > 1) add(company.name)
        if (fetchedAt != null) add(HomeWidgets.updated(snapshot, fetchedAt, context))
        if (stale) add(HomeWidgets.staleHint(snapshot, company, context))
      }
      if (oneLine) {
        // Muted label and tail around the amount in the TextView's own ink;
        // a stale widget says so at the end, where the footer would.
        val line = SpannableStringBuilder()
        line.appendColored(lineLabel, R.color.widget_ink_muted)
        line.append(" ")
        val amountStart = line.length
        line.append(if (masked) MASK else heroCompact)
        line.setSpan(AbsoluteSizeSpan(16, true), amountStart, line.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        line.setSpan(StyleSpan(Typeface.BOLD), amountStart, line.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (lineTail.isNotEmpty()) {
          line.appendColored(" · ", R.color.widget_ink_muted)
          // Coloured part by part (muted, past due, a trend), never one span
          // laid over another: which of two overlapping colours wins is a
          // matter of span order, and that order crosses a parcel here.
          line.append(lineTail)
        }
        if (stale) {
          line.appendColored(" · ${HomeWidgets.staleHint(snapshot, company, context)}", R.color.widget_warning)
        }
        for (v in listOf(R.id.label, R.id.hero, R.id.caption, R.id.past_due_bar, R.id.period_row, R.id.spacer, R.id.footer)) {
          show(views, v, false)
        }
        show(views, R.id.line, true)
        views.setTextViewText(R.id.line, line)
        HomeWidgets.textColor(context, views, R.id.line, R.color.widget_ink)
        if (masked) describeAmount(views, R.id.line, snapshot, true)
        views.setOnClickPendingIntent(
            R.id.line,
            HomeWidgets.link(context, lineRoute, company.id, id * 100 + 1),
        )
        fitPadding(context, views, height, lineDp(context, 16f, typeface = Typeface.DEFAULT_BOLD))
        views.setOnClickPendingIntent(
            android.R.id.background,
            HomeWidgets.link(context, "/dashboard", company.id, id * 100 + 4),
        )
        return views
      }
      views.setTextViewText(R.id.footer, parts.joinToString(" · "))
      HomeWidgets.textColor(context, views, R.id.footer, (if (stale) R.color.widget_warning else R.color.widget_ink_muted),
      )
      fitPadding(
          context,
          views,
          height,
          fixed + captionLines * captionLineDp + heroDp(heroSp),
      )
      views.setOnClickPendingIntent(
          android.R.id.background,
          HomeWidgets.link(context, "/dashboard", company.id, id * 100 + 4),
      )
      return views
    }
  }
}
