package com.invoiceninja.admin

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONArray

/**
 * A `FragmentActivity` because `local_auth` needs one.
 *
 * Also the receiving end of the two engine-free trampolines —
 * [ShareReceiverActivity] (files shared in, invoiceninja/flutter#173) and
 * [DeepLinkReceiverActivity] (deep links). Each arrives as a launcher-shaped
 * intent carrying a [Handoff] token — on the launching intent for a cold start,
 * through [onNewIntent] for a running app. The token is claimed into
 * [Handoff]'s queues, which Dart pulls over `invoice_ninja/share_intake`
 * (`AppShareIntake`) and `invoice_ninja/deep_links` (`AppDeepLinks`). Pull, not
 * push: it never matters whether Dart was listening yet when the intent came in.
 *
 * Exported, so anything can start it with any extras, and
 * `FlutterFragmentActivity` reads its launch configuration from them — the
 * initial `route` (which would replace the restored location and bypass
 * `DeepLinkRouter`), a cached engine id, `dart_entrypoint_args`, and some
 * twenty engine flags through `FlutterShellArgs.fromIntent` (software
 * rendering, the Impeller toggle, trace-to-file…). This app sets none of them,
 * so every intent is stripped of all its extras before the superclass sees it
 * ([sanitize]). That also keeps the token read the only one, and makes it
 * safe: before API 33 any extras read unparcels the whole bundle, and a forged
 * unknown Parcelable would crash the running app.
 */
class MainActivity : FlutterFragmentActivity() {

  private companion object {
    /** Same name as `AppShareIntake.kChannel`. */
    const val SHARE_CHANNEL = "invoice_ninja/share_intake"

    /** Same name as `AppDeepLinks.kChannel`. */
    const val LINK_CHANNEL = "invoice_ninja/deep_links"

    /** Same folder as `ShareReceiverActivity` / `SharedIntakeFiles.kFolderName`. */
    const val INTAKE_FOLDER = "shared_intake"
  }

  private var shareChannel: MethodChannel? = null
  private var linkChannel: MethodChannel? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    val token = sanitize(intent)
    // A recreation or a relaunch from Recents re-delivers an intent whose token
    // was already claimed (or was minted by a process that has since died):
    // `claim` finds nothing. The guards just skip the lookup.
    if (savedInstanceState == null && !launchedFromHistory(intent)) {
      Handoff.claim(token)
    }
    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val messenger = flutterEngine.dartExecutor.binaryMessenger
    shareChannel =
        MethodChannel(messenger, SHARE_CHANNEL).apply {
          setMethodCallHandler { call, result ->
            when (call.method) {
              "takeShares" -> result.success(takeShares())
              else -> result.notImplemented()
            }
          }
        }
    linkChannel =
        MethodChannel(messenger, LINK_CHANNEL).apply {
          setMethodCallHandler { call, result ->
            when (call.method) {
              "takeLinks" -> result.success(Handoff.drainLinks())
              else -> result.notImplemented()
            }
          }
        }
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    shareChannel?.setMethodCallHandler(null)
    shareChannel = null
    linkChannel?.setMethodCallHandler(null)
    linkChannel = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onNewIntent(intent: Intent) {
    val token = sanitize(intent)
    // Before the claim, so plugins (`app_links`) still see every intent.
    super.onNewIntent(intent)
    if (launchedFromHistory(intent)) return
    val kind = Handoff.claim(token) ?: return
    setIntent(intent)
    when (kind) {
      Handoff.Kind.SHARE -> shareChannel?.invokeMethod("sharesAvailable", null)
      Handoff.Kind.LINK -> linkChannel?.invokeMethod("linksAvailable", null)
    }
  }

  /**
   * The [Handoff] token on [intent], if any, after removing every extra from
   * it — in place, before `FlutterFragmentActivity` reads it. The read can
   * throw on a forged bundle (before API 33 it unparcels everything); that is
   * just no token. `replaceExtras` drops the bundle without unparcelling it.
   */
  private fun sanitize(intent: Intent?): String? {
    if (intent == null) return null
    val token = runCatching { intent.getStringExtra(Handoff.EXTRA_TOKEN) }.getOrNull()
    intent.replaceExtras(null as Bundle?)
    return token
  }

  private fun launchedFromHistory(intent: Intent?): Boolean =
      intent != null && intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0

  /**
   * Every claimed share's files. A path outside `filesDir/shared_intake` is
   * dropped to "unreadable" — only [ShareReceiverActivity]'s own copies ever
   * belong there, and nothing else may be attached and uploaded.
   */
  private fun takeShares(): List<Map<String, String?>> {
    val root = runCatching { File(filesDir, INTAKE_FOLDER).canonicalFile }.getOrNull()
    val out = mutableListOf<Map<String, String?>>()
    for (share in Handoff.drainShares()) {
      val entries = runCatching { JSONArray(share) }.getOrNull() ?: continue
      for (i in 0 until entries.length()) {
        val entry = entries.optJSONObject(i) ?: continue
        var path = entry.optString("path", "")
        var issue: String? = if (entry.has("issue")) entry.optString("issue") else null
        if (path.isNotEmpty() && !isInside(root, path)) {
          path = ""
          issue = "unreadable"
        }
        out.add(mapOf("path" to path, "name" to entry.optString("name", ""), "issue" to issue))
      }
    }
    return out
  }

  private fun isInside(root: File?, path: String): Boolean {
    if (root == null) return false
    val file = runCatching { File(path).canonicalFile }.getOrNull() ?: return false
    return file.path.startsWith(root.path + File.separator)
  }
}
