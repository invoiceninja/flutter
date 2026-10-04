package com.invoiceninja.admin

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ProviderInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.Parcelable
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.MimeTypeMap
import android.widget.FrameLayout
import android.widget.ProgressBar
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

/**
 * The app's share target: "Share → Invoice Ninja" from Gmail, Photos, Files…
 * opens New Expense with the files attached (invoiceninja/flutter#173).
 *
 * Deliberately NOT MainActivity, and never a Flutter activity. The share sheet
 * starts its target in the *sender's* task, and MainActivity is `singleTop` with
 * `taskAffinity=""` — so a share filter on it would start a second MainActivity,
 * with a second Flutter engine, in the same process. Its isolate would pass
 * `holdStoreLock` (a per-isolate map over a per-process POSIX lock) and open the
 * encrypted store a second time. This activity starts no engine at all.
 *
 * It also has to be the one that reads the files: the read grant on a shared
 * `content://` URI lasts only as long as the activity it was delivered to. So it
 * copies each into `filesDir/shared_intake/<uuid>/` — which is what Dart's
 * `getApplicationSupportDirectory()` returns (`SharedIntakeFiles`) — and hands
 * MainActivity the copies through [Handoff]. Images the server's upload
 * rule won't take (HEIC, HEIF, BMP, TIFF…: `mimes:` in the server's
 * `Request::$file_validation`) are re-encoded as JPEG on the way.
 *
 * See docs/sharing-files-into-the-app.md.
 */
class ShareReceiverActivity : Activity() {

