package com.invoiceninja.admin.homewidgets

import android.content.Context

/**
 * One widget's configuration, kept per `appWidgetId` in a private preferences
 * file. Every field has a default, so a widget placed without configuring
 * (`configuration_optional`) works at once.
 */
data class WidgetSettings(
    /** Empty follows the app's active company. */
    val companyId: String = "",
    /** A `WidgetPeriod.wire` value. */
    val period: String = "this_month",
    /** What the small snapshot shows: outstanding, invoices, payments, expenses. */
    val figure: String = FIGURE_OUTSTANDING,
    val hideAmounts: String = HIDE_AUTO,
) {
  /** Whether money is masked, given whether App Lock is on. */
  fun masks(appLock: Boolean): Boolean =
      when (hideAmounts) {
        HIDE_ON -> true
        HIDE_OFF -> false
        else -> appLock
      }

  companion object {
    const val FIGURE_OUTSTANDING = "outstanding"
    const val FIGURE_INVOICES = "invoices"
    const val FIGURE_PAYMENTS = "payments"
    const val FIGURE_EXPENSES = "expenses"

    const val HIDE_AUTO = "auto"
    const val HIDE_ON = "on"
    const val HIDE_OFF = "off"

    val PERIODS = listOf("this_month", "last30_days", "this_year")

    private const val PREFS = "home_widget_settings"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(context: Context, appWidgetId: Int): WidgetSettings {
      val p = prefs(context)
      val d = WidgetSettings()
      return WidgetSettings(
          companyId = p.getString("$appWidgetId.company", d.companyId) ?: d.companyId,
          period = p.getString("$appWidgetId.period", d.period) ?: d.period,
          figure = p.getString("$appWidgetId.figure", d.figure) ?: d.figure,
          hideAmounts = p.getString("$appWidgetId.hide", d.hideAmounts) ?: d.hideAmounts,
      )
    }

    fun save(context: Context, appWidgetId: Int, s: WidgetSettings) {
      prefs(context)
          .edit()
          .putString("$appWidgetId.company", s.companyId)
          .putString("$appWidgetId.period", s.period)
          .putString("$appWidgetId.figure", s.figure)
          .putString("$appWidgetId.hide", s.hideAmounts)
          .apply()
    }

    fun delete(context: Context, appWidgetId: Int) {
      val e = prefs(context).edit()
      for (key in listOf("company", "period", "figure", "hide")) e.remove("$appWidgetId.$key")
      e.apply()
    }

    /**
     * Restored widgets' settings follow them to their new ids. All read first,
     * then the old ones deleted, then the new ones written: moved one at a
     * time, an id appearing in both lists (old [2, 3] → new [3, 4]) would hand
     * widget 2's settings to widget 4, and old == new would delete what it had
     * just written — dropping a "Hide amounts: On" back to the default.
     */
    fun restore(context: Context, oldIds: IntArray, newIds: IntArray) {
      val moved = oldIds.indices.filter { it < newIds.size }.map { newIds[it] to load(context, oldIds[it]) }
      for (id in oldIds) delete(context, id)
      for ((id, settings) in moved) save(context, id, settings)
    }
  }
}
