package com.invoiceninja.store_services

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * The one Android plugin class store_services can declare (pubspec
 * `pluginClass`), hosting its three channels: receipt OCR
 * (`ReceiptOcrPlugin`), and passkeys (`PasskeysPlugin`) and Stripe Terminal's
 * device check and permissions (`StripeTerminalPlugin`), which also need the
 * activity.
 */
class StoreServicesPlugin : FlutterPlugin, ActivityAware {
  private val receiptOcr = ReceiptOcrPlugin()
  private val passkeys = PasskeysPlugin()
  private val stripeTerminal = StripeTerminalPlugin()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    receiptOcr.onAttachedToEngine(binding)
    passkeys.onAttachedToEngine(binding)
    stripeTerminal.onAttachedToEngine(binding)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    receiptOcr.onDetachedFromEngine(binding)
    passkeys.onDetachedFromEngine(binding)
    stripeTerminal.onDetachedFromEngine(binding)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    passkeys.onAttachedToActivity(binding)
    stripeTerminal.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    passkeys.onDetachedFromActivityForConfigChanges()
    stripeTerminal.onDetachedFromActivityForConfigChanges()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    passkeys.onReattachedToActivityForConfigChanges(binding)
    stripeTerminal.onReattachedToActivityForConfigChanges(binding)
  }

  override fun onDetachedFromActivity() {
    passkeys.onDetachedFromActivity()
    stripeTerminal.onDetachedFromActivity()
  }
}
