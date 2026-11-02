package com.invoiceninja.admin.homewidgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.UUID
import org.json.JSONObject

/**
 * The Timer widget's Stop: queues a command for the app and shows the timer as
 * stopped at once (docs/home-screen-widgets.md § The only write is a queued
 * command).
 *
 * **Not exported**, so only this app's own PendingIntents reach it — that is
 * the whole security story: a stop can't be forged by another app or a web
 * page the way a URL could. It never starts the Flutter engine; when the app
 * happens to be running it is told over the channel and applies the stop now.
 */
class WidgetCommandReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != ACTION_STOP) return
    val taskId = intent.getStringExtra(EXTRA_TASK) ?: return
    val companyId = intent.getStringExtra(EXTRA_COMPANY) ?: return
    val userId = intent.getStringExtra(EXTRA_USER) ?: return
    val runningSince = intent.getLongExtra(EXTRA_RUNNING_SINCE, 0)
    if (taskId.isEmpty() || companyId.isEmpty() || userId.isEmpty() || runningSince <= 0) return

    val id = UUID.randomUUID().toString()
    val command =
        JSONObject()
            .put("v", 1)
            .put("id", id)
            .put("kind", "stop")
            .put("userId", userId)
            .put("companyId", companyId)
            .put("taskId", taskId)
            .put("runningSince", runningSince)
            .put("at", System.currentTimeMillis())
    val pending = goAsync()
    val app = context.applicationContext
    HomeWidgets.worker.execute {
      try {
        WidgetStore.queueCommand(app, command)
        HomeWidgets.update(app, setOf(HomeWidgets.KIND_TIMER))
        HomeWidgetsChannel.active?.notifyCommandsQueued()
      } catch (e: Throwable) {
        // A full disk, say: the Stop is lost (the widget keeps showing the
        // timer running, so nothing claims otherwise) — but never the app.
        android.util.Log.w("HomeWidgets", "Widget Stop not queued", e)
      } finally {
        pending.finish()
      }
    }
  }

  companion object {
    const val ACTION_STOP = "com.invoiceninja.admin.homewidgets.STOP"
    const val EXTRA_TASK = "taskId"
    const val EXTRA_COMPANY = "companyId"
    const val EXTRA_USER = "userId"
    const val EXTRA_RUNNING_SINCE = "runningSince"
  }
}
