package com.invoiceninja.admin.homewidgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Redraws every widget when its text changes on its own: the rollover alarm
 * (`HomeWidgets.scheduleRollover` — midnight, a stale threshold), and the
 * clock or time zone changing under it. Each redraw schedules the next alarm.
 *
 * Not exported: the alarm is an explicit intent, and the two clock broadcasts
 * are protected ones only the system sends. The action is still checked.
 */
class WidgetRolloverReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action !in ACTIONS) return
    val pending = goAsync()
    HomeWidgets.updateAsync(context, null) { pending.finish() }
  }

  companion object {
    /** The rollover alarm's own action — set on its explicit intent. */
    const val ACTION_ROLLOVER = "com.invoiceninja.admin.homewidgets.ROLLOVER"

    private val ACTIONS =
        setOf(ACTION_ROLLOVER, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)
  }
}
