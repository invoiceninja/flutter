package com.invoiceninja.admin.homewidgets

import android.app.Activity
import android.os.Bundle
import com.invoiceninja.admin.Handoff
import java.util.UUID

/**
 * An idle Timer widget's recent task, tapped: queues a Start for the app and
 * opens it (docs/home-screen-widgets.md § The only write is a queued command).
 *
 * An activity, not [WidgetCommandReceiver]'s receiver: the app has to come to
 * the front, and Android 10+ won't let a receiver running in the background
 * start an activity. One started by the widget's own click is in the
 * foreground, so it can. It never starts the Flutter engine itself — it
 * writes the command, then brings MainActivity forward with the same
 * launcher-shaped intent as [com.invoiceninja.admin.DeepLinkReceiverActivity],
 * no extras, and the app applies the command when it opens.
 *
 * **Not exported**, so only this app's own PendingIntents reach it, as the
 * Stop receiver. `Theme.NoDisplay`: nothing is drawn, and it finishes in
 * `onCreate`, which that theme requires.
 */
class WidgetStartActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // A recreation, or a relaunch from Recents, re-delivers the tap: queue
    // nothing for it (a second Start would only be skipped, but be honest).
    val replay =
        savedInstanceState != null ||
            intent.flags and android.content.Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
    if (!replay) queue()
    startActivity(Handoff.launchIntent(this, null))
    finish()
  }

  private fun queue() {
    try {
      val taskId = intent.getStringExtra(EXTRA_TASK).orEmpty()
      val companyId = intent.getStringExtra(EXTRA_COMPANY).orEmpty()
      val drawnFor = intent.getStringExtra(EXTRA_USER).orEmpty()
      if (taskId.isEmpty() || taskId.startsWith("tmp_") || companyId.isEmpty()) return
      // The user is the snapshot's now, not the one the row was drawn for —
      // and when those differ (signed out, or someone else signed in since
      // the widget last redrew) nothing is queued: the app just opens.
      val snapshot = WidgetStore.readSnapshot(this) ?: return
      if (!snapshot.signedIn || snapshot.userId.isEmpty() || snapshot.userId != drawnFor) return
      if (snapshot.companies.none { it.id == companyId }) return
      // Small enough to write here, before the app is brought forward: the
      // command must be on disk before a cold start reads the folder.
      WidgetStore.queueCommand(
          this,
          WidgetStore.startCommand(
              id = UUID.randomUUID().toString(),
              userId = snapshot.userId,
              companyId = companyId,
              taskId = taskId,
              at = System.currentTimeMillis(),
          ),
      )
      HomeWidgetsChannel.active?.notifyCommandsQueued()
    } catch (e: Throwable) {
      // A full disk, say: the Start is lost but the app still opens, so the
      // user sees nothing started — never a crash on a widget tap.
      android.util.Log.w("HomeWidgets", "Widget Start not queued", e)
    }
  }

  companion object {
    const val EXTRA_TASK = "taskId"
    const val EXTRA_COMPANY = "companyId"
    const val EXTRA_USER = "userId"
  }
}
