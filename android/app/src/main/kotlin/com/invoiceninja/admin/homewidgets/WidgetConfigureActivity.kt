package com.invoiceninja.admin.homewidgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import com.invoiceninja.admin.R

/**
 * A widget's settings: company, period and figure (Business snapshot), and
 * Hide amounts. Plain Android views — no Flutter engine, which this process
 * may already be running.
 *
 * Exported, as the launcher has to start it; so it checks the widget id it is
 * handed belongs to this app before it saves anything — otherwise another app
 * could switch a widget's masking off.
 */
class WidgetConfigureActivity : Activity() {
  private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setResult(RESULT_CANCELED)
    // Exported, so anything can start it: before API 33 reading the extras
    // unparcels them all, and a forged one would throw — finish instead.
    appWidgetId =
        runCatching {
              intent?.extras?.getInt(
                  AppWidgetManager.EXTRA_APPWIDGET_ID,
                  AppWidgetManager.INVALID_APPWIDGET_ID,
              )
            }
            .getOrNull() ?: AppWidgetManager.INVALID_APPWIDGET_ID
    val info = AppWidgetManager.getInstance(this).getAppWidgetInfo(appWidgetId)
    if (info == null || info.provider.packageName != packageName) {
      finish()
      return
    }
    val kind =
        when (info.provider.className) {
          SnapshotWidgetProvider::class.java.name -> HomeWidgets.KIND_SNAPSHOT
          AttentionWidgetProvider::class.java.name -> HomeWidgets.KIND_ATTENTION
          else -> HomeWidgets.KIND_TIMER
        }
    setTitle(R.string.widget_settings_title)
    setContentView(build(kind))
  }

  private fun dp(v: Int): Int =
      TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics)
          .toInt()

  private fun build(kind: String): ScrollView {
    val snapshot = WidgetStore.readSnapshot(this)
    val current = WidgetSettings.load(this, appWidgetId)
    fun s(key: String, fallback: Int) = snapshot?.string(key, getString(fallback)) ?: getString(fallback)

    val column =
        LinearLayout(this).apply {
          orientation = LinearLayout.VERTICAL
          setPadding(dp(20), dp(16), dp(20), dp(16))
        }

    fun section(title: Int) =
        column.addView(
            TextView(this).apply {
              setText(title)
              setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
              setPadding(0, dp(16), 0, dp(4))
            },
        )

    fun group(options: List<Pair<String, String>>, selected: String): RadioGroup {
      val g = RadioGroup(this)
      for ((value, label) in options) {
        g.addView(
            RadioButton(this).apply {
              id = ViewGroup.generateViewId()
              text = label
              tag = value
              isChecked = value == selected
            },
        )
      }
      if (g.checkedRadioButtonId == -1 && g.childCount > 0) {
        (g.getChildAt(0) as RadioButton).isChecked = true
      }
      column.addView(g)
      return g
    }

    fun RadioGroup.value(): String =
        findViewById<RadioButton>(checkedRadioButtonId)?.tag as? String ?: ""

    section(R.string.widget_settings_company)
    val companies =
        listOf("" to getString(R.string.widget_settings_current_company)) +
            snapshot?.companies.orEmpty().map { it.id to it.name }
    val companyGroup = group(companies, current.companyId)

    var periodGroup: RadioGroup? = null
    var figureGroup: RadioGroup? = null
    if (kind == HomeWidgets.KIND_SNAPSHOT) {
      section(R.string.widget_settings_period)
      periodGroup =
          group(
              WidgetSettings.PERIODS.map { p ->
                p to
                    s(
                        p,
                        when (p) {
                          "last30_days" -> R.string.widget_last_30_days
                          "this_year" -> R.string.widget_this_year
                          else -> R.string.widget_this_month
                        },
                    )
              },
              current.period,
          )
      section(R.string.widget_settings_figure)
      figureGroup =
          group(
              listOf(
                  WidgetSettings.FIGURE_OUTSTANDING to s("outstanding", R.string.widget_outstanding),
                  WidgetSettings.FIGURE_INVOICES to s("invoices", R.string.widget_invoices),
                  WidgetSettings.FIGURE_PAYMENTS to s("payments", R.string.widget_payments),
                  WidgetSettings.FIGURE_EXPENSES to s("expenses", R.string.widget_expenses),
              ),
              current.figure,
          )
      column.addView(
          TextView(this).apply {
            setText(R.string.widget_settings_figure_help)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
          },
      )
    }

    var hideGroup: RadioGroup? = null
    if (kind != HomeWidgets.KIND_TIMER) {
      section(R.string.widget_settings_hide_amounts)
      hideGroup =
          group(
              listOf(
                  WidgetSettings.HIDE_AUTO to getString(R.string.widget_settings_hide_auto),
                  WidgetSettings.HIDE_ON to getString(R.string.widget_settings_on),
                  WidgetSettings.HIDE_OFF to getString(R.string.widget_settings_off),
              ),
              current.hideAmounts,
          )
      column.addView(
          TextView(this).apply {
            setText(R.string.widget_settings_hide_help)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
          },
      )
    }

    column.addView(
        Button(this).apply {
          setText(R.string.widget_settings_save)
          setOnClickListener {
            WidgetSettings.save(
                this@WidgetConfigureActivity,
                appWidgetId,
                WidgetSettings(
                    companyId = companyGroup.value(),
                    period = periodGroup?.value() ?: current.period,
                    figure = figureGroup?.value() ?: current.figure,
                    hideAmounts = hideGroup?.value() ?: current.hideAmounts,
                ),
            )
            HomeWidgets.updateAsync(this@WidgetConfigureActivity, setOf(kind)) {}
            // The app fetches what a newly chosen period needs on its next run.
            HomeWidgetsChannel.active?.notifyWidgetsChanged()
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
            finish()
          }
        },
    )
    // No taps through an overlay drawn over it (tapjacking a masking switch).
    return ScrollView(this).apply {
      filterTouchesWhenObscured = true
      addView(column)
    }
  }
}
