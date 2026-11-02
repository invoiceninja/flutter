package com.invoiceninja.admin.homewidgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Typeface
import android.os.Bundle
import android.text.StaticLayout
import android.text.TextPaint
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.invoiceninja.admin.R

/**
 * What the three providers share: the lifecycle hooks, and the states every
 * widget draws the same way — never opened, signed out, a newer schema, no
 * company.
 *
 * Exported false (manifest): the system still delivers `APPWIDGET_UPDATE`,
 * and nothing else can poke a provider.
 */
abstract class BaseWidgetProvider : AppWidgetProvider() {
  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
    redraw(context)
    // A widget just placed may show a company or a period nothing has fetched
    // yet: a running app fetches it now rather than at its next resume.
    HomeWidgetsChannel.active?.notifyWidgetsChanged()
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      manager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    redraw(context)
  }

  private fun redraw(context: Context) {
    val pending = goAsync()
    HomeWidgets.updateAsync(context, setOf(kind)) { pending.finish() }
  }

  override fun onDeleted(context: Context, appWidgetIds: IntArray) {
    for (id in appWidgetIds) WidgetSettings.delete(context, id)
  }

  override fun onRestored(context: Context, oldWidgetIds: IntArray, newWidgetIds: IntArray) {
    WidgetSettings.restore(context, oldWidgetIds, newWidgetIds)
  }

  abstract val kind: String

  companion object {
    const val MASK = "••••"

    /**
     * A hidden hero amount. At 28sp the small bullets of [MASK] look like a
     * rendering fault; four large dots read as deliberate.
     */
    const val HERO_MASK = "\u25CF\u25CF\u25CF\u25CF"

    /**
     * The message every widget shows when it has nothing of its own to draw,
     * or null when it can draw. [needsFigures] is false for the Timer widget,
     * which works without the dashboard permission.
     */
    fun message(
        context: Context,
        snapshot: WidgetSnapshot?,
        settings: WidgetSettings,
        appWidgetId: Int,
        needsFigures: Boolean,
    ): RemoteViews? {
      fun view(text: String, tap: android.app.PendingIntent): RemoteViews =
          messageViews(context, text, tap, appWidgetId)

      val open = HomeWidgets.openApp(context, appWidgetId * 100)
      if (snapshot == null) {
        return view(context.getString(R.string.widget_open_to_load), open)
      }
      if (snapshot.tooNew) {
        return view(
            snapshot.string("widget_update_app", context.getString(R.string.widget_update_app)),
            open,
        )
      }
      if (!snapshot.signedIn) {
        return view(
            snapshot.string("widget_sign_in", context.getString(R.string.widget_sign_in)),
            open,
        )
      }
      val company = snapshot.company(settings.companyId)
          ?: return view(
              snapshot.string(
                  "widget_choose_company",
                  context.getString(R.string.widget_choose_company),
              ),
              HomeWidgets.configure(context, appWidgetId),
          )
      if (needsFigures && !company.canViewDashboard) {
        return view(
            snapshot.string(
                "widget_no_dashboard_permission",
                context.getString(R.string.widget_no_dashboard_permission),
            ),
            open,
        )
      }
      return null
    }

    /** Lays the widget out right to left when the APP's language does. */
    fun applyDirection(views: RemoteViews, snapshot: WidgetSnapshot) {
      views.setInt(
          android.R.id.background,
          "setLayoutDirection",
          if (snapshot.rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR,
      )
    }

    /**
     * The widget's size in dp, as it is in the orientation where it is
     * *smallest*: portrait's width (MIN_WIDTH) and landscape's height
     * (MIN_HEIGHT). One layout serves both, so it must fit both — sized to the
     * larger height, a rotated tablet clipped the footer, the one line that
     * says the figures are stale.
     */
    fun sizeDp(context: Context, manager: AppWidgetManager, appWidgetId: Int): Pair<Int, Int> {
      val o = manager.getAppWidgetOptions(appWidgetId)
      val width = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
      val height = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
      if (width > 0 && height > 0) return width to height
      // Some launchers send no size until the first resize: lay out for the
      // smallest the provider allows, which is what fits everywhere.
      val info = manager.getAppWidgetInfo(appWidgetId)
      val density = context.resources.displayMetrics.density
      return (width.takeIf { it > 0 } ?: ((info?.minResizeWidth ?: 0) / density).toInt().coerceAtLeast(110)) to
          (height.takeIf { it > 0 } ?: ((info?.minResizeHeight ?: 0) / density).toInt().coerceAtLeast(60))
    }

    // ─── Measuring ─────────────────────────────────────────────────────────
    //
    // A RemoteViews layout can't measure itself back to us, so the providers
    // measure the text they are about to set, with the device's own font and
    // the user's font size, and choose what to show from that: which rows fit,
    // how big the hero is, whether a line breaks. Guessing in dp per line
    // (what the providers did first) drifts with every font and font scale.

    /** The widget's padding on one edge, in dp (`widget_padding`: 14dp, 16dp on Android 12+). */
    fun paddingDp(context: Context): Float =
        context.resources.getDimension(R.dimen.widget_padding) /
            context.resources.displayMetrics.density

    /** How far [fitPadding] may squeeze the vertical padding of a widget too short for its content. */
    private const val MIN_PADDING_DP = 4f

    /**
     * The layouts' `sans-serif-medium`, for measuring. Lazy: a JVM unit test
     * that touches a provider's pure planning must not run Android code.
     */
    val MEDIUM: Typeface by lazy { Typeface.create("sans-serif-medium", Typeface.NORMAL) }

    private fun paint(context: Context, sp: Float, typeface: Typeface): TextPaint =
        TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
          textSize =
              TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, context.resources.displayMetrics)
          this.typeface = typeface
        }

    /**
     * One line of [sp] text, in dp: top to bottom with font padding (what a
     * TextView reserves by default), ascent to descent without it — the
     * figures and clocks, which turn the padding off: digits have no tall
     * script to clip.
     */
    fun lineDp(
        context: Context,
        sp: Float,
        fontPadding: Boolean = true,
        typeface: Typeface = Typeface.DEFAULT,
    ): Float {
      val m = paint(context, sp, typeface).fontMetrics
      val px = if (fontPadding) m.bottom - m.top else m.descent - m.ascent
      return px / context.resources.displayMetrics.density
    }

    /** How wide [text] is on one line at [sp], in dp. */
    fun textWidthDp(context: Context, text: CharSequence, sp: Float, typeface: Typeface = Typeface.DEFAULT): Float =
        paint(context, sp, typeface).measureText(text, 0, text.length) /
            context.resources.displayMetrics.density

    /** How many lines [text] wraps to in [widthDp]. */
    fun lineCount(
        context: Context,
        text: CharSequence,
        sp: Float,
        widthDp: Float,
        typeface: Typeface = Typeface.DEFAULT,
    ): Int {
      if (text.isEmpty() || widthDp <= 0) return 1
      val widthPx = (widthDp * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
      return StaticLayout.Builder.obtain(text, 0, text.length, paint(context, sp, typeface), widthPx)
          .setIncludePad(true)
          .build()
          .lineCount
    }

    /**
     * Sets the vertical padding so [needDp] of content fits in [heightDp]:
     * the usual padding when it does, less — never under 4dp — when the
     * widget is at its smallest and even one row would cut the footer, the
     * line that says "Tap to refresh". Returns the padding used, per edge.
     */
    fun fitPadding(context: Context, views: RemoteViews, heightDp: Int, needDp: Float): Float {
      val pad = paddingDp(context)
      if (heightDp - 2 * pad >= needDp) return pad
      val vertical = ((heightDp - needDp) / 2).coerceIn(MIN_PADDING_DP, pad)
      val density = context.resources.displayMetrics.density
      val h = (pad * density).toInt()
      val v = (vertical * density).toInt()
      views.setViewPadding(android.R.id.background, h, v, h, v)
      return vertical
    }

    /**
     * The message layout, fitted: the glyph above 14sp text where there is
     * room, then without the glyph, then at 12sp — the Timer widget is
     * allowed down to 60dp tall, where two lines of 14sp are all there is.
     */
    fun messageViews(
        context: Context,
        text: String,
        tap: android.app.PendingIntent,
        appWidgetId: Int,
    ): RemoteViews {
      val views = RemoteViews(context.packageName, R.layout.widget_message)
      views.setTextViewText(R.id.message, text)
      views.setOnClickPendingIntent(android.R.id.background, tap)
      val manager = AppWidgetManager.getInstance(context)
      val (width, height) = sizeDp(context, manager, appWidgetId)
      val pad = paddingDp(context)
      val contentWidth = width - 2 * pad
      val roomy = height - 2 * pad
      val tight = height - 2 * MIN_PADDING_DP
      fun textDp(sp: Float) = lineCount(context, text, sp, contentWidth) * lineDp(context, sp)
      val glyphDp = 28f + 8f
      when {
        glyphDp + textDp(14f) <= roomy -> Unit
        textDp(14f) <= roomy -> show(views, R.id.message_glyph, false)
        else -> {
          show(views, R.id.message_glyph, false)
          val sp = if (textDp(14f) <= tight) 14f else 12f
          setTextSizeSp(views, R.id.message, sp)
          val lines = (tight / lineDp(context, sp)).toInt().coerceAtLeast(1)
          views.setInt(R.id.message, "setMaxLines", lines)
          fitPadding(context, views, height, minOf(textDp(sp), lines * lineDp(context, sp)))
        }
      }
      return views
    }

    /**
     * A figure that isn't loaded is not zero: the company a widget shows has
     * no figures yet (never fetched, a pinned company the app hasn't opened, a
     * failed fetch). Says so instead of drawing "Nothing past due" or "—".
     */
    fun notLoaded(
        context: Context,
        snapshot: WidgetSnapshot,
        company: WidgetSnapshot.Company,
        appWidgetId: Int,
    ): RemoteViews =
        messageViews(
            context,
            if (company.id != snapshot.activeCompanyId) {
              HomeWidgets.fill(
                  snapshot.string(
                      "widget_open_company_to_update",
                      context.getString(R.string.widget_open_company_to_update),
                  ),
                  mapOf("company" to company.name),
              )
            } else {
              context.getString(R.string.widget_open_to_load)
            },
            HomeWidgets.link(context, "/dashboard", company.id, appWidgetId * 100 + 98),
            appWidgetId,
        )

    /** Reads "Amount hidden" for a masked amount, not four bullets. */
    fun describeAmount(views: RemoteViews, viewId: Int, snapshot: WidgetSnapshot, masked: Boolean) {
      if (masked) {
        views.setContentDescription(viewId, snapshot.string("widget_amount_hidden", "Amount hidden"))
      } else {
        views.setContentDescription(viewId, null)
      }
    }

    fun setTextSizeSp(views: RemoteViews, id: Int, sp: Float) {
      views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sp)
    }

    fun show(views: RemoteViews, id: Int, visible: Boolean) {
      views.setViewVisibility(id, if (visible) View.VISIBLE else View.GONE)
    }
  }
}
