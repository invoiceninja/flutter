package com.invoiceninja.store_services

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * The one Android plugin class store_services can declare (pubspec
 * `pluginClass`), hosting its two channels: receipt OCR (`ReceiptOcrPlugin`)
 * and passkeys (`PasskeysPlugin`), which also needs the activity.
 */
class StoreServicesPlugin : FlutterPlugin, ActivityAware {
  private val receiptOcr = ReceiptOcrPlugin()
  private val passkeys = PasskeysPlugin()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    receiptOcr.onAttachedToEngine(binding)
    passkeys.onAttachedToEngine(binding)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    receiptOcr.onDetachedFromEngine(binding)
    passkeys.onDetachedFromEngine(binding)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) =
      passkeys.onAttachedToActivity(binding)

  override fun onDetachedFromActivityForConfigChanges() =
      passkeys.onDetachedFromActivityForConfigChanges()

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
      passkeys.onReattachedToActivityForConfigChanges(binding)

  override fun onDetachedFromActivity() = passkeys.onDetachedFromActivity()
}
