package com.invoiceninja.store_services

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The Android half of `invoice_ninja/receipt_ocr` (`ReceiptTextRecognizer`,
 * docs/receipt-ocr.md): ML Kit reads a receipt photo or a rasterised PDF page
 * on the device. Store builds only — the F-Droid build has no such plugin, so
 * the Dart side sees a `MissingPluginException` and hides the feature.
 *
 * `recognize {path?, bytes?}` replies `[{text, x, y, w, h}]`, one per line,
 * normalised to the upright image with a top-left origin. Work runs on a
 * single background thread; the reply goes back on the main looper. Errors
 * carry a code only — never recognised text, which is personal data.
 */
class ReceiptOcrPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private var channel: MethodChannel? = null
  private var executor: ExecutorService? = null

  /** Touched only on [executor]'s one thread: made there, used there, closed there. */
  private var recognizer: TextRecognizer? = null
  private val main = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    executor = Executors.newSingleThreadExecutor()
    channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
      it.setMethodCallHandler(this)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
    // Closed behind any read still running, on the thread that uses it.
    executor?.let { worker ->
      worker.execute {
        recognizer?.close()
        recognizer = null
      }
      worker.shutdown()
    }
    executor = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isAvailable" -> result.success(true)
      "recognize" -> {
        val path = call.argument<String>("path")
        val bytes = call.argument<ByteArray>("bytes")
        val worker = executor ?: return result.error("unavailable", null, null)
        worker.execute {
          // Throwable, not Exception: an OutOfMemoryError decoding a huge
          // image must still answer, or the Dart side waits out its timeout.
          val reply: Any? = try {
            recognize(path, bytes)
          } catch (e: Throwable) {
            null
          }
          main.post {
            when (reply) {
              null -> result.error("failed", null, null)
              UNSUPPORTED -> result.error("unsupported_image", null, null)
              else -> result.success(reply)
            }
          }
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun recognizer(): TextRecognizer =
      recognizer ?: TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).also {
        recognizer = it
      }

  private fun recognize(path: String?, bytes: ByteArray?): Any {
    // The photo's EXIF orientation: BitmapFactory ignores it, and ML Kit
    // reads a sideways receipt as noise unless told.
    val rotation = try {
      when {
        path != null -> ExifInterface(path).rotationDegrees
        bytes != null -> ExifInterface(ByteArrayInputStream(bytes)).rotationDegrees
        else -> 0
      }
    } catch (e: Exception) {
      0
    }
    val bitmap = decode(path, bytes) ?: return UNSUPPORTED
    try {
      val text = Tasks.await(recognizer().process(InputImage.fromBitmap(bitmap, rotation)))
      // ML Kit reports boxes in the upright image.
      val upright = rotation % 180 == 0
      val width = (if (upright) bitmap.width else bitmap.height).toDouble()
      val height = (if (upright) bitmap.height else bitmap.width).toDouble()
      val out = ArrayList<Map<String, Any>>()
      for (block in text.textBlocks) {
        for (line in block.lines) {
          val box = line.boundingBox ?: continue
          out.add(
              mapOf(
                  "text" to line.text,
                  "x" to box.left / width,
                  "y" to box.top / height,
                  "w" to box.width() / width,
                  "h" to box.height() / height,
              ))
        }
      }
      return out
    } finally {
      bitmap.recycle()
    }
  }

  /** The image at [path] or in [bytes], downsampled so neither side passes [MAX_SIDE]. */
  private fun decode(path: String?, bytes: ByteArray?): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    when {
      path != null -> {
        if (!File(path).canRead()) return null
        BitmapFactory.decodeFile(path, bounds)
      }
      bytes != null -> BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
      else -> return null
    }
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_SIDE) sample *= 2
    val options = BitmapFactory.Options().apply { inSampleSize = sample }
    return if (path != null) {
      BitmapFactory.decodeFile(path, options)
    } else {
      BitmapFactory.decodeByteArray(bytes, 0, bytes!!.size, options)
    }
  }

  private companion object {
    /** Same name as `ChannelReceiptTextRecognizer.kChannel`. */
    const val CHANNEL = "invoice_ninja/receipt_ocr"

    /** The longest side ML Kit is handed; a 48 MP photo decoded whole is ~190 MB. */
    const val MAX_SIDE = 3000

    /** A file that isn't an image BitmapFactory can decode. */
    val UNSUPPORTED = Any()
  }
}
