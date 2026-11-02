package com.invoiceninja.admin.homewidgets

import android.content.Context
import java.io.File
import java.util.UUID
import org.json.JSONObject

/**
 * Where the home-screen widgets' files live: the snapshot the app writes, and
 * the commands a widget queues for the app (docs/home-screen-widgets.md).
 *
 * Under `noBackupFilesDir`, never `filesDir`: the app's backup rules exclude
 * nothing in `filesDir`, so anything there is auto-backed up — a plaintext
 * copy of the user's figures restored onto another device.
 */
object WidgetStore {
  private const val FOLDER = "home_widgets"
  private const val SNAPSHOT = "snapshot.json"
  private const val COMMANDS = "commands"

  /** A command file name: a UUID and `.json`, nothing a caller can path out of. */
  private val COMMAND_NAME = Regex("^[A-Za-z0-9-]{1,64}\\.json$")

  private fun root(context: Context): File = File(context.noBackupFilesDir, FOLDER)

  private fun commandsDir(context: Context): File = File(root(context), COMMANDS)

  /** Replaces the snapshot. Write-then-rename, so a widget never reads half a file. */
  @Synchronized
  fun writeSnapshot(context: Context, json: String) {
    val dir = root(context).apply { mkdirs() }
    val tmp = File(dir, "$SNAPSHOT.tmp")
    tmp.writeText(json)
    if (!tmp.renameTo(File(dir, SNAPSHOT))) {
      File(dir, SNAPSHOT).writeText(json)
      tmp.delete()
    }
  }

  /** The snapshot, or null when the app has never written one or it won't parse. */
  fun readSnapshot(context: Context): WidgetSnapshot? {
    val file = File(root(context), SNAPSHOT)
    if (!file.exists()) return null
    return runCatching { WidgetSnapshot.parse(JSONObject(file.readText())) }.getOrNull()
  }

  /** Queues a command for the app. Returns its file id. */
  @Synchronized
  fun queueCommand(context: Context, command: JSONObject): String {
    val dir = commandsDir(context).apply { mkdirs() }
    val id = command.optString("id").takeIf { it.isNotEmpty() } ?: UUID.randomUUID().toString()
    val name = "$id.json"
    val tmp = File(dir, "$name.tmp")
    tmp.writeText(command.toString())
    if (!tmp.renameTo(File(dir, name))) {
      // Never lose a Stop the user tapped: write it in place instead.
      File(dir, name).writeText(command.toString())
      tmp.delete()
    }
    return name
  }

  /** Every queued command as `{fileId, json}`, oldest tap first (by `at`, as iOS). */
  fun commands(context: Context): List<Map<String, String>> {
    val files =
        commandsDir(context).listFiles { f -> COMMAND_NAME.matches(f.name) } ?: return emptyList()
    return files
        .mapNotNull { f ->
          runCatching {
                val text = f.readText()
                val at = runCatching { JSONObject(text).optLong("at") }.getOrDefault(0L)
                at to mapOf("fileId" to f.name, "json" to text)
              }
              .getOrNull()
        }
        .sortedBy { it.first }
        .map { it.second }
  }

  /**
   * `taskId|runningSince` → tap time, for every queued Stop — the widget shows
   * that session as stopped already. Keyed by the session, not the task: a
   * stop still waiting (deferred for another company) must not mark a later,
   * restarted session of the same task as stopped.
   */
  fun pendingStops(context: Context): Map<String, Long> {
    val out = mutableMapOf<String, Long>()
    for (entry in commands(context)) {
      val json = runCatching { JSONObject(entry["json"] ?: "") }.getOrNull() ?: continue
      if (json.optString("kind") != "stop") continue
      out[stopKey(json.optString("taskId"), json.optLong("runningSince"))] = json.optLong("at")
    }
    return out
  }

  fun stopKey(taskId: String, runningSince: Long) = "$taskId|$runningSince"

  /**
   * A Start, as the app reads it (`HomeWidgetCommand`): the same file and id
   * rules as a Stop, no `runningSince` — nothing is running yet. `at` is the
   * tap; the app starts the task through its own start path when it opens,
   * which may still ask its booking question.
   */
  fun startCommand(id: String, userId: String, companyId: String, taskId: String, at: Long): JSONObject =
      JSONObject()
          .put("v", 1)
          .put("id", id)
          .put("kind", "start")
          .put("userId", userId)
          .put("companyId", companyId)
          .put("taskId", taskId)
          .put("at", at)

  fun deleteCommand(context: Context, fileId: String) {
    if (!COMMAND_NAME.matches(fileId)) return
    File(commandsDir(context), fileId).delete()
  }

  fun deleteAllCommands(context: Context) {
    commandsDir(context).listFiles()?.forEach { it.delete() }
  }
}
