package com.invoiceninja.admin

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Where Android delivers the app's deep links — `invoiceninja://app/…`,
 * `invoiceninja://calendar_connection/…` and the verified
 * `https://invoicing.co/app/…` — so that MainActivity never receives one.
 *
 * A VIEW intent sent straight to MainActivity breaks the one-engine rule two
 * ways. From an app that doesn't add `NEW_TASK` it starts a `singleTop`
 * MainActivity inside *that* app's task: a second Flutter engine on the store.
 * And one that does reach the live MainActivity becomes its task's base intent
 * (`Task.setIntent`), after which a launcher tap with a picker on top no longer
 * matches it and Android adds a second instance anyway. So, like
 * [ShareReceiverActivity], this starts no engine: it hands the URI over through
 * [Handoff] and brings MainActivity forward with the launcher-shaped intent.
 * Dart's `AppDeepLinks` pulls the link and routes it through `DeepLinkRouter`
 * exactly as before.
 *
 * Reads only the action, the data and the flags — never the extras, which a
 * sender controls (and which, before API 33, unparcel all at once).
 */
class DeepLinkReceiverActivity : Activity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // A relaunch from Recents re-delivers the original link (excludeFromRecents
    // should make it unreachable); a recreation already forwarded it.
    val replay =
        savedInstanceState != null ||
            intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
    val link = intent.dataString?.takeIf { !replay && intent.action == Intent.ACTION_VIEW }
    startActivity(Handoff.launchIntent(this, link?.let { Handoff.stageLink(it) }))
    finish()
  }
}