  companion object {
    /** Same folder name as `SharedIntakeFiles.kFolderName`. */
    private const val INTAKE_FOLDER = "shared_intake"

    /** The document cap (`kDocumentMaxBytes`): a copy past it is abandoned. */
    private const val MAX_BYTES = 25L * 1024 * 1024

    /** More than anyone attaches to one expense; bounds the copy work. */
    private const val MAX_FILES = 20

    /** Long edge of a converted image. A receipt needs nothing larger. */
    private const val MAX_EDGE = 4096

    /** A file name's base, in UTF-8 bytes — well inside the 255-byte limit. */
    private const val MAX_BASE_BYTES = 150

    /** How long a copy may run before the user is shown it is working. */
    private const val PROGRESS_DELAY_MS = 300L

    /** Image types the server takes as-is; any other image is converted. */
    private val SERVER_IMAGE_TYPES =
        setOf("image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp")
    private val SERVER_IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "gif", "webp")
    private val IMAGE_EXTENSIONS =
        SERVER_IMAGE_EXTENSIONS + setOf("heic", "heif", "bmp", "tif", "tiff", "svg")
  }

  private val executor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())
  private val cancelSignal = CancellationSignal()

  /** Set when the user leaves (Back, Home — `noHistory` finishes us) mid-copy. */
  @Volatile private var cancelled = false

  /**
   * Whether we are in front of the user — the only time a copy may be handed
   * on. Stopped, `startActivity` is refused by the background-activity-start
   * rules and the share is lost; and a power-button lock stops us WITHOUT
   * finishing us (`noHistory` skips an activity that is "just sleeping"), so
   * `cancelled` alone can't tell.
   */
  private var resumed = false

  /** A finished copy waiting for [onResume] — after the screen was locked. */
  private var parked: Pair<File, JSONArray>? = null

  /** A slow (cloud) copy shows a spinner rather than a frozen-looking sender. */
  private val showProgress = Runnable {
    if (isFinishing || isDestroyed) return@Runnable
    setContentView(
        FrameLayout(this).apply {
          // The platform spinner here is the old white one: a scrim keeps it
          // visible over a light sender. Only after the delay, so a quick
          // share never flashes the screen.
          setBackgroundColor(0x66000000)
          addView(
              ProgressBar(this@ShareReceiverActivity),
              FrameLayout.LayoutParams(
                  ViewGroup.LayoutParams.WRAP_CONTENT,
                  ViewGroup.LayoutParams.WRAP_CONTENT,
                  Gravity.CENTER))
        })
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // A relaunch from Recents re-delivers the original share — the same guard
    // `app_links` applies. (`excludeFromRecents` should make this unreachable.)
    // A recreation copies again: `configChanges` covers the usual ones, and
    // what's left — a process death while the screen was locked — keeps the
    // read grant, which belongs to this activity record, not to the process.
    val fromHistory = intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
    val uris = if (fromHistory) emptyList() else sharedUris(intent)
    if (uris.isEmpty()) {
      openApp(null)
      return
    }
    // A long copy must not let the screen time out and stop us ([resumed]).
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    mainHandler.postDelayed(showProgress, PROGRESS_DELAY_MS)
    // Off the main thread, but while this activity — and so the grant — lives.
    executor.execute {
      val folder = File(File(filesDir, INTAKE_FOLDER), UUID.randomUUID().toString())
      val files = JSONArray()
      try {
        for ((index, uri) in uris.withIndex()) {
          if (cancelled) break
          files.put(
              runCatching { copy(uri, index, folder) }
                  .getOrElse {
                    JSONObject().put("name", "shared_${index + 1}").put("issue", "unreadable")
                  })
        }
      } finally {
        runOnUiThread { finishCopy(folder, files) }
      }
    }
    executor.shutdown()
  }

  private fun finishCopy(folder: File, files: JSONArray) {
    mainHandler.removeCallbacks(showProgress)
    if (cancelled || isFinishing || isDestroyed) {
      // The user left: nobody is waiting for these.
      folder.deleteRecursively()
      return
    }
    if (!resumed) {
      // Locked, or on the way out: wait for [onResume], or [onDestroy].
      parked = folder to files
      return
    }
    openApp(files)
  }

  override fun onResume() {
    super.onResume()
    resumed = true
    parked?.let { (_, files) ->
      parked = null
      openApp(files)
    }
  }

  override fun onPause() {
    resumed = false
    super.onPause()
  }

  override fun onDestroy() {
    cancelled = true
    cancelSignal.cancel()
    mainHandler.removeCallbacks(showProgress)
    parked?.first?.deleteRecursively()
    parked = null
    super.onDestroy()
  }

  /**
   * Bring MainActivity forward, handing [files] over through [Handoff] — in
   * the launcher-shaped intent [Handoff.launchIntent] explains.
   */
  private fun openApp(files: JSONArray?) {
    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    val token =
        if (files != null && files.length() > 0) Handoff.stageShare(files.toString()) else null
    setResult(RESULT_OK)
    startActivity(Handoff.launchIntent(this, token))
    finish()
  }

  /**
   * The shared URIs. Defensive throughout: a buggy sender can put non-Uri
   * values in the list, or (before API 33) an unknown Parcelable anywhere in the
   * extras, and either would otherwise crash the whole process — taking a
   * running MainActivity's unsaved edits with it.
   */
  @Suppress("DEPRECATION") // The typed getters misbehave on API 33 itself.
  private fun sharedUris(intent: Intent): List<Uri> =
      runCatching {
            val uris = mutableListOf<Uri>()
            when (intent.action) {
              Intent.ACTION_SEND ->
                  (intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri)?.let {
                    uris.add(it)
                  }
              Intent.ACTION_SEND_MULTIPLE ->
                  intent
                      .getParcelableArrayListExtra<Parcelable>(Intent.EXTRA_STREAM)
                      ?.filterIsInstance<Uri>()
                      ?.let { uris.addAll(it) }
            }
            if (uris.isEmpty()) {
              intent.clipData?.let { clip ->
                for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { uris.add(it) }
              }
            }
            uris.distinct().take(MAX_FILES)
          }
          .getOrDefault(emptyList())

  /**
   * Only another app's `content://` file. A `file://` URI, or one served by a
   * provider of THIS app, is refused: either could name the app's own private
   * files (its database, its token store) and have them copied, attached and
   * uploaded — the "share intent file theft" class of bug. Our process can read
   * our own non-exported providers, so the check has to be ours. Checked before
   * anything else touches the URI.
   */
  private fun isForeignContent(uri: Uri): Boolean {
    if (uri.scheme != ContentResolver.SCHEME_CONTENT) return false
    // A cross-profile URI prefixes the authority with `<userId>@` — parsed the
    // way `ContentProvider.getAuthorityWithoutUserId` does (last `@`).
    val authority = uri.authority?.substringAfterLast('@') ?: return false
    return authority !in ownAuthorities
  }

  /**
   * Every authority this app's own providers serve (plugins register several
   * FileProviders), disabled ones included. Matched rather than asking who owns
   * the URI's authority: since Android 11, package visibility can hide the
   * sender's provider from that query, which would refuse an ordinary share.
   */
  private val ownAuthorities: Set<String> by lazy {
    ownProviders()
        .flatMap { it.authority.orEmpty().split(';') }
        .filter { it.isNotEmpty() }
        .toSet()
  }

  @Suppress("DEPRECATION")
  private fun ownProviders(): List<ProviderInfo> {
    val flags = PackageManager.GET_PROVIDERS or PackageManager.MATCH_DISABLED_COMPONENTS
    val info =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
          packageManager.getPackageInfo(
              packageName, PackageManager.PackageInfoFlags.of(flags.toLong()))
        } else {
          packageManager.getPackageInfo(packageName, flags)
        }
    return info.providers?.toList().orEmpty()
  }

  private fun copy(uri: Uri, index: Int, folder: File): JSONObject {
    val entry = JSONObject()
    if (!isForeignContent(uri)) {
      return entry.put("name", "shared_${index + 1}").put("issue", "unreadable")
    }
    // The provider's type; when it won't name one, the type the sender put on
    // the share — only a specific one (a mixed SEND_MULTIPLE says `*/*`).
    val providerMime = runCatching { contentResolver.getType(uri) }.getOrNull()?.lowercase()
    val mime = specificMime(providerMime) ?: specificMime(intent.type?.lowercase()) ?: providerMime
    val (queriedName, size) = queryMeta(uri)
    val name = safeName(queriedName ?: uri.lastPathSegment, mime, index)
    entry.put("name", name)
    // Known up front: don't download 25 MB to find out.
    if (size != null && size > MAX_BYTES) return entry.put("issue", "tooLarge")
    var target: File? = null
    try {
      folder.mkdirs()
      target = uniqueFile(folder, name)
      if (!copyCapped(uri, target)) {
        target.delete()
        return entry.put("issue", "tooLarge")
      }
      if (needsConversion(mime, name)) {
        val converted = toJpeg(target, folder)
        target.delete()
        if (converted == null) return entry.put("issue", "unsupported")
        target = converted
        entry.put("name", converted.name)
      }
      entry.put("path", target.absolutePath)
    } catch (e: Throwable) {
      target?.delete()
      entry.put("issue", "unreadable")
    }
    return entry
  }

  /** The provider's display name and size, either null when it won't say. */
  private fun queryMeta(uri: Uri): Pair<String?, Long?> =
      runCatching {
            contentResolver
                .query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                    null,
                    null,
                    null)
                ?.use { cursor ->
                  if (!cursor.moveToFirst()) return@use null to null
                  val nameAt = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                  val sizeAt = cursor.getColumnIndex(OpenableColumns.SIZE)
                  val name = if (nameAt >= 0 && !cursor.isNull(nameAt)) cursor.getString(nameAt) else null
                  val size = if (sizeAt >= 0 && !cursor.isNull(sizeAt)) cursor.getLong(sizeAt) else null
                  name to size
                } ?: (null to null)
          }
          .getOrDefault(null to null)

  /**
   * Copies [uri] to [target]; false when it runs past [MAX_BYTES]. Opened with
   * the activity's [CancellationSignal], so leaving mid-copy unblocks a provider
   * still fetching the file from the cloud.
   */
  private fun copyCapped(uri: Uri, target: File): Boolean {
    val descriptor =
        contentResolver.openAssetFileDescriptor(uri, "r", cancelSignal)
            ?: throw IOException("no descriptor")
    descriptor.createInputStream().use { source ->
      FileOutputStream(target).use { sink ->
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
          if (cancelled) throw IOException("cancelled")
          val read = source.read(buffer)
          if (read < 0) return true
          total += read
          if (total > MAX_BYTES) return false
          sink.write(buffer, 0, read)
        }
      }
    }
  }

  /**
   * An image the server won't take. A specific `image/…` type is trusted; when
   * the sender gave none, or a generic one (`application/octet-stream` from some
   * file managers), the extension decides — a HEIC must not slip through as
   * "not an image" and die as a 422 on upload.
   */
  private fun needsConversion(mime: String?, name: String): Boolean {
    val ext = name.substringAfterLast('.', "").lowercase()
    // A wildcard `image/*` says nothing about which image: decide by the name,
    // or a JPEG gets re-encoded and a PNG loses its transparency.
    val type = specificMime(mime)
    val typeIsImage = type?.startsWith("image/") == true
    if (!typeIsImage && ext !in IMAGE_EXTENSIONS) return false
    return if (typeIsImage) type !in SERVER_IMAGE_TYPES else ext !in SERVER_IMAGE_EXTENSIONS
  }

  /** [mime] when it names a type — not empty, a wildcard, or octet-stream. */
  private fun specificMime(mime: String?): String? =
      mime?.takeIf {
        it.isNotEmpty() && it != "application/octet-stream" && !it.endsWith("/*")
      }

  /** [source] re-encoded as JPEG beside it, or null when it can't be. */
  private fun toJpeg(source: File, folder: File): File? {
    val decoded = decode(source) ?: return null
    // `compress` can't encode every config (a 10-bit HEIF decodes to
    // RGBA_1010102 / F16 on newer Androids).
    val encodable =
        if (decoded.config == Bitmap.Config.ARGB_8888 || decoded.config == Bitmap.Config.RGB_565) {
          decoded
        } else {
          decoded.copy(Bitmap.Config.ARGB_8888, false)
        }
    if (encodable == null) {
      decoded.recycle()
      return null
    }
    val target = uniqueFile(folder, source.nameWithoutExtension + ".jpg")
    return try {
      val written =
          FileOutputStream(target).use { encodable.compress(Bitmap.CompressFormat.JPEG, 90, it) }
      if (written) target else null.also { target.delete() }
    } catch (e: Exception) {
      target.delete()
      null
    } finally {
      if (encodable !== decoded) encodable.recycle()
      decoded.recycle()
    }
  }

  /**
   * Decodes [file], scaled so its long edge is at most [MAX_EDGE]. API 28+'s
   * `ImageDecoder` reads HEIF and applies the image's orientation; before that
   * `BitmapFactory` can't read HEIF, which then comes back null (`unsupported`).
   * Throwable, not Exception: a huge image can run the decoder out of memory.
   */
  private fun decode(file: File): Bitmap? =
      try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
            // Software, so `compress` can read the pixels back.
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val longEdge = maxOf(info.size.width, info.size.height)
            if (longEdge > MAX_EDGE) {
              val scale = MAX_EDGE.toFloat() / longEdge
              decoder.setTargetSize(
                  (info.size.width * scale).toInt().coerceAtLeast(1),
                  (info.size.height * scale).toInt().coerceAtLeast(1))
            }
          }
        } else {
          val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
          BitmapFactory.decodeFile(file.path, bounds)
          var sample = 1
          while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_EDGE) sample *= 2
          BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
        }
      } catch (e: Throwable) {
        null
      }

  /**
   * The sending app's name for the file, made safe as a file name, with an
   * extension that names what the file IS — the server and Dart's validation
   * both read the type from it.
   *
   * A dot is not an extension: "Receipt 12.05.2024" or "Inv. 42" for a PDF
   * keeps its whole name and gains `.pdf`. A trailing word is kept as the
   * extension only when it names the type the provider reports (or the
   * provider reports none). The base is truncated by UTF-8 bytes, never the
   * extension, and never mid-character.
   */
  private fun safeName(raw: String?, mime: String?, index: Int): String {
    val cleaned =
        (raw ?: "")
            .substringAfterLast('/')
            .replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_")
            .trim()
            .trimStart('.')
    val specificMime = specificMime(mime)
    val dot = cleaned.lastIndexOf('.')
    val tail = if (dot > 0) cleaned.substring(dot + 1).lowercase() else ""
    val tailMime = tail.takeIf { it.isNotEmpty() }?.let {
      MimeTypeMap.getSingleton().getMimeTypeFromExtension(it)
    }
    val mimeExt = specificMime?.let { extensionFor(it) }
    val (base, ext) =
        when {
          tailMime != null && (specificMime == null || sameType(tailMime, specificMime)) ->
              cleaned.substring(0, dot) to tail
          mimeExt != null -> cleaned to mimeExt
          tail.isNotEmpty() -> cleaned.substring(0, dot) to tail
          else -> cleaned to ""
        }
    // Nothing but dots would name the folder itself ("." / "..").
    val safeBase =
        truncateUtf8(base.trim(), MAX_BASE_BYTES).takeIf { b ->
          b.any { it != '.' && !it.isWhitespace() }
        } ?: "shared_${index + 1}"
    return if (ext.isEmpty()) safeBase else "$safeBase.${ext.take(10)}"
  }

  private fun extensionFor(mime: String): String? =
      if (mime == "image/jpg") "jpg" else MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)

  private fun sameType(a: String, b: String): Boolean {
    fun norm(t: String) = if (t.equals("image/jpg", ignoreCase = true)) "image/jpeg" else t.lowercase()
    return norm(a) == norm(b)
  }

  /** The longest prefix of [s] that fits [maxBytes] of UTF-8, whole code points only. */
  private fun truncateUtf8(s: String, maxBytes: Int): String {
    var bytes = 0
    var end = 0
    while (end < s.length) {
      val codePoint = s.codePointAt(end)
      val length =
          when {
            codePoint < 0x80 -> 1
            codePoint < 0x800 -> 2
            codePoint < 0x10000 -> 3
            else -> 4
          }
      if (bytes + length > maxBytes) break
      bytes += length
      end += Character.charCount(codePoint)
    }
    return s.substring(0, end)
  }

  /** [name] in [folder], or `name (2).ext`… when a multi-share repeats it. */
  private fun uniqueFile(folder: File, name: String): File {
    var candidate = File(folder, name)
    var n = 2
    while (candidate.exists()) {
      val base = name.substringBeforeLast('.', name)
      val ext = name.substringAfterLast('.', "")
      candidate = File(folder, if (ext.isEmpty()) "$base ($n)" else "$base ($n).$ext")
      n++
    }
    return candidate
  }
}
