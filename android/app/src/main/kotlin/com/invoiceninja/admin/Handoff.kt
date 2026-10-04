package com.invoiceninja.admin

import android.content.Context
import android.content.Intent
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Carries what an engine-free trampoline received — a share
 * ([ShareReceiverActivity], invoiceninja/flutter#173) or a deep link
 * ([DeepLinkReceiverActivity]) — to [MainActivity] inside the process. The
 * intent between them holds only a one-time token ([EXTRA_TOKEN]); the payload
 * never travels in it.
 *
 * Two reasons it is not an intent extra:
 * - MainActivity is exported (it is the launcher activity), so anything could
 *   send it an intent naming arbitrary paths — this app's own private files —
 *   to be attached and uploaded. A token only this process minted resolves to
 *   nothing when forged. (MainActivity strips every other extra, too.)
 * - The intent outlives the hand-off: it becomes the task's base intent and is
 *   re-delivered on a relaunch from Recents or a recreation. A token is
 *   claimed once, so a replay finds nothing — no guard has to be remembered.
 *
 * Claimed payloads wait in process-level queues until Dart pulls them
 * (`takeShares` / `takeLinks`), so a MainActivity recreated before then doesn't
 * lose them.
 */
object Handoff {
  const val EXTRA_TOKEN = "com.invoiceninja.admin.extra.HANDOFF_TOKEN"

  enum class Kind {
    /** A JSON array of `{path, name, issue?}` — the copied files. */
    SHARE,

    /** A deep link URI, as received. */
    LINK,
  }

  private class Staged(val kind: Kind, val value: String)

  /** Hand-offs not yet claimed by MainActivity, by token. */
  private val staged = ConcurrentHashMap<String, Staged>()

  /** Claimed hand-offs, oldest first, per kind. */
  private val shares = mutableListOf<String>()
  private val links = mutableListOf<String>()

  /** Holds [filesJson] and returns the token to put on the intent. */
  fun stageShare(filesJson: String): String = stage(Kind.SHARE, filesJson)

  /** Holds [uri] and returns the token to put on the intent. */
  fun stageLink(uri: String): String = stage(Kind.LINK, uri)

  private fun stage(kind: Kind, value: String): String {
    val token = UUID.randomUUID().toString()
    staged[token] = Staged(kind, value)
    return token
  }

  /** Moves what [token] names into its queue and says which. Null for a token
   *  that is missing, forged, or already claimed. */
  fun claim(token: String?): Kind? {
    val entry = token?.let { staged.remove(it) } ?: return null
    val queue = queueOf(entry.kind)
    synchronized(queue) { queue.add(entry.value) }
    return entry.kind
  }

  /** Every claimed share, oldest first; empties the queue. */
  fun drainShares(): List<String> = drain(shares)

  /** Every claimed link, oldest first; empties the queue. */
  fun drainLinks(): List<String> = drain(links)

  private fun queueOf(kind: Kind) = if (kind == Kind.SHARE) shares else links

  private fun drain(queue: MutableList<String>): List<String> =
      synchronized(queue) { queue.toList().also { queue.clear() } }

  /**
   * The intent a trampoline brings MainActivity forward with, carrying [token]
   * when there is one.
   *
   * Launcher-shaped on purpose. Whatever it is becomes the base intent of the
   * app's task — a cold start makes it the root, and CLEAR_TOP onto the root
   * calls `Task.setIntent` — and a later launcher tap is checked against it
   * with `Intent.filterEquals`, which ignores extras but not the action or
   * categories. Any other shape fails that check while another activity (a
   * file picker, the camera) sits above MainActivity, and Android then starts a
   * SECOND MainActivity on top — a second Flutter engine on the store
   * (`ActivityStarter.complyActivityFlags`: `!isSameIntentFilter` →
   * `mAddingToTask`). That is why neither a share nor a deep link may be
   * delivered to MainActivity directly.
   *
   * `NEW_TASK` finds the app's own task by its root component (so
   * `taskAffinity=""` doesn't matter) instead of joining the sender's;
   * `CLEAR_TOP` with `SINGLE_TOP` delivers to the live MainActivity's
   * `onNewIntent` even with a picker above it — closing the picker — instead
   * of stacking another.
   */
  fun launchIntent(context: Context, token: String?): Intent =
      Intent(Intent.ACTION_MAIN)
          .addCategory(Intent.CATEGORY_LAUNCHER)
          .setClass(context, MainActivity::class.java)
          .addFlags(
              Intent.FLAG_ACTIVITY_NEW_TASK or
                  Intent.FLAG_ACTIVITY_CLEAR_TOP or
                  Intent.FLAG_ACTIVITY_SINGLE_TOP)
          .apply { if (token != null) putExtra(EXTRA_TOKEN, token) }
}
